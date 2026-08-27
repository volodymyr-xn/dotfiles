-- The stacked-column menubar row: two rows of figures in the height of the
-- bar, laid out left to right and handed over as an hs.menubar item's *icon*.
--
-- An icon rather than a title because a menubar title is a single line of text
-- however it is styled, so two rows in 22 points cannot be done any other way.
--
-- Shared because two menubar items draw the same row for different readings —
-- system_stats.lua stacks six columns of sensor figures, network_stats.lua one
-- column of throughput — and the two have to be indistinguishable in the bar.
-- Nothing here knows what a figure means: units, thresholds and colours stay
-- with the caller and arrive already resolved to text and a colour.
--
-- A column is described by which bands it carries rather than by a kind:
--
--   top           the upper band, or the whole height when there is no bottom
--   bottom        the lower band, absent for a column carrying one figure
--   reservedWidth points the column claims whatever it reads, right-aligning
--                 its figures inside that; nil to size to the content
--
-- A band is { text, color, font, icon } — `font` defaulting to the stacked-row
-- face, `icon` naming an SVG in assets/ that heads the figure.
--
-- Usage:
--   local menubarRow = require("menubar_row")
--   local row = menubarRow.new()
--   local plainText = row.paint(menu, columns)

local statPanel = require("stat_panel")

local M = {}

-- Height of the macOS menubar, and the two rows the columns are drawn on:
-- each figure is centred in its own half of that height.
local BAR_HEIGHT = 22
local ROW_COUNT = 2

-- Points between one column and the next. Laid out in points rather than
-- padded with spaces, because the system font's digits are proportional.
-- Wide enough that the columns read as separate without a label between
-- them: the unit on each figure is what names it.
local COLUMN_GAP = 10

-- Separate the figures in the plain-text mirror only; on the bar the two
-- bands of a column are stacked and the columns are spaced in points.
local VALUE_SEPARATOR = " "
local COLUMN_SEPARATOR = "  "

local ICON_DIRECTORY = hs.configdir .. "/assets/"

-- The token every icon paints itself with. Substituted for a hex colour at
-- render, which is how one file serves the light bar and the dark one;
-- SVG's own `currentColor` never resolves inside an NSImage.
local ICON_COLOR_TOKEN = "currentColor"

-- Square, sized to the row it sits in rather than the whole bar, with a
-- point of air after it.
local ICON_SIZE = BAR_HEIGHT / ROW_COUNT - 2
local ICON_TEXT_GAP = 2

-- Roughly the share of a line box the system font leaves below the baseline.
-- Half of it is what a digits-only figure has to come down by to sit on the
-- optical centre rather than the geometric one.
local DESCENDER_SHARE = 0.09

-- The macOS UI font, which is what the Stats app draws its widgets with
-- (NSFont.systemFont); the hidden PostScript name is how AppKit exposes it.
-- Two rows in the height of the menubar leave room for about 10pt, which is
-- the size Stats sets its own stacked widgets in.
M.FONT = { name = ".AppleSystemUIFont", size = 10 }

-- A column carrying one figure spans both rows, so it can afford a size the
-- stacked columns cannot.
M.SOLO_FONT = { name = ".AppleSystemUIFont", size = 13.9 }

-- Bold at the solo size, for the cell that carries a word instead of a
-- figure and would otherwise read lighter than the numbers beside it.
M.SOLO_BOLD_FONT = { name = ".AppleSystemUIFontBold", size = 13.9 }

-- Raw SVG source per file, and rendered images per file-and-colour. Both are
-- permanent and shared across rows: a handful of icons across a handful of
-- colours.
local iconSources = {}
local iconImages = {}

-- Measured size per string-and-face. Measuring is by far the most expensive
-- thing a repaint does — hs.drawing.getTextDrawingSize costs about 6ms a
-- string on macOS 26, and a row of five stacked columns measures eight of
-- them — and the figures on the bar repeat: a temperature has a few dozen
-- forms, a percentage a hundred. So after a minute of running almost every
-- measurement is a hit and a paint costs the canvas alone.
--
-- Keyed without the colour, which no glyph metric depends on. Dropped whole
-- rather than aged when it grows past the cap: rebuilding it costs one slow
-- paint, and tracking use order to evict better would cost more than that
-- every paint in between.
local MEASURE_CACHE_LIMIT = 1024

local measuredSizes = {}
local measuredCount = 0

-- The row follows the system appearance, same as the panel behind it: white
-- text in Dark, black in Light. It does not follow the wallpaper the way macOS
-- tints its own items — that needs the strip behind the bar sampled, which
-- nothing in Hammerspoon exposes.
function M.textColor()
  return statPanel.textColor()
end

-- "#RRGGBB" for an hs.drawing colour table, so the same colour drives both
-- the text attributes and the icon substitution. Handles the greyscale form
-- (`white`) as well as the RGB one.
local function colorHex(color)
  local red = color.red or color.white or 0
  local green = color.green or color.white or 0
  local blue = color.blue or color.white or 0

  return string.format("#%02X%02X%02X", red * 255, green * 255, blue * 255)
end

-- SVG source for an icon, read once per file.
local function iconSource(name)
  local cached = iconSources[name]

  if cached ~= nil then
    return cached
  end

  local file = io.open(ICON_DIRECTORY .. name .. ".svg", "r")

  if file == nil then
    return nil
  end

  local source = file:read("a")
  file:close()
  iconSources[name] = source

  return source
end

-- An icon painted in one specific colour. Built through a data URL rather
-- than imageFromPath because the colour is stamped into the source first.
local function iconImage(name, color)
  local hex = colorHex(color)
  local key = name .. hex
  local cached = iconImages[key]

  if cached ~= nil then
    return cached
  end

  local source = iconSource(name)

  if source == nil then
    return nil
  end

  local svg = source:gsub(ICON_COLOR_TOKEN, hex)
  local image = hs.image.imageFromURL("data:image/svg+xml;base64," .. hs.base64.encode(svg))
  iconImages[key] = image

  return image
end

-- Styled run for one band of the row, in the colour and size that band
-- carries; a band without a font of its own takes the stacked-row one.
local function styledValue(text, color, font)
  return hs.styledtext.new(text, { font = font or M.FONT, color = color })
end

-- The size a styled run draws at, measured once per string-and-face.
local function measuredSize(styled, text, font)
  local face = font or M.FONT
  local key = face.name .. face.size .. text
  local cached = measuredSizes[key]

  if cached ~= nil then
    return cached
  end

  local size = hs.drawing.getTextDrawingSize(styled)

  if measuredCount >= MEASURE_CACHE_LIMIT then
    measuredSizes = {}
    measuredCount = 0
  end

  measuredSizes[key] = size
  measuredCount = measuredCount + 1

  return size
end

-- Width a column claims whatever it currently reads: its widest form, plus
-- the icon and the gap after it when the column carries one. Callers reserve
-- the columns whose figures swing several digits at a time, so a spike does
-- not push everything to its right sideways.
function M.reservedWidth(template, font, withIcon)
  local width = measuredSize(styledValue(template, M.textColor(), font), template, font).w

  if withIcon then
    return width + ICON_SIZE + ICON_TEXT_GAP
  end

  return width
end

-- Vertical placement for content starting at one row and spanning `span` of
-- them: the rows split the bar evenly and the content sits in the middle of
-- the band it was given, whatever height it turns out to have.
--
-- A figure spanning the whole bar gets nudged down by the descender space it
-- does not use — "20G" has nothing below the baseline, so centring its
-- measured box leaves the glyphs visibly high. Stacked rows sit too close
-- together for the same correction to read as anything but misalignment.
local function rowOrigin(row, span, height)
  local rowHeight = BAR_HEIGHT / ROW_COUNT
  local origin = row * rowHeight + (rowHeight * span - height) / 2

  if span > 1 then
    return origin + height * DESCENDER_SHARE
  end

  return origin
end

-- One text element, from a run whose size the caller already measured: the
-- band needs the size to place the run, and asking for it twice would pay the
-- measurement twice on a string the cache has not seen yet.
local function textElement(styled, size, x, row, span)
  return {
    type = "text",
    text = styled,
    -- A point of slack on the width: the measured size rounds down often
    -- enough to clip the last glyph otherwise.
    frame = { x = x, y = rowOrigin(row, span, size.h), w = size.w + 1, h = size.h },
  }
end

-- The icon that heads one band, or nil when the band carries none or its file
-- failed to load — a missing asset costs the glyph, not the reading.
local function iconElement(name, color, x, row, span)
  local image = iconImage(name, color)

  if image == nil then
    return nil
  end

  return {
    type = "image",
    image = image,
    imageScaling = "scaleProportionally",
    frame = { x = x, y = rowOrigin(row, span, ICON_SIZE), w = ICON_SIZE, h = ICON_SIZE },
  }
end

-- One band of a column: its icon, if any, then the figure. Returns the width
-- the pair claimed, so the column can size itself to its widest band.
--
-- `boxWidth` reserves the band: the icon stays at the left edge and the
-- figure is pushed against the right one, so a value that grows a digit eats
-- the reserved gap instead of widening the row.
local function bandElements(band, x, row, span, boxWidth, elements)
  local textX = x
  local iconWidth = 0

  if band.icon ~= nil then
    local icon = iconElement(band.icon, band.color, x, row, span)

    if icon ~= nil then
      elements[#elements + 1] = icon
      iconWidth = ICON_SIZE + ICON_TEXT_GAP
      textX = x + iconWidth
    end
  end

  local styled = styledValue(band.text, band.color, band.font)
  local size = measuredSize(styled, band.text, band.font)

  if boxWidth ~= nil then
    textX = x + boxWidth - size.w
  end

  elements[#elements + 1] = textElement(styled, size, textX, row, span)

  return iconWidth + size.w
end

-- One row and the canvas it is painted into. Per-instance rather than shared:
-- the canvas is resized to the columns it was last given, and two widgets
-- painting on the same cadence would resize it out from under each other.
function M.new()
  local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = BAR_HEIGHT })
  local row = {}

  -- Lay the columns out left to right and hand the snapshot to `menu`. The two
  -- bands of a column share a left edge, so the pair reads as one block rather
  -- than two stray numbers. Returns the plain-text mirror of what was painted.
  function row.paint(menu, columns)
    local elements = {}
    local plainParts = {}
    local x = 0

    for _, column in ipairs(columns) do
      local top = column.top
      local bottom = column.bottom
      local reserved = column.reservedWidth
      local plainText = top.text
      local columnWidth

      if bottom == nil then
        -- Nothing to stack under it, so the figure takes the whole height and
        -- the larger face that comes with it.
        columnWidth = bandElements(top, x, 0, ROW_COUNT, reserved, elements)
      else
        columnWidth = math.max(bandElements(top, x, 0, 1, reserved, elements),
          bandElements(bottom, x, 1, 1, reserved, elements))
        plainText = plainText .. VALUE_SEPARATOR .. bottom.text
      end

      if reserved ~= nil then
        columnWidth = math.max(columnWidth, reserved)
      end

      x = x + columnWidth + COLUMN_GAP
      plainParts[#plainParts + 1] = plainText
    end

    canvas:size({ w = x - COLUMN_GAP, h = BAR_HEIGHT })
    canvas:replaceElements(table.unpack(elements))

    -- template = false keeps the colours: the default treats the image as a
    -- mask and repaints the whole row in the menubar's own tint.
    menu:setIcon(canvas:imageFromCanvas(), false)

    return table.concat(plainParts, COLUMN_SEPARATOR)
  end

  return row
end

return M
