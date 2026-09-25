-- Menubar readout of CPU load and die temperature alongside the RAM and
-- swap in use and the machine's power draw. Five unlabelled columns of
-- stacked figures, the way the Stats app lays its widgets out; the unit on
-- each figure is what names it. A reading turns orange, then red, as it
-- crosses the warning and critical thresholds.
--
-- The GPU has no column — the bar has no width for one — and the streamed
-- report no longer carries it either: everything the row cannot show is
-- fetched separately when the dropdown opens.
--
-- Throughput has no column either, and for a different reason: it is a
-- menubar item of its own. It swings several digits a second where these
-- figures move by one, so it wants a column wide enough to swing in without
-- dragging these figures sideways; see modules/network_stats.lua.
--
-- The item itself is drawn by c-system-sensors-macos, a small Swift helper
-- that reads the SMC directly and samples load, memory and power alongside
-- (see native_modules/macos/c-system-sensors-macos.swift, SystemRow). It
-- repaints the item on its own timer and pauses while the screens are locked
-- or asleep; this file gets the readings over lib/stats_stream and draws only
-- the panel. Hammerspoon has no temperature API of its own —
-- hs.host.thermalState() returns a coarse pressure word, not degrees — and
-- macmon, the obvious CLI, only exposes averages, so a "hottest" figure
-- cannot be recovered from it.
--
-- Build the helper once with `dotfiles_setup/build_native_modules.sh`; until
-- then the item is missing from the bar.
--
-- Clicking the item opens a panel with everything the row has no width for,
-- drawn into canvases: sections of gauges rather than lines of text, because
-- a share of a limit is a bar and reads as one. The drawing itself lives in
-- stat_panel, which the process widget shares. It is a native menu popped up
-- under the item, from a Hammerspoon menubar object that is never in the bar.
--
-- The panel's sensor readings travel with the click: the helper reads its
-- details report — every die sensor named, the GPU, total memory — when the
-- item is clicked, so that cost lands on a menu that has not been drawn yet
-- rather than on every tick of a row nobody is looking at.
--
-- There is no hide item in the panel: `hs -c 'require("system_stats").hide()'`
-- still works, and `show()` or a config reload brings the widget back.

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "system_stats" and "modules.system_stats" — two
-- package.loaded entries, and without this guard the second require runs
-- the body again and builds a second panel.
local INSTANCE_KEY = "systemStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")
local memoryUsage = require("memory_usage")
local statFormat = require("stat_format")
local statPanel = require("stat_panel")
local statsStream = require("stats_stream")

local formatCelsius = statFormat.celsius
local formatPercent = statFormat.percent
local formatGigabytes = statFormat.gigabytes
local formatBytes = statFormat.bytes
local formatWatts = statFormat.watts

-- The sensor helper's details report, taken directly only when the panel's
-- text is asked for from `hs -c` without a click to carry it.
local DETAILS_COMMAND = statsStream.HELPER .. " details"

-- Above this the reading is drawn in orange. The row's own thresholds live in
-- the helper (SystemRow) and have to match these.
local WARN_CELSIUS = 75

-- Above this it turns red: sustained throttling territory, not a spike.
local CRITICAL_CELSIUS = 92

-- Power is the one reading shown twice: what the machine draws right now
-- over the mean of the last minute, which is what a burst actually cost. The
-- window is the helper's (StatsMenubar.powerWindowSeconds); this names it.
local POWER_AVERAGE_SECONDS = 60

-- nf-md-eye_off — the banner glyph confirming the widget was hidden.
local HIDDEN_ICON = "󰛑"

-- A click on the item while its menu is open closes the menu and then
-- arrives here as a fresh click. One this soon after the menu closed is that
-- click, not a request to open it again.
local REOPEN_GUARD_SECONDS = 0.3

local BYTES_PER_MEGABYTE = 1024 * 1024
local BYTES_PER_GIGABYTE = 1024 * BYTES_PER_MEGABYTE

-- Swap gets the same two-step treatment as temperature: 200MB means the
-- compressor stopped absorbing the pressure, three gigabytes means the
-- machine is paging for real and everything starts feeling slow.
local WARN_SWAP_BYTES = 200 * BYTES_PER_MEGABYTE
local CRITICAL_SWAP_BYTES = 3 * BYTES_PER_GIGABYTE

-- A gauge with nothing to be a share of still needs a full scale. Power gets
-- a fixed ceiling — an Apple Silicon laptop pulling this much is at its
-- sustained limit — rather than the window's own peak, which would move
-- under the bar and make a steady draw look like it was climbing.
local POWER_CEILING_WATTS = 40

-- Separates the two figures of a detail line. Wider than a space on each
-- side because the two are different readings, not one phrase.
local DETAIL_SEPARATOR = "  ·  "


-- Never in the bar: the helper draws the item, and this only carries the
-- menu that pops up under it when it is clicked.
local menu = hs.menubar.new(false)

-- The latest tick's readings, which the detail menu reads when it opens.
local lastReading = {}

-- When the popped-up menu last closed, for REOPEN_GUARD_SECONDS.
local menuClosedAt = 0

-- Clicking a panel section should do nothing, but a menu item still needs an
-- action: AppKit disables any item without one, and it draws a disabled item
-- dimmed — which would fade the whole section image, gauges included.
local function ignoreClick() end

-- One `details` call, decoded. Only for the panel text asked for from
-- `hs -c`: a click carries its own report. Synchronous, because the text is
-- wanted there and then; the helper takes about 9ms including the spawn.
local function fetchDetails()
  local output = hs.execute(DETAILS_COMMAND)

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
-- figures are the last tick's: the helper diffs the per-core tick counters
-- between ticks, and a panel opened now has no earlier sample of its own.
local function cpuSection(details, resting)
  local reading = lastReading
  local busiest = reading.cpu_busiest

  return {
    header = "CPU",
    rows = {
      {
        label = "Load",
        value = formatPercent(busiest) .. " busiest" .. DETAIL_SEPARATOR
          .. formatPercent(reading.cpu_mean) .. " mean",
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

-- The rolling window is the helper's: it records a reading every tick, which
-- is the only place a minute of history exists.
local function powerSection(details, resting)
  local lowestWatts = lastReading.watts_low
  local highestWatts = lastReading.watts_high

  return {
    header = "Power",
    rows = {
      {
        label = "Draw",
        value = formatWatts(details.watts) .. " now" .. DETAIL_SEPARATOR
          .. formatWatts(lastReading.watts_avg) .. " mean",
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
local function detailSections(resting, details)
  details = details or {}

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

-- The detail sections as menu items, one image per section with separators
-- between them.
local function detailMenu(details)
  local resting = statPanel.textColor()
  local items = {}

  for index, section in ipairs(detailSections(resting, details)) do
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

-- Keep the tick's readings for the menu and the `title` accessor.
local function applyReadings(event)
  lastReading = event
end

-- Build the menu from the click's details and pop it up under the item.
-- popupMenu blocks until the menu closes, the way a native menu tracks, so
-- the close time is taken when it returns.
local function handleClick(event)
  if hs.timer.secondsSinceEpoch() - menuClosedAt < REOPEN_GUARD_SECONDS then
    return
  end

  local frame = event.frame

  menu:setMenu(detailMenu(event.details))
  menu:popupMenu({ x = frame.x, y = frame.y + frame.h })
  menuClosedAt = hs.timer.secondsSinceEpoch()
end

local subscriber = { readings = applyReadings, click = handleClick }

-- Take the item out of the bar: the helper restarts without it, or stops
-- when no other widget is left. Hidden, the widget costs nothing.
local function hide()
  statsStream.unsubscribe("system")

  canvasBanner.show({
    title = "Sensors hidden",
    subtitle = "hs -c 'require(\"system_stats\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back. The load figures land one tick after that — two samples are
-- needed for a delta — and until then the row shows placeholders.
local function show()
  statsStream.subscribe("system", subscriber)
end

statsStream.subscribe("system", subscriber)

local widget = {
  refresh = statsStream.restart,
  show = show,
  hide = hide,
  -- Plain text of the current readout and of the menu behind it, for
  -- checking both from `hs -c` without squinting at the menubar.
  title = function() return lastReading.system_text or "" end,
  details = function()
    return statPanel.stackText(detailSections(statPanel.textColor(), fetchDetails()))
  end,
}

_G[INSTANCE_KEY] = widget

return widget
