-- Menubar readout of what the machine's processes are doing: the heaviest few
-- by CPU, by energy and by memory, over the uptime and load average they add
-- up to.
--
-- The bar itself carries a gear and nothing else. Everything here is a list of
-- processes and a list does not fit in a menubar, so the icon is static: no
-- timer runs while the panel is shut, and c-process-stats-macos is not spawned
-- at all until someone looks.
--
-- The panel is an hs.canvas rather than a menu, which is what buys the
-- once-a-second refresh. A native NSMenu runs a modal event loop while it is
-- tracking — Hammerspoon's timers do not fire during it, and hs.menubar hands
-- out no reference to an item already on screen — so a menu can only ever show
-- the readings it was built with. Owning the surface costs the dismissal a
-- menu gives away for free, so a click outside, Escape, and a second click on
-- the icon are all wired up below.
--
-- The rows are drawn by stat_panel, which the sensors widget shares; only the
-- readings and their units are this file's.
--
-- Rates are a delta between two of the helper's reports, measured against a
-- monotonic clock on this side rather than against anything in the report:
-- the helper reports cumulative totals, because a rate needs two samples and
-- it takes one. The first open after a reload has nothing to diff against and
-- falls back to the mean over each process's life, which reads low; a second
-- later the panel is showing real per-second figures.

-- One widget per Hammerspoon instance, for the same reason system_stats.lua
-- guards itself: modules/ is on package.path, so this file is reachable under
-- two names and a second require would paint a second gear.
local INSTANCE_KEY = "processStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local statFormat = require("stat_format")
local statPanel = require("stat_panel")

-- Absolute path because hs.task and hs.execute do not consult the login
-- shell's PATH, which is where ~/dotfiles/bin_native/macos is added.
local NATIVE_DIRECTORY = os.getenv("HOME") .. "/dotfiles/bin_native/macos/"
local PROCESS_HELPER = NATIVE_DIRECTORY .. "c-process-stats-macos"

-- Drawn as a template image, so AppKit repaints the mask in whatever colour
-- the menubar wants and the gear follows Dark and Light with no redraw of
-- ours.
--
-- No size is set here: hs.menubar fits an icon to the menubar height whatever
-- the image claims, so how large the gear reads is decided by the padding
-- around it inside the asset's viewBox, not from this side.
local ICON_PATH = hs.configdir .. "/assets/gear.svg"
local ICON_FALLBACK_TITLE = "proc"

-- While the panel is open. The helper costs about 4ms, and a second is fast
-- enough that a process spinning up is visible without the figures flickering
-- too hard to read.
local REFRESH_SECONDS = 1

local TOP_PROCESS_COUNT = 4

-- Characters a process name gets before it is cut short. An Electron helper
-- runs past the figure it shares a line with otherwise.
local PROCESS_NAME_LIMIT = 24

-- The panel pays back stat_panel's lopsided margin, which exists only to
-- cancel the indent AppKit gives a menu item's image. Nothing indents this
-- one.
local PANEL_INSET = statPanel.EVEN_MARGIN_INSET
local PANEL_WIDTH = statPanel.WIDTH + PANEL_INSET
local PANEL_RADIUS = 6

-- Clear of the menubar, and clear of the screen edge if the icon sits far
-- enough right that the panel would hang off it.
local MENUBAR_GAP = 2
local SCREEN_MARGIN = 8

-- The surface behind the rows, matched to a native menu as closely as a canvas
-- can be: the radius and the wash are the menu's, but not the material. AppKit
-- blurs what is behind a menu through an NSVisualEffectView, and hs.canvas has
-- no such element — so this is a near-opaque wash in the appearance of the
-- moment, which is the one visible difference from the sensors dropdown.
local DARK_SURFACE = { white = 0.14, alpha = 0.98 }
local LIGHT_SURFACE = { white = 0.97, alpha = 0.98 }
local BORDER_ALPHA = 0.16
local BORDER_WIDTH = 1

-- Strength of the gauge fill under a process row. Lower than a reading with a
-- threshold behind it: nothing here is a warning, it is a ranking.
local GAUGE_ALPHA = 0.6

-- A tenth of a core is a millisecond of CPU per second, so a rate in
-- milliseconds per second is already a percentage ten times over.
local MILLISECONDS_PER_PERCENT = 10
local NANOJOULES_PER_JOULE = 1e9
local NANOSECONDS_PER_SECOND = 1e9

-- Bounds on the gap two reports may be diffed across. Under the first, the
-- figure is rounding noise; over the second it is a mean across a stretch
-- nobody was watching, and the process's own lifetime mean is the more honest
-- answer.
local MINIMUM_ELAPSED_SECONDS = 0.2
local MAXIMUM_ELAPSED_SECONDS = 600

-- CPU is the one ranking with a scale that means something on its own: a
-- process at 100% has a core. The other two are scaled to the heaviest row
-- they contain, because neither joules nor bytes has a natural ceiling here.
local CPU_CEILING_PERCENT = 100

local SEPARATOR = "  ·  "

local ESCAPE_KEY_CODE = hs.keycodes.map.escape

local menu = hs.menubar.new()

-- Created once and reused: the panel is shown and hidden rather than built and
-- thrown away, so the window it lives in keeps its place in the level order.
local panelCanvas = hs.canvas.new({ x = 0, y = 0, w = PANEL_WIDTH, h = PANEL_WIDTH })

local refreshTimer = nil
local outsideTap = nil
local escapeTap = nil
local visible = false

-- The previous report and the moment it was taken, which is what every rate
-- below is measured against.
local previousStats = nil
local previousFetchedAt = nil

-- Set when the panel was dismissed by a click that landed on the icon, so the
-- menubar callback that follows does not read it as a request to open again.
local dismissedByIcon = false

-- Plain text of what the panel last drew, for reading it from `hs -c` without
-- opening it.
local lastText = ""

-- One helper run to completion, decoded. Synchronous because the panel is
-- repainted from a timer callback and there is nothing else for this
-- millisecond to do; the helper walks the whole process table in about 4ms.
local function fetchStats()
  local output = hs.execute(PROCESS_HELPER)

  if output == nil or output == "" then
    return nil
  end

  return hs.json.decode(output)
end

-- The previous report's processes by pid, so a process can be matched to its
-- own earlier sample.
local function processesByPid(processes)
  local byPid = {}

  for _, sample in ipairs(processes or {}) do
    byPid[sample.pid] = sample
  end

  return byPid
end

-- A cumulative counter turned into a per-second rate.
--
-- The age check is what makes a recycled pid safe: a process that exited and
-- had its number handed to another one reports an age lower than the sample it
-- would be diffed against, and falls back to the lifetime mean rather than
-- reporting the difference between two unrelated processes.
local function ratePerSecond(sample, previous, elapsed, field)
  local total = sample[field]

  if total == nil then
    return nil
  end

  local earlier = previous ~= nil and previous[field] or nil

  if earlier ~= nil and total >= earlier and elapsed ~= nil
    and elapsed >= MINIMUM_ELAPSED_SECONDS and elapsed <= MAXIMUM_ELAPSED_SECONDS
    and previous.age_seconds <= sample.age_seconds then
    return (total - earlier) / elapsed
  end

  if sample.age_seconds > 0 then
    return total / sample.age_seconds
  end

  return nil
end

-- A millisecond of CPU per second is a tenth of a core.
local function asPercent(millisecondsPerSecond)
  return millisecondsPerSecond / MILLISECONDS_PER_PERCENT
end

local function asWatts(nanojoulesPerSecond)
  return nanojoulesPerSecond / NANOJOULES_PER_JOULE
end

local function heaviestFirst(left, right)
  return left.value > right.value
end

-- The helper's candidates ranked by what they are doing now rather than by
-- what they have done in total, which is the only order a single sample could
-- have handed over.
local function rankedByRate(processes, previousByPid, elapsed, field, convert)
  local ranked = {}

  for _, sample in ipairs(processes) do
    local perSecond = ratePerSecond(sample, previousByPid[sample.pid], elapsed, field)

    if perSecond ~= nil then
      ranked[#ranked + 1] = { name = sample.name, value = convert(perSecond) }
    end
  end

  table.sort(ranked, heaviestFirst)

  return ranked
end

-- Resident memory needs none of that: it is measured rather than accumulated,
-- so the reading is already the answer.
local function rankedByResident(processes)
  local ranked = {}

  for _, sample in ipairs(processes) do
    if sample.rss_bytes ~= nil then
      ranked[#ranked + 1] = { name = sample.name, value = sample.rss_bytes }
    end
  end

  table.sort(ranked, heaviestFirst)

  return ranked
end

-- Load average rather than another CPU percentage: it counts threads waiting
-- for a turn, so a machine at 20% with a load of twelve is stuck on something
-- the utilisation figures cannot show.
local function systemSection(stats)
  return {
    header = "System",
    rows = {
      { label = "Uptime", value = statFormat.uptime(stats.uptime_seconds) },
      { label = "Load avg", value = statFormat.loadAverages(stats.load_avg, SEPARATOR) },
    },
  }
end

-- One ranking as a section. `ceiling` is what the gauges are a share of, and
-- nil when the ranking came back empty — which draws empty tracks rather than
-- dividing by nothing.
local function rankingSection(header, ranked, formatValue, ceiling, resting)
  local rows = {}
  local gaugeColor = statPanel.faded(resting, GAUGE_ALPHA)

  for index = 1, math.min(TOP_PROCESS_COUNT, #ranked) do
    local process = ranked[index]

    rows[index] = {
      label = statFormat.shortened(process.name, PROCESS_NAME_LIMIT),
      value = formatValue(process.value),
      fraction = statPanel.fraction(process.value, ceiling),
      gaugeColor = gaugeColor,
    }
  end

  return { header = header, rows = rows }
end

local function heaviestValue(ranked)
  local first = ranked[1]

  return first ~= nil and first.value or nil
end

local function panelSections(stats, elapsed, resting)
  local processes = stats.processes or {}
  local previousByPid = processesByPid(previousStats and previousStats.processes)
  local byCpu = rankedByRate(processes, previousByPid, elapsed, "cpu_ms", asPercent)
  local byEnergy = rankedByRate(processes, previousByPid, elapsed, "energy_nj", asWatts)
  local byMemory = rankedByResident(processes)

  return {
    systemSection(stats),
    rankingSection("Top by CPU", byCpu, statFormat.processPercent,
      CPU_CEILING_PERCENT, resting),
    rankingSection("Top by energy", byEnergy, statFormat.processWatts,
      heaviestValue(byEnergy), resting),
    rankingSection("Top by memory", byMemory, statFormat.bytes,
      heaviestValue(byMemory), resting),
  }
end

local function surfaceColor()
  if hs.host.interfaceStyle() == "Dark" then
    return DARK_SURFACE
  end

  return LIGHT_SURFACE
end

-- Where the panel hangs: under the icon and left-aligned to it, the way a menu
-- would, pulled back inside the screen when the icon sits far enough right
-- that the panel would overhang.
local function panelOrigin()
  local item = menu:frame()
  local screen = hs.screen.mainScreen():fullFrame()
  local rightLimit = screen.x + screen.w - PANEL_WIDTH - SCREEN_MARGIN

  return math.max(screen.x + SCREEN_MARGIN, math.min(item.x, rightLimit)),
    item.y + item.h + MENUBAR_GAP
end

-- The rounded wash and its hairline, under everything the rows draw.
local function surfaceElements(height, resting)
  return {
    {
      type = "rectangle",
      action = "fill",
      fillColor = surfaceColor(),
      roundedRectRadii = { xRadius = PANEL_RADIUS, yRadius = PANEL_RADIUS },
      frame = { x = 0, y = 0, w = PANEL_WIDTH, h = height },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = statPanel.faded(resting, BORDER_ALPHA),
      strokeWidth = BORDER_WIDTH,
      roundedRectRadii = { xRadius = PANEL_RADIUS, yRadius = PANEL_RADIUS },
      -- Inset by half a point so the stroke lands inside the canvas instead of
      -- straddling its edge and coming out half as bright.
      frame = {
        x = BORDER_WIDTH / 2,
        y = BORDER_WIDTH / 2,
        w = PANEL_WIDTH - BORDER_WIDTH,
        h = height - BORDER_WIDTH,
      },
    },
  }
end

-- Take a reading, rank it against the previous one, and repaint. Called once
-- on open and then on the timer, which only runs while the panel is up.
local function repaint()
  local stats = fetchStats() or {}
  local takenAt = hs.timer.absoluteTime()
  local elapsed = previousFetchedAt ~= nil
    and (takenAt - previousFetchedAt) / NANOSECONDS_PER_SECOND or nil
  local resting = statPanel.textColor()
  local sections = panelSections(stats, elapsed, resting)

  previousStats = stats
  previousFetchedAt = takenAt
  lastText = statPanel.stackText(sections)

  local rows, height = statPanel.stack(sections, resting, PANEL_INSET)
  local elements = surfaceElements(height, resting)

  for _, row in ipairs(rows) do
    elements[#elements + 1] = row
  end

  local x, y = panelOrigin()

  panelCanvas:frame({ x = x, y = y, w = PANEL_WIDTH, h = height })
  panelCanvas:replaceElements(table.unpack(elements))
end

local function hidePanel()
  if not visible then
    return
  end

  visible = false
  refreshTimer:stop()
  outsideTap:stop()
  escapeTap:stop()
  panelCanvas:hide()
end

local function containsPoint(frame, point)
  return point.x >= frame.x and point.x <= frame.x + frame.w
    and point.y >= frame.y and point.y <= frame.y + frame.h
end

-- Dismiss on any click that is not on the panel. The click is passed through
-- rather than swallowed, so dismissing the panel and clicking what is behind
-- it are one gesture.
local function handleClickOutside(event)
  local point = event:location()

  if containsPoint(panelCanvas:frame(), point) then
    return false
  end

  -- A click on the icon reaches this tap before the menubar callback. Without
  -- the flag the callback would read the panel as already shut and open it
  -- straight back, so the icon would never close it.
  if containsPoint(menu:frame(), point) then
    dismissedByIcon = true
  end

  hidePanel()

  return false
end

-- Escape is swallowed, because dismissing a panel is the whole of what the
-- keystroke meant.
local function handleEscape(event)
  if event:getKeyCode() ~= ESCAPE_KEY_CODE then
    return false
  end

  hidePanel()

  return true
end

local function showPanel()
  visible = true

  repaint()
  panelCanvas:show()
  refreshTimer:start()
  outsideTap:start()
  escapeTap:start()
end

local function togglePanel()
  if dismissedByIcon then
    dismissedByIcon = false

    return
  end

  if visible then
    hidePanel()

    return
  end

  showPanel()
end

refreshTimer = hs.timer.new(REFRESH_SECONDS, repaint)
outsideTap = hs.eventtap.new({
  hs.eventtap.event.types.leftMouseDown,
  hs.eventtap.event.types.rightMouseDown,
  hs.eventtap.event.types.otherMouseDown,
}, handleClickOutside)
escapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleEscape)

-- Above ordinary windows and clear of the menubar, and present on whichever
-- Space is in front — the panel belongs to the bar, not to a desktop.
panelCanvas:level(hs.canvas.windowLevels.popUpMenu)
panelCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
  + hs.canvas.windowBehaviors.stationary)

local icon = hs.image.imageFromPath(ICON_PATH)

if icon ~= nil then
  -- template = true, the opposite of what the sensors row wants: that one
  -- carries its own colours, this one is a silhouette AppKit should tint.
  menu:setIcon(icon, true)
else
  -- A missing asset costs the gear, not the widget.
  menu:setTitle(ICON_FALLBACK_TITLE)
end

-- A click callback rather than a menu: the panel is drawn, and hs.menubar
-- honours one or the other.
menu:setClickCallback(togglePanel)

local widget = {
  show = showPanel,
  hide = hidePanel,
  toggle = togglePanel,
  -- Plain text of what the panel last drew. Takes a fresh reading when the
  -- panel has never been opened, so it answers on a cold config too.
  text = function()
    if lastText == "" then
      repaint()
    end

    return lastText
  end,
}

_G[INSTANCE_KEY] = widget

return widget
