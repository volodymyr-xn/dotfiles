-- Drawing for the launchd-jobs menu: one card per job and a summary header
-- over them, each painted into a canvas and snapshotted as the image of a
-- native menu item — the way system_stats hands its sections to a menu.
--
-- A card, top to bottom: a status dot, the job's name and a countdown to its
-- next run; its launchctl label and the date of that run; the description;
-- the schedule as a weekday strip and times, or as chips; a bar of how far
-- the job is from its last run to its next; and the last run, how it ended,
-- and whether launchd has the job loaded.
--
-- Nothing here reads the system or knows what a reading means. The caller
-- hands over a view of plain strings, flags and fractions, already resolved:
--
--   name, label, description   text; description may be nil
--   status        "loaded" | "running" | "failing" | "unloaded"
--   countdown     "in 3d 3h", nil without a next run
--   soon          true when the countdown is close enough to draw in accent
--   nextDate      "Sun 11 Oct 21:10", nil without a next run
--   weekly        { weekdays = { [slot] = true }, times = { "10:00" } }
--                 with Monday as slot 1, nil when the calendar is not weekly
--   todaySlot     today's Monday-first slot, ringed on the weekday strip
--   chips         schedule phrases drawn as chips after the strip
--   progress      0..1 from last run to next run, nil to skip the bar
--   exit          "ok" | "failed" | "none"
--   lastRun       "Ran 3d 20h ago"
--   exitText      "exit 1", drawn in red; nil unless the exit failed
--   state         "Loaded" | "Running · pid 123" | "Not loaded"
--
-- The background is left transparent so the menu's own material shows
-- through: a filled card would read as a box pasted onto the menu.

local statPanel = require("stat_panel")

local M = {}

M.WIDTH = 400

-- AppKit indents a menu item's image by the width of its checkmark column,
-- so the left margin is small; the right one clears the submenu chevron.
local LEFT_MARGIN = 4
local RIGHT_MARGIN = 12
local CONTENT_WIDTH = M.WIDTH - LEFT_MARGIN - RIGHT_MARGIN

-- Everything under the title lines up with the title, not with the dot.
local TEXT_INSET = 18
local TEXT_X = LEFT_MARGIN + TEXT_INSET
local TEXT_WIDTH = CONTENT_WIDTH - TEXT_INSET

local PADDING = 10

-- Space kept between a left-aligned text and a right-aligned one sharing a
-- row, and between the parts laid along the schedule row.
local COLUMN_GAP = 12
local INLINE_GAP = 8

local REGULAR_FONT = ".AppleSystemUIFont"
local MEDIUM_FONT = ".AppleSystemUIFontMedium"
local SEMIBOLD_FONT = ".AppleSystemUIFontDemi"

-- Type roles. `height` is the line box the role is laid out in; canvas text
-- is anchored at the top of its frame, so rows of different roles centre
-- against each other by the difference between these.
local TITLE = { font = SEMIBOLD_FONT, size = 15, height = 20 }
local COUNTDOWN = { font = MEDIUM_FONT, size = 15, height = 20 }
local BODY = { font = REGULAR_FONT, size = 13.5, height = 18 }
local TIME = { font = MEDIUM_FONT, size = 13, height = 17 }
local META = { font = REGULAR_FONT, size = 12, height = 16 }
local BADGE = { font = SEMIBOLD_FONT, size = 12, height = 16 }
local DAY = { font = SEMIBOLD_FONT, size = 11, height = 14 }

-- Vertical rhythm between the card's rows.
local TITLE_GAP = 1
local LABEL_GAP = 8
local DESCRIPTION_GAP = 10
local SCHEDULE_GAP = 12
local PROGRESS_GAP = 8
local HEADER_ROW_GAP = 6

local DOT_SIZE = 9

local DESCRIPTION_MAX_LINES = 2

-- One square cell per weekday, and the chips beside them share its height.
local SCHEDULE_HEIGHT = 20
local DAY_CELL = 20
local DAY_GAP = 4
local DAY_RADIUS = 6
local WEEKDAY_INITIALS = { "M", "T", "W", "T", "F", "S", "S" }

local CHIP_PADDING = 8
local CHIP_MIN_WIDTH = 32

local BAR_HEIGHT = 4
local BADGE_WIDTH = 15

-- macOS system green and blue. One value each serves both appearances: the
-- two are saturated enough to hold on light and dark menus alike.
local GREEN = { red = 0.19, green = 0.78, blue = 0.35, alpha = 1 }
local BLUE = { red = 0.04, green = 0.52, blue = 1, alpha = 1 }
local ON_ACCENT = { white = 1, alpha = 1 }

-- Strengths of the resting colour for the card's secondary layers.
local DESCRIPTION_ALPHA = 0.82
local META_ALPHA = 0.55
local CHIP_FILL_ALPHA = 0.09
local CHIP_TEXT_ALPHA = 0.85
local IDLE_DAY_ALPHA = 0.45
local TODAY_RING_ALPHA = 0.5
local TRACK_ALPHA = 0.13
local UNLOADED_DOT_ALPHA = 0.35

local EXIT_BADGES = {
  ok = "✓",
  failed = "✕",
  none = "–",
}

-- Painted, resized and snapshotted per card: one canvas serves them all.
local canvas = hs.canvas.new({ x = 0, y = 0, w = M.WIDTH, h = M.WIDTH })

-- Width a text needs in a type role, rounded up to whole points.
local function measuredWidth(text, role)
  local styled = hs.styledtext.new(text, {
    font = { name = role.font, size = role.size },
  })

  return math.ceil(canvas:minimumTextSize(styled).w)
end

-- One line of text, cut short with an ellipsis rather than wrapped onto a
-- second line the frame has no room for.
local function textElement(text, role, color, frame, alignment)
  return {
    type = "text",
    text = text,
    textFont = role.font,
    textSize = role.size,
    textColor = color,
    textAlignment = alignment or "left",
    textLineBreak = "truncateTail",
    frame = frame,
  }
end

-- A filled rectangle with rounded corners.
local function filledRect(frame, radius, color)
  return {
    type = "rectangle",
    action = "fill",
    fillColor = color,
    roundedRectRadii = { xRadius = radius, yRadius = radius },
    frame = frame,
  }
end

-- Add one element to the page being laid out.
local function append(page, element)
  page.elements[#page.elements + 1] = element
end

-- The dot's colour: what a glance at the menu should take away first.
local function statusColor(status, resting)
  if status == "running" then
    return BLUE
  end

  if status == "failing" then
    return statPanel.CRITICAL_COLOR
  end

  if status == "loaded" then
    return GREEN
  end

  return statPanel.faded(resting, UNLOADED_DOT_ALPHA)
end

-- Status dot, name, and the countdown to the next run.
local function addTitleRow(page, view, resting)
  local countdownWidth = 0

  if view.countdown ~= nil then
    countdownWidth = measuredWidth(view.countdown, COUNTDOWN) + COLUMN_GAP

    append(page, textElement(view.countdown, COUNTDOWN,
      view.soon and BLUE or resting,
      { x = TEXT_X, y = page.y, w = TEXT_WIDTH, h = COUNTDOWN.height },
      "right"
    ))
  end

  append(page, {
    type = "circle",
    action = "fill",
    fillColor = statusColor(view.status, resting),
    center = {
      x = LEFT_MARGIN + DOT_SIZE / 2 + 1,
      y = page.y + TITLE.height / 2 + 1,
    },
    radius = DOT_SIZE / 2,
  })
  append(page, textElement(view.name, TITLE, resting, {
    x = TEXT_X,
    y = page.y,
    w = TEXT_WIDTH - countdownWidth,
    h = TITLE.height,
  }))

  page.y = page.y + TITLE.height
end

-- launchctl label on the left, the next run's date on the right.
local function addLabelRow(page, view, resting)
  local meta = statPanel.faded(resting, META_ALPHA)
  local dateWidth = 0

  if view.nextDate ~= nil then
    dateWidth = measuredWidth(view.nextDate, META) + COLUMN_GAP

    append(page, textElement(view.nextDate, META, meta,
      { x = TEXT_X, y = page.y, w = TEXT_WIDTH, h = META.height }, "right"
    ))
  end

  local label = textElement(view.label, META, meta, {
    x = TEXT_X,
    y = page.y,
    w = TEXT_WIDTH - dateWidth,
    h = META.height,
  })

  -- Cut from the middle: a label's distinctive part is its tail, and the
  -- head says whose it is.
  label.textLineBreak = "truncateMiddle"
  append(page, label)

  page.y = page.y + META.height
end

-- The description under the label, wrapped onto a second line when it does
-- not fit on one. Anything past the second line is clipped.
local function addDescription(page, description, resting)
  local lineCount = measuredWidth(description, BODY) > TEXT_WIDTH
    and DESCRIPTION_MAX_LINES or 1
  local height = BODY.height * lineCount
  local element = textElement(description, BODY,
    statPanel.faded(resting, DESCRIPTION_ALPHA),
    { x = TEXT_X, y = page.y, w = TEXT_WIDTH, h = height }
  )

  element.textLineBreak = "wordWrap"
  append(page, element)

  page.y = page.y + height
end

-- Seven day cells, Monday first, the scheduled ones filled in accent and
-- today's ringed. Returns where the next part of the row may start.
local function addWeekdayStrip(page, weekly, todaySlot, resting)
  local idleFill = statPanel.faded(resting, CHIP_FILL_ALPHA)
  local idleText = statPanel.faded(resting, IDLE_DAY_ALPHA)

  for slot, initial in ipairs(WEEKDAY_INITIALS) do
    local x = TEXT_X + (DAY_CELL + DAY_GAP) * (slot - 1)
    local scheduled = weekly.weekdays[slot] == true

    append(page, filledRect({ x = x, y = page.y, w = DAY_CELL, h = DAY_CELL },
      DAY_RADIUS, scheduled and BLUE or idleFill
    ))

    if slot == todaySlot then
      -- Inset by half a point so the stroke lands inside the cell rather
      -- than straddling its edge.
      append(page, {
        type = "rectangle",
        action = "stroke",
        strokeColor = statPanel.faded(resting, TODAY_RING_ALPHA),
        strokeWidth = 1,
        roundedRectRadii = { xRadius = DAY_RADIUS, yRadius = DAY_RADIUS },
        frame = { x = x + 0.5, y = page.y + 0.5, w = DAY_CELL - 1, h = DAY_CELL - 1 },
      })
    end

    append(page, textElement(initial, DAY, scheduled and ON_ACCENT or idleText, {
      x = x,
      y = page.y + (DAY_CELL - DAY.height) / 2,
      w = DAY_CELL,
      h = DAY.height,
    }, "center"
    ))
  end

  return TEXT_X + (DAY_CELL + DAY_GAP) * #WEEKDAY_INITIALS - DAY_GAP + INLINE_GAP
end

-- The times a weekly job fires at, beside its strip.
local function addTimes(page, times, x, resting)
  local text = table.concat(times, ", ")
  local width = math.min(measuredWidth(text, TIME), TEXT_X + TEXT_WIDTH - x)

  append(page, textElement(text, TIME, resting, {
    x = x,
    y = page.y + (SCHEDULE_HEIGHT - TIME.height) / 2,
    w = width,
    h = TIME.height,
  }))

  return x + width + INLINE_GAP
end

-- One schedule phrase as a chip. Shortened with an ellipsis when the row is
-- nearly full; nil once there is no room left for even a short one.
local function addChip(page, text, x, resting)
  local available = TEXT_X + TEXT_WIDTH - x
  local width = math.min(measuredWidth(text, META) + CHIP_PADDING * 2, available)

  if width < CHIP_MIN_WIDTH then
    return nil
  end

  append(page, filledRect({ x = x, y = page.y, w = width, h = SCHEDULE_HEIGHT },
    SCHEDULE_HEIGHT / 2, statPanel.faded(resting, CHIP_FILL_ALPHA)
  ))
  append(page, textElement(text, META, statPanel.faded(resting, CHIP_TEXT_ALPHA), {
    x = x + CHIP_PADDING,
    y = page.y + (SCHEDULE_HEIGHT - META.height) / 2,
    w = width - CHIP_PADDING * 2,
    h = META.height,
  }))

  return x + width + INLINE_GAP / 2
end

-- Weekday strip and times when the calendar is weekly, then a chip per
-- remaining trigger.
local function addScheduleRow(page, view, resting)
  local x = TEXT_X

  if view.weekly ~= nil then
    x = addWeekdayStrip(page, view.weekly, view.todaySlot, resting)
    x = addTimes(page, view.weekly.times, x, resting)
  end

  for _, chip in ipairs(view.chips) do
    x = addChip(page, chip, x, resting)

    if x == nil then
      break
    end
  end

  page.y = page.y + SCHEDULE_HEIGHT
end

-- How far the job is from its last run to its next.
local function addProgress(page, progress, resting)
  append(page, filledRect({ x = TEXT_X, y = page.y, w = TEXT_WIDTH, h = BAR_HEIGHT },
    BAR_HEIGHT / 2, statPanel.faded(resting, TRACK_ALPHA)
  ))

  if progress > 0 then
    append(page, filledRect(
      { x = TEXT_X, y = page.y, w = TEXT_WIDTH * progress, h = BAR_HEIGHT },
      BAR_HEIGHT / 2, BLUE
    ))
  end

  page.y = page.y + BAR_HEIGHT
end

-- Green tick, red cross, or a faded dash when no run has finished.
local function badgeColor(exit, resting)
  if exit == "ok" then
    return GREEN
  end

  if exit == "failed" then
    return statPanel.CRITICAL_COLOR
  end

  return statPanel.faded(resting, META_ALPHA)
end

-- Exit badge, last run and a failed exit code on the left; launchd's state
-- on the right.
local function addFooterRow(page, view, resting)
  local meta = statPanel.faded(resting, META_ALPHA)
  local stateWidth = measuredWidth(view.state, META) + COLUMN_GAP
  local lastRunX = TEXT_X + BADGE_WIDTH
  local lastRunWidth = math.min(measuredWidth(view.lastRun, META),
    TEXT_WIDTH - BADGE_WIDTH - stateWidth
  )

  append(page, textElement(EXIT_BADGES[view.exit], BADGE,
    badgeColor(view.exit, resting),
    { x = TEXT_X, y = page.y, w = BADGE_WIDTH, h = BADGE.height }
  ))
  append(page, textElement(view.lastRun, META, meta,
    { x = lastRunX, y = page.y, w = lastRunWidth, h = META.height }
  ))

  if view.exitText ~= nil then
    local exitX = lastRunX + lastRunWidth + INLINE_GAP

    append(page, textElement(view.exitText, META, statPanel.CRITICAL_COLOR, {
      x = exitX,
      y = page.y,
      w = TEXT_X + TEXT_WIDTH - stateWidth - exitX,
      h = META.height,
    }))
  end

  append(page, textElement(view.state, META, meta,
    { x = TEXT_X, y = page.y, w = TEXT_WIDTH, h = META.height }, "right"
  ))

  page.y = page.y + META.height
end

-- Snapshot the elements laid out on `page` at the height they came to.
local function pageImage(page)
  canvas:size({ w = M.WIDTH, h = page.y + PADDING })
  canvas:replaceElements(table.unpack(page.elements))

  return canvas:imageFromCanvas()
end

-- One job's card as a menu item image.
function M.jobImage(view, resting)
  local page = { elements = {}, y = PADDING }

  addTitleRow(page, view, resting)
  page.y = page.y + TITLE_GAP
  addLabelRow(page, view, resting)
  page.y = page.y + LABEL_GAP

  if view.description ~= nil then
    addDescription(page, view.description, resting)
    page.y = page.y + DESCRIPTION_GAP
  end

  addScheduleRow(page, view, resting)
  page.y = page.y + SCHEDULE_GAP

  if view.progress ~= nil then
    addProgress(page, view.progress, resting)
    page.y = page.y + PROGRESS_GAP
  end

  addFooterRow(page, view, resting)

  return pageImage(page)
end

-- A count with a coloured dot before it, laid right to left from `right`.
-- Returns where the next one, further left, has to end.
local function addCount(page, text, color, right, resting)
  local width = measuredWidth(text, META)
  local textX = right - width
  local y = page.y + (TITLE.height - META.height) / 2

  append(page, textElement(text, META, statPanel.faded(resting, META_ALPHA),
    { x = textX, y = y, w = width, h = META.height }
  ))
  append(page, {
    type = "circle",
    action = "fill",
    fillColor = color,
    center = { x = textX - 8, y = y + META.height / 2 + 0.5 },
    radius = 3.5,
  })

  return textX - 8 - 3.5 - COLUMN_GAP
end

-- The summary over the cards:
--   title     "Launchd agents"
--   loaded    "3 loaded"
--   failing   "1 failing", nil when nothing is
--   nextName  name of the job that runs next, nil when none is scheduled
--   nextIn    "in 12m"
--   empty     line shown in place of the next-up row when there are no jobs
function M.headerImage(view, resting)
  local page = { elements = {}, y = PADDING }
  local right = TEXT_X + TEXT_WIDTH

  if view.failing ~= nil then
    right = addCount(page, view.failing, statPanel.CRITICAL_COLOR, right, resting)
  end

  if view.loaded ~= nil then
    right = addCount(page, view.loaded, GREEN, right, resting)
  end

  append(page, textElement(view.title, TITLE, resting, {
    x = LEFT_MARGIN,
    y = page.y,
    w = right - LEFT_MARGIN,
    h = TITLE.height,
  }))

  page.y = page.y + TITLE.height + HEADER_ROW_GAP

  local meta = statPanel.faded(resting, META_ALPHA)

  if view.nextName == nil then
    append(page, textElement(view.empty, BODY, meta,
      { x = LEFT_MARGIN, y = page.y, w = CONTENT_WIDTH, h = BODY.height }
    ))
  else
    local prefix = "Next up"
    local prefixWidth = measuredWidth(prefix, META) + INLINE_GAP
    local countdownWidth = measuredWidth(view.nextIn, TIME) + COLUMN_GAP
    local metaY = page.y + (BODY.height - META.height) / 2

    append(page, textElement(prefix, META, meta,
      { x = LEFT_MARGIN, y = metaY, w = prefixWidth, h = META.height }
    ))
    append(page, textElement(view.nextName, BODY, resting, {
      x = LEFT_MARGIN + prefixWidth,
      y = page.y,
      w = CONTENT_WIDTH - prefixWidth - countdownWidth,
      h = BODY.height,
    }))
    append(page, textElement(view.nextIn, TIME, BLUE, {
      x = LEFT_MARGIN,
      y = page.y + (BODY.height - TIME.height) / 2,
      w = CONTENT_WIDTH,
      h = TIME.height,
    }, "right"
    ))
  end

  page.y = page.y + BODY.height

  return pageImage(page)
end

return M
