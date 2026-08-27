-- Drawing for the stacked-gauge panels behind the menubar readouts: a section
-- is a heading and a list of rows, a row is a line of text over whichever bar
-- it carries, and this turns either one into canvas elements.
--
-- Shared because two menubar items draw the same thing for different reasons.
-- system_stats.lua snapshots one image per section and hands them to a native
-- menu, which takes an image and cannot be repainted once it is open;
-- process_stats.lua stacks every section into one canvas it owns and repaints
-- it on a timer, which is the only way to get a panel that updates while it is
-- on screen.
--
-- A row is described by which fields it carries rather than by a kind, so a
-- plain reading and a gauged one are the same table with one field more or
-- less:
--
--   label       text on the left of the line
--   value       text on the right of the same line
--   color       colour for `value`, defaulting to the resting one
--   fraction    0..1, drawn as a filled bar under the line
--   gaugeColor  colour of that fill
--   parts       { { fraction, color }, ... } laid end to end instead
--   bars        { { fraction, color }, ... } as a row of vertical slots
--   detail      a smaller, faded line under the bar
--
-- Nothing here knows what a reading means: thresholds, ceilings and units stay
-- with the caller and arrive already resolved to a fraction and a colour.

local panel = {}

-- Asymmetric on purpose for the menu case: AppKit indents a menu item's image
-- by the width of the checkmark column it reserves, so a left inset of our own
-- lands on top of that one and the panel reads as pushed off centre. The right
-- side gets the full margin, which is all the panel actually needs.
panel.WIDTH = 340

local LEFT_MARGIN = 4
local RIGHT_MARGIN = 14
local CONTENT_WIDTH = panel.WIDTH - LEFT_MARGIN - RIGHT_MARGIN

-- What a caller drawing its own surface has to add to the width, and shift
-- the content by, to get the margin back to even on both sides. The lopsided
-- pair above is a correction for the menu's indent, and a panel that is not in
-- a menu is not indented.
panel.EVEN_MARGIN_INSET = RIGHT_MARGIN - LEFT_MARGIN

-- Above the heading and below the last row of a section.
local SECTION_PADDING = 5

-- Air on each side of the rule between two stacked sections, on top of the
-- padding the sections already carry. Sized so a stack lands on the same
-- rhythm a native menu does: there, the separator is a menu item of its own
-- with its own height, which is what a stacked panel has to put back by hand
-- to look like the dropdown next to it.
local SECTION_DIVIDER_GAP = 10

-- Section heading: set at full strength and a touch above the reading size, so
-- the group it names is the first thing read rather than the faintest.
local HEADER_SIZE = 13.5
local HEADER_HEIGHT = 17
local HEADER_GAP = 5

local VALUE_SIZE = 12.5
local VALUE_HEIGHT = 16
local DETAIL_SIZE = 10.5
local DETAIL_HEIGHT = 14

-- The bar under a reading: a full-width track with the reading's share filled
-- in, rounded enough to read as a bar rather than as a rule.
local GAUGE_HEIGHT = 4
local GAUGE_RADIUS = 2
local GAUGE_GAP = 5
local ROW_GAP = 9

-- One slot per reading, each filled from the bottom.
local BARS_HEIGHT = 16
local BARS_GAP = 2

-- Strength of the resting colour for the panel's furniture: the qualifying
-- lines at the first, the empty part of a gauge at the second, the rule
-- between two sections at the third.
--
-- Neither a section heading nor a row's label is in here: both are set in the
-- resting colour at full strength.
local FADED_ALPHA = 0.52
local TRACK_ALPHA = 0.13
local DIVIDER_ALPHA = 0.12
local DIVIDER_HEIGHT = 1

-- The macOS UI font at the size the system sets its own menu items in, so the
-- panel reads as native rather than as a terminal.
local FONT_NAME = ".AppleSystemUIFont"

local LIGHT_COLOR = { white = 0, alpha = 1 }
local DARK_COLOR = { white = 1, alpha = 1 }

-- The warning ladder every readout shares: orange once a figure is warm, red
-- once it is past the point where it costs something. Here rather than in the
-- widgets because the bar and the panel behind it have to agree on what a
-- warning looks like, and two of them draw one.
panel.WARN_COLOR = { red = 1, green = 0.58, blue = 0, alpha = 1 }
panel.CRITICAL_COLOR = { red = 1, green = 0.23, blue = 0.19, alpha = 1 }

-- Ladder for the plain-text mirror of a `bars` row: eight levels is what the
-- block glyphs give, and a strip of twelve sensors reads fine at that.
local SPARK_GLYPHS = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

-- Sized and painted per section, then snapshotted: one canvas serves every
-- section of every open.
local sectionCanvas = hs.canvas.new({ x = 0, y = 0, w = panel.WIDTH, h = panel.WIDTH })

-- Resting colour for a panel, which macOS paints in the appearance of the
-- moment: white text on the dark surface, black on the light one. Read per
-- draw rather than cached, because the appearance can flip under the running
-- config (Auto mode at dusk).
function panel.textColor()
  if hs.host.interfaceStyle() == "Dark" then
    return DARK_COLOR
  end

  return LIGHT_COLOR
end

-- The resting colour at reduced strength, for the panel's own furniture.
function panel.faded(resting, alpha)
  return { white = resting.white, alpha = alpha }
end

-- Colour for one reading against its own pair of thresholds, for the readings
-- that get worse as they climb: red once critical, orange once warm, otherwise
-- the resting colour it was handed — which differs between the bar and the
-- panel, so it is passed in rather than looked up here.
function panel.thresholdColor(value, warnAt, criticalAt, resting)
  if value == nil then
    return resting
  end

  if value >= criticalAt then
    return panel.CRITICAL_COLOR
  end

  if value >= warnAt then
    return panel.WARN_COLOR
  end

  return resting
end

-- Share of a scale, clamped: a reading past its ceiling fills the track rather
-- than overflowing it, and one below zero cannot happen but would draw
-- backwards if it did.
function panel.fraction(value, ceiling)
  if value == nil or ceiling == nil or ceiling <= 0 then
    return 0
  end

  return math.max(0, math.min(1, value / ceiling))
end

-- A panel under construction: the elements drawn so far and the vertical pen
-- they are laid against. Every row appends and advances it, which is the whole
-- layout — nothing has to know its own height in advance.
local function newPanel(offsetX)
  return { elements = {}, x = offsetX or 0, y = SECTION_PADDING }
end

-- One line of text at the pen's height. The label and the figure share the
-- line and the full content width, separated by their alignment alone, which
-- is also what lines the figure up with the right edge of the bar below it
-- without a single string being measured.
local function addText(page, text, size, height, color, alignment)
  local elements = page.elements

  elements[#elements + 1] = {
    type = "text",
    text = text,
    textFont = FONT_NAME,
    textSize = size,
    textColor = color,
    textAlignment = alignment,
    frame = { x = page.x + LEFT_MARGIN, y = page.y, w = CONTENT_WIDTH, h = height },
  }
end

local function barElement(x, y, width, height, color)
  return {
    type = "rectangle",
    action = "fill",
    fillColor = color,
    roundedRectRadii = { xRadius = GAUGE_RADIUS, yRadius = GAUGE_RADIUS },
    frame = { x = x, y = y, w = width, h = height },
  }
end

-- A reading's share of its scale. The track is drawn whatever the reading is,
-- so a figure at zero still shows what it is measured against.
local function addGauge(page, fraction, color, trackColor)
  local elements = page.elements

  elements[#elements + 1] =
    barElement(page.x + LEFT_MARGIN, page.y, CONTENT_WIDTH, GAUGE_HEIGHT, trackColor)

  if fraction > 0 then
    elements[#elements + 1] =
      barElement(page.x + LEFT_MARGIN, page.y, CONTENT_WIDTH * fraction, GAUGE_HEIGHT, color)
  end

  page.y = page.y + GAUGE_HEIGHT
end

-- Several shares of one scale laid end to end, for a total worth breaking
-- down.
local function addSegments(page, parts, trackColor)
  local elements = page.elements
  local x = page.x + LEFT_MARGIN

  elements[#elements + 1] =
    barElement(x, page.y, CONTENT_WIDTH, GAUGE_HEIGHT, trackColor)

  for _, part in ipairs(parts) do
    local width = CONTENT_WIDTH * part.fraction

    if width > 0 then
      elements[#elements + 1] = barElement(x, page.y, width, GAUGE_HEIGHT, part.color)
      x = x + width
    end
  end

  page.y = page.y + GAUGE_HEIGHT
end

-- A row of slots filled from the bottom: the shape a summary figure only
-- averages, and the reason a caller reports a set rather than the mean of it.
local function addBars(page, bars, trackColor)
  local count = #bars

  if count == 0 then
    return
  end

  local elements = page.elements
  local slotWidth = (CONTENT_WIDTH - BARS_GAP * (count - 1)) / count

  for index, bar in ipairs(bars) do
    local x = page.x + LEFT_MARGIN + (slotWidth + BARS_GAP) * (index - 1)
    local filled = BARS_HEIGHT * bar.fraction

    elements[#elements + 1] = barElement(x, page.y, slotWidth, BARS_HEIGHT, trackColor)

    if filled > 0 then
      elements[#elements + 1] =
        barElement(x, page.y + BARS_HEIGHT - filled, slotWidth, filled, bar.color)
    end
  end

  page.y = page.y + BARS_HEIGHT
end

-- One row: its line of text, whichever bar it carries, and the smaller line
-- that qualifies it.
local function addRow(page, row, resting)
  local faded = panel.faded(resting, FADED_ALPHA)
  local track = panel.faded(resting, TRACK_ALPHA)
  local hasBar = row.fraction ~= nil or row.parts ~= nil or row.bars ~= nil

  if row.label ~= nil then
    addText(page, row.label, VALUE_SIZE, VALUE_HEIGHT, resting, "left")
  end

  if row.value ~= nil then
    addText(page, row.value, VALUE_SIZE, VALUE_HEIGHT, row.color or resting, "right")
  end

  if row.label ~= nil or row.value ~= nil then
    page.y = page.y + VALUE_HEIGHT + (hasBar and GAUGE_GAP or 0)
  end

  if row.fraction ~= nil then
    addGauge(page, row.fraction, row.gaugeColor, track)
  elseif row.parts ~= nil then
    addSegments(page, row.parts, track)
  elseif row.bars ~= nil then
    addBars(page, row.bars, track)
  end

  if row.detail ~= nil then
    page.y = page.y + GAUGE_GAP
    addText(page, row.detail, DETAIL_SIZE, DETAIL_HEIGHT, faded, "left")
    page.y = page.y + DETAIL_HEIGHT
  end
end

-- One heading and its rows, appended at the pen.
local function addSection(page, section, resting)
  local rows = section.rows

  addText(page, section.header, HEADER_SIZE, HEADER_HEIGHT, resting, "left")

  page.y = page.y + HEADER_HEIGHT + HEADER_GAP

  for index, row in ipairs(rows) do
    if index > 1 then
      page.y = page.y + ROW_GAP
    end

    addRow(page, row, resting)
  end
end

-- One section as an image, for a menu item. The canvas is resized to whatever
-- the rows turned out to need rather than to a figure worked out in advance.
function panel.sectionImage(section, resting)
  local page = newPanel()

  addSection(page, section, resting)

  sectionCanvas:size({ w = panel.WIDTH, h = page.y + SECTION_PADDING })
  sectionCanvas:replaceElements(table.unpack(page.elements))

  return sectionCanvas:imageFromCanvas()
end

-- Every section stacked into one set of elements, with a rule between each
-- pair, for a canvas the caller owns and repaints. `offsetX` shifts the whole
-- stack right, which is how a caller drawing its own surface pays back
-- EVEN_MARGIN_INSET. Returns the elements and the height they need.
function panel.stack(sections, resting, offsetX)
  local page = newPanel(offsetX)
  local divider = panel.faded(resting, DIVIDER_ALPHA)

  for index, section in ipairs(sections) do
    if index > 1 then
      -- Edge to edge, the way a native menu separator runs, rather than
      -- inset to the rows: the rule is between two sections, not part of one.
      page.y = page.y + SECTION_DIVIDER_GAP
      page.elements[#page.elements + 1] =
        barElement(0, page.y, panel.WIDTH + page.x, DIVIDER_HEIGHT, divider)
      page.y = page.y + DIVIDER_HEIGHT + SECTION_DIVIDER_GAP
    end

    addSection(page, section, resting)
  end

  return page.elements, page.y + SECTION_PADDING
end

-- The plain-text mirror of one row, for reading a panel from `hs -c` without
-- opening it. A gauge has no text to mirror; a row of slots does, as the block
-- glyphs the fractions land on.
function panel.rowText(row)
  local lines = {}

  if row.value ~= nil then
    lines[#lines + 1] = string.format("  %-27s %s", row.label or "", row.value)
  elseif row.label ~= nil then
    lines[#lines + 1] = "  " .. row.label
  end

  if row.bars ~= nil then
    local glyphs = {}
    local topGlyph = #SPARK_GLYPHS

    for index, bar in ipairs(row.bars) do
      glyphs[index] = SPARK_GLYPHS[math.max(1, math.ceil(bar.fraction * topGlyph))]
    end

    lines[#lines + 1] = "  " .. table.concat(glyphs)
  end

  if row.detail ~= nil then
    lines[#lines + 1] = "  " .. row.detail
  end

  return table.concat(lines, "\n")
end

-- Every section as text, headings included.
function panel.stackText(sections)
  local lines = {}

  for _, section in ipairs(sections) do
    lines[#lines + 1] = section.header

    for _, row in ipairs(section.rows) do
      lines[#lines + 1] = panel.rowText(row)
    end
  end

  return table.concat(lines, "\n")
end

return panel
