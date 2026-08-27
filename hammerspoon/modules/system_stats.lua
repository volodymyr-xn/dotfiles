-- Menubar readout of CPU load and die temperature alongside the RAM and
-- swap in use and the machine's power draw, refreshed on a timer. Five
-- unlabelled columns of stacked figures, the way the Stats app lays its
-- widgets out; the unit on each figure is what names it. A reading turns
-- orange, then red, as it crosses the warning and critical thresholds.
--
-- The GPU has no column — the bar has no width for one — and the streamed
-- report no longer carries it either: everything the row cannot show is
-- fetched separately when the dropdown opens.
--
-- Throughput has no column either, and for a different reason: it is a
-- menubar item of its own. It swings several digits a second where these
-- figures move by one, so it wanted a cadence this row has no use for; see
-- modules/network_stats.lua.
--
-- The row itself is drawn by menubar_row, which the network item shares — an
-- hs.canvas handed over as the item's *icon*, because a menubar title is a
-- single line of text however it is styled.
--
-- The temperatures come from c-system-sensors-macos, a small Swift helper that
-- reads the SMC directly (see
-- native_modules/macos/c-system-sensors-macos.swift).
-- Hammerspoon has no temperature API of its own — hs.host.thermalState()
-- returns a coarse pressure word, not degrees — and macmon, the obvious CLI,
-- only exposes averages, so a "hottest" figure cannot be recovered from it.
--
-- Build the helper once with `setup/build_native_modules.sh`; until then
-- this shows placeholders rather than disappearing, so a missing binary is
-- visible.
--
-- Clicking the item opens a panel with everything the row has no width for,
-- drawn into canvases the same way the row is: sections of gauges rather than
-- lines of text, because a share of a limit is a bar and reads as one. The
-- drawing itself lives in stat_panel, which the process widget shares.
--
-- What this file owns is which columns the row carries, what the panel says
-- and the cadence they refresh on. Taking the readings does not live here:
-- cpu_ticks, memory_usage and power_window each own one source and the
-- baseline it needs to be a rate, and line_stream owns the helper process
-- they read from.
--
-- The panel's readings come from a second, separate call to the same helper —
-- `c-system-sensors-macos details` — taken once per open. It names every die
-- sensor rather than reducing the set to two figures, and adds the GPU and
-- total memory. The streamed report carries four figures and nothing else, so
-- that cost lands on a menu that has not been drawn yet rather than on every
-- tick of a row nobody is looking at.
--
-- There is no hide item in the panel: `hs -c 'require("system_stats").hide()'`
-- still works, and `show()` or a config reload brings the widget back.

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "system_stats" and "modules.system_stats" — two
-- package.loaded entries, and without this guard the second require runs
-- the body again and paints a second item in the bar.
local INSTANCE_KEY = "systemStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")
local cpuTicks = require("cpu_ticks")
local lineStream = require("line_stream")
local memoryUsage = require("memory_usage")
local menubarRow = require("menubar_row")
local powerWindow = require("power_window")
local statFormat = require("stat_format")
local statPanel = require("stat_panel")

-- Aliased rather than called through the table: these run several times per
-- cell on every repaint, and the row is the one place in this config where
-- that is worth a local.
local formatCelsius = statFormat.celsius
local formatPercent = statFormat.percent
local formatGigabytes = statFormat.gigabytes
local formatBytes = statFormat.bytes
local formatWatts = statFormat.watts

-- Absolute paths because hs.task does not consult the login shell's PATH,
-- which is where ~/dotfiles/bin_native/macos is added.
local NATIVE_DIRECTORY = os.getenv("HOME") .. "/dotfiles/bin_native/macos/"
local SENSOR_HELPER = NATIVE_DIRECTORY .. "c-system-sensors-macos"

-- The sensor helper's other report, which the dropdown asks for by itself
-- rather than reading off the stream.
local DETAILS_SUBCOMMAND = " details"

-- The helper streams a line per interval through lib/line_stream, which
-- carries why that beats spawning one per refresh.
--
-- Two seconds because none of these figures moves faster than that in a way a
-- reader could use: a die warms over tens of seconds, and resident memory over
-- minutes. The row repaints per line rather than on a timer of its own — with
-- one stream feeding it, the line *is* the cadence.
local SENSOR_INTERVAL_MILLISECONDS = 2000

-- How often a dead stream is noticed and restarted. Loose because a helper
-- that dies at all is the unexpected case — this is a backstop, not a poll.
local SUPERVISOR_SECONDS = 10

-- Above this the reading is drawn in orange.
local WARN_CELSIUS = 75

-- Above this it turns red: sustained throttling territory, not a spike.
local CRITICAL_CELSIUS = 92

-- Power is the one reading shown twice: what the machine draws right now
-- over the mean of the last minute, which is what a burst actually cost.
local POWER_AVERAGE_SECONDS = 60
local POWER_SAMPLE_LIMIT = POWER_AVERAGE_SECONDS * 1000 / SENSOR_INTERVAL_MILLISECONDS

-- nf-md-eye_off — the banner glyph confirming the widget was hidden.
local HIDDEN_ICON = "󰛑"

-- The faces the row is set in, which menubar_row owns so the two items in the
-- bar are set in the same ones. The bold is for the idle-swap word: it is the
-- one cell carrying prose instead of a figure, and it needs the weight to
-- read as a reading next to the numbers.
local SOLO_COLUMN_FONT = menubarRow.SOLO_FONT
local SOLO_COLUMN_BOLD_FONT = menubarRow.SOLO_BOLD_FONT

local BYTES_PER_MEGABYTE = 1024 * 1024
local BYTES_PER_GIGABYTE = 1024 * BYTES_PER_MEGABYTE

-- Swap gets the same two-step treatment as temperature: 200MB means the
-- compressor stopped absorbing the pressure, three gigabytes means the
-- machine is paging for real and everything starts feeling slow.
local WARN_SWAP_BYTES = 200 * BYTES_PER_MEGABYTE
local CRITICAL_SWAP_BYTES = 3 * BYTES_PER_GIGABYTE
local NO_SWAP_TEXT = "No swap"

-- A gauge with nothing to be a share of still needs a full scale. Power gets
-- a fixed ceiling — an Apple Silicon laptop pulling this much is at its
-- sustained limit — rather than the window's own peak, which would move
-- under the bar and make a steady draw look like it was climbing.
local POWER_CEILING_WATTS = 40

-- Separates the two figures of a detail line. Wider than a space on each
-- side because the two are different readings, not one phrase.
local DETAIL_SEPARATOR = "  ·  "


local menu = hs.menubar.new()
local barRow = menubarRow.new()
local sensorTask = nil
local supervisorTimer = nil

local lastPaintMilliseconds = 0

-- Plain-text mirror of what was last painted, for the `title` accessor, and
-- the snapshot behind it, which the detail menu reads when it opens.
local lastText = ""
local lastReading = {}

-- Load and memory readings come from lib collectors; the two that need a
-- baseline (CPU load, the power window) get an instance of their own here, so
-- nothing else in this Lua state can consume the span between two of this
-- widget's refreshes.
local cpuSampler = cpuTicks.new()
local wattsWindow = powerWindow.new(POWER_SAMPLE_LIMIT)

-- One temperature figure, tinted by how close it is to throttling.
local function celsiusCell(celsius, resting)
  return {
    text = formatCelsius(celsius),
    color = statPanel.thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS, resting),
  }
end

-- Idle swap reads "No swap" rather than "0B": zero paging is a state, and the
-- word says so where a zeroed size looks like a stalled reading.
local function swapCell(bytes, resting)
  local color = statPanel.thresholdColor(bytes, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting)

  if bytes == 0 then
    return { text = NO_SWAP_TEXT, color = color, font = SOLO_COLUMN_BOLD_FONT }
  end

  return { text = formatBytes(bytes), color = color, font = SOLO_COLUMN_FONT }
end

-- The five columns, left to right, unlabelled: memory in use, swap in use,
-- busiest core over mean load, hottest die over the mean of the sensor set,
-- and current draw over the rolling mean. Memory leads because it is the
-- figure worth a glance; it and swap carry one value each and span both rows,
-- the way a column with nothing to qualify it does. The GPU is not shown at
-- all, and neither is throughput — it has an item of its own.
--
-- Only readings with a threshold take the warning colour: the load is not
-- what got hot, and the resident memory is not what is paging.
local function columns(reading, resting)
  local swapUsed = reading.swapUsed

  return {
    {
      top = {
        text = formatGigabytes(reading.ramUsed),
        color = resting,
        font = SOLO_COLUMN_FONT,
      },
    },
    {
      top = swapCell(swapUsed, resting),
    },
    {
      top = { text = formatPercent(reading.cpuBusiestUsage), color = resting },
      bottom = { text = formatPercent(reading.cpuUsage), color = resting },
    },
    {
      top = celsiusCell(reading.cpuCelsius, resting),
      bottom = celsiusCell(reading.cpuAverageCelsius, resting),
    },
    {
      top = { text = formatWatts(reading.watts), color = resting },
      bottom = { text = formatWatts(wattsWindow.average()), color = resting },
    },
  }
end

-- Paint the columns of the moment. The layout is menubar_row's; what stays
-- here is the snapshot, which the panel reads when it opens.
local function render(reading)
  lastReading = reading
  lastText = barRow.paint(menu, columns(reading, menubarRow.textColor()))
end

-- The reading the row and the panel are both drawn from. One table reused
-- rather than replaced, so a line that reports some of the figures leaves the
-- rest of the row standing rather than blanking it.
local reading = {}

-- What the helper does not own is read on its tick: hs.host counters, which
-- are counter reads rather than sampled measurements and so cost microseconds.
--
-- The row is painted from here rather than from a timer of its own. It cost
-- about 5ms, nearly all of it measuring strings, back when two streams landed
-- three paints a second between them and a coalescing timer was worth having;
-- one stream at two seconds is already the cadence a paint belongs on.
local function applySensorLine(line)
  local sensors = hs.json.decode(line)

  if sensors == nil then
    return
  end

  local busiestUsage, overallUsage = cpuSampler.usagePercents()
  local memory = memoryUsage.current()

  reading.cpuBusiestUsage = busiestUsage
  reading.cpuUsage = overallUsage
  reading.memory = memory
  reading.ramUsed = memory ~= nil and memory.used or nil
  reading.cpuCelsius = sensors.cpu
  reading.cpuAverageCelsius = sensors.cpu_avg
  reading.watts = sensors.watts
  reading.swapUsed = sensors.swap_bytes

  wattsWindow.record(reading.watts)

  local started = hs.timer.absoluteTime()
  render(reading)
  lastPaintMilliseconds = (hs.timer.absoluteTime() - started) / 1e6
end

-- Start the helper in watch mode, at the cadence it should report on. "watch"
-- is this helper's own subcommand, not something lib knows.
local function startStream()
  if lineStream.isRunning(sensorTask) then
    return
  end

  sensorTask = lineStream.start(SENSOR_HELPER,
    { "watch", tostring(SENSOR_INTERVAL_MILLISECONDS) }, applySensorLine)
end

local function stopStream()
  lineStream.stop(sensorTask)

  sensorTask = nil
end

-- A helper that dies takes its readings with it and nothing else notices, so
-- this is the backstop that starts it again.
supervisorTimer = hs.timer.new(SUPERVISOR_SECONDS, startStream)

-- Take the item out of the bar and kill the helper with it: hidden, the widget
-- costs nothing, not even the process.
local function hide()
  supervisorTimer:stop()
  stopStream()
  menu:removeFromMenuBar()

  canvasBanner.show({
    title = "Sensors hidden",
    subtitle = "hs -c 'require(\"system_stats\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back and start the stream again. The first line lands within an
-- interval, and until then the row shows the placeholders it was built with
-- rather than the readings it was hidden on.
local function show()
  menu:returnToMenuBar()
  startStream()
  supervisorTimer:start()
end

-- Clicking a panel section should do nothing, but a menu item still needs an
-- action: AppKit disables any item without one, and it draws a disabled item
-- dimmed — which would fade the whole section image, gauges included.
local function ignoreClick() end

-- One `details` call, decoded. Synchronous, because hs.menubar wants its menu
-- returned there and then and an hs.task cannot answer in time; the helper
-- takes about 6ms including the spawn, and it is paid against a panel that has
-- not been drawn yet rather than on a timer.
local function fetchDetails()
  local output = hs.execute(SENSOR_HELPER .. DETAILS_SUBCOMMAND)

  if output == nil or output == "" then
    return nil
  end

  return hs.json.decode(output)
end

-- One die reading as a row of the temperature summary: hottest over mean,
-- against the threshold that decides its colour.
local function temperatureRow(label, hottest, average, resting)
  return {
    label = label,
    value = formatCelsius(hottest) .. " hottest" .. DETAIL_SEPARATOR
      .. formatCelsius(average) .. " mean",
    color = statPanel.thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS, resting),
    fraction = statPanel.fraction(hottest, CRITICAL_CELSIUS),
    gaugeColor = statPanel.thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS,
      statPanel.faded(resting, 0.75)),
  }
end

-- Both dies in one place, which the row itself can only answer for the CPU:
-- it has no width for a GPU column. The sensor sets these
-- summarise stay with the unit they belong to, further down.
local function temperatureSection(details, resting)
  return {
    header = "Temperature",
    rows = {
      temperatureRow("CPU", details.cpu, details.cpu_avg, resting),
      temperatureRow("GPU", details.gpu, details.gpu_avg, resting),
    },
  }
end

-- One slot per die sensor, each filled by how hot that sensor is against the
-- critical threshold and tinted the same way the summary above it is.
local function sensorBars(readings, resting)
  local bars = {}
  local resting70 = statPanel.faded(resting, 0.7)

  for index, sensor in ipairs(readings or {}) do
    local celsius = sensor.c

    bars[index] = {
      fraction = statPanel.fraction(celsius, CRITICAL_CELSIUS),
      color = statPanel.thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS, resting70),
    }
  end

  return bars
end

-- Load, then the whole sensor set the summary above was reduced from. The load
-- figures stay Hammerspoon's own: the helper has no CPU utilisation to report,
-- because hs.host.cpuUsageTicks() already does.
local function cpuSection(details, resting)
  local reading = lastReading
  local busiest = reading.cpuBusiestUsage

  return {
    header = "CPU",
    rows = {
      {
        label = "Load",
        value = formatPercent(busiest) .. " busiest" .. DETAIL_SEPARATOR
          .. formatPercent(reading.cpuUsage) .. " mean",
        fraction = statPanel.fraction(busiest, 100),
        gaugeColor = statPanel.faded(resting, 0.75),
      },
      { label = "Cores", bars = sensorBars(details.cpu_sensors, resting) },
    },
  }
end

-- The column the bar has no width for at all.
local function gpuSection(details, resting)
  local usage = details.gpu_usage

  return {
    header = "GPU",
    rows = {
      {
        label = "Load",
        value = formatPercent(usage),
        fraction = statPanel.fraction(usage, 100),
        gaugeColor = statPanel.faded(resting, 0.75),
      },
      { label = "Dies", bars = sensorBars(details.gpu_sensors, resting) },
    },
  }
end

-- Memory read again here rather than taken from the last tick: it is a counter
-- read, and the panel is a snapshot of the moment it opened.
local function memorySection(details, resting)
  local memory = memoryUsage.current() or {}
  local total = details.ram_total_bytes
  local swapUsed = details.swap_bytes

  return {
    header = "Memory",
    rows = {
      {
        label = "RAM",
        value = formatGigabytes(memory.used) .. " of " .. formatGigabytes(total),
        parts = {
          { fraction = statPanel.fraction(memory.app, total),
            color = statPanel.faded(resting, 0.85) },
          { fraction = statPanel.fraction(memory.wired, total),
            color = statPanel.faded(resting, 0.55) },
          { fraction = statPanel.fraction(memory.compressed, total),
            color = statPanel.faded(resting, 0.3) },
        },
        detail = "app " .. formatBytes(memory.app) .. DETAIL_SEPARATOR
          .. "wired " .. formatBytes(memory.wired) .. DETAIL_SEPARATOR
          .. "compressed " .. formatBytes(memory.compressed),
      },
      {
        label = "Swap",
        value = formatBytes(swapUsed) .. " in use",
        color = statPanel.thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting),
        fraction = statPanel.fraction(swapUsed, CRITICAL_SWAP_BYTES),
        gaugeColor = statPanel.thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES,
          statPanel.faded(resting, 0.75)),
      },
    },
  }
end

-- The rolling window stays Hammerspoon's: it is built from the streamed
-- readings, one every couple of seconds, which is the only place a minute of
-- history exists.
local function powerSection(details, resting)
  local lowestWatts, highestWatts = wattsWindow.range()

  return {
    header = "Power",
    rows = {
      {
        label = "Draw",
        value = formatWatts(details.watts) .. " now" .. DETAIL_SEPARATOR
          .. formatWatts(wattsWindow.average()) .. " mean",
        fraction = statPanel.fraction(details.watts, POWER_CEILING_WATTS),
        gaugeColor = statPanel.faded(resting, 0.75),
        detail = string.format("%s low%s%s peak over the last %ds",
          formatWatts(lowestWatts), DETAIL_SEPARATOR, formatWatts(highestWatts),
          POWER_AVERAGE_SECONDS),
      },
    },
  }
end

-- Everything the bar has no width for, rebuilt each time the panel opens so it
-- carries the reading of the moment it was opened rather than the one the menu
-- was built on.
--
-- Processes, uptime and load average are not here, and neither is throughput:
-- each has a menubar item of its own, and the helper behind it never runs for
-- this one.
local function detailSections(resting)
  local details = fetchDetails() or {}

  -- Memory leads, the way it leads the row: it is the figure worth a glance.
  -- The temperature summary follows, and the per-unit sections after it.
  return {
    memorySection(details, resting),
    temperatureSection(details, resting),
    cpuSection(details, resting),
    gpuSection(details, resting),
    powerSection(details, resting),
  }
end

local function detailMenu()
  local resting = statPanel.textColor()
  local items = {}

  for index, section in ipairs(detailSections(resting)) do
    if index > 1 then
      items[#items + 1] = { title = "-" }
    end

    -- template = false keeps the colours, the same way the row's own icon
    -- does: the default treats the image as a mask and repaints it in the
    -- menu's own tint.
    local image = statPanel.sectionImage(section, resting):template(false)

    items[#items + 1] = { title = "", image = image, fn = ignoreClick }
  end

  return items
end

-- A menu rather than a click callback: hs.menubar honours one or the other,
-- and there is nothing to do with a click but open this.
menu:setMenu(detailMenu)

-- Restart the helper, which is the only "refresh" a streaming widget has: the
-- readings arrive on their own, and the useful manual action is bringing the
-- stream back after killing its process by hand.
local function restart()
  stopStream()
  startStream()
end

-- Claim the menubar slot before the first line arrives, so the item is never
-- a zero-width gap on startup.
render(reading)
startStream()
supervisorTimer:start()

local widget = {
  refresh = restart,
  show = show,
  hide = hide,
  -- Plain text of the current readout and of the menu behind it, for
  -- checking both from `hs -c` without squinting at the menubar.
  title = function() return lastText end,
  paintCost = function() return lastPaintMilliseconds end,
  details = function()
    return statPanel.stackText(detailSections(statPanel.textColor()))
  end,
}

_G[INSTANCE_KEY] = widget

return widget
