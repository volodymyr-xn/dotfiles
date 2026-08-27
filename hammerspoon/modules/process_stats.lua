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
-- once-a-second refresh; canvas_panel owns that surface, where it hangs and
-- how it is dismissed, and the network widget draws its own the same way. The
-- rows inside it are stat_panel's, which the sensors widget shares too. What
-- is this file's is the readings and their units.
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

local canvasPanel = require("canvas_panel")
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

local menu = hs.menubar.new()

-- The previous report and the moment it was taken, which is what every rate
-- below is measured against.
local previousStats = nil
local previousFetchedAt = nil

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

-- Take a reading, rank it against the previous one, and hand the panel its
-- sections. Called on open and then on the panel's own cadence, which only
-- runs while it is up — so the helper is not spawned for an item nobody
-- clicked.
local function panelSections(resting)
  local stats = fetchStats() or {}
  local takenAt = hs.timer.absoluteTime()
  local elapsed = previousFetchedAt ~= nil
    and (takenAt - previousFetchedAt) / NANOSECONDS_PER_SECOND or nil
  local processes = stats.processes or {}
  local previousByPid = processesByPid(previousStats and previousStats.processes)
  local byCpu = rankedByRate(processes, previousByPid, elapsed, "cpu_ms", asPercent)
  local byEnergy = rankedByRate(processes, previousByPid, elapsed, "energy_nj", asWatts)
  local byMemory = rankedByResident(processes)

  previousStats = stats
  previousFetchedAt = takenAt

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

local panel = canvasPanel.new(menu, REFRESH_SECONDS, panelSections)

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
menu:setClickCallback(panel.toggle)

local widget = {
  show = panel.show,
  hide = panel.hide,
  toggle = panel.toggle,
  text = panel.text,
}

_G[INSTANCE_KEY] = widget

return widget
