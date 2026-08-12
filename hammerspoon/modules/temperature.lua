-- Menubar readout of CPU load and die temperature alongside the RAM and
-- swap in use and the machine's power draw, refreshed on a timer. Four
-- unlabelled columns of stacked figures, the way the Stats app lays its
-- widgets out; the unit on each figure is what names it. A reading turns
-- orange, then red, as it crosses the warning and critical thresholds.
--
-- The GPU is read but not shown: the helper still reports its temperature
-- and utilisation, so putting a column back is a display change only.
--
-- Drawn into an hs.canvas and handed over as the item's *icon*: a menubar
-- title is a single line of text however it is styled, so two rows in the
-- height of the bar cannot be done any other way.
--
-- The temperatures come from c-sensor-temps-macos, a small Swift helper that
-- reads the SMC directly (see
-- native_modules/macos/c-sensor-temps-macos.swift).
-- Hammerspoon has no temperature API of its own — hs.host.thermalState()
-- returns a coarse pressure word, not degrees — and macmon, the obvious CLI,
-- only exposes averages, so a "hottest" figure cannot be recovered from it.
--
-- Build the helper once with `setup/build_native_modules.sh`; until then
-- this shows placeholders rather than disappearing, so a missing binary is
-- visible.
--
-- Clicking the item hides it and stops the timer; `hs -c
-- 'require("temperature").show()'` or a config reload brings it back.

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "temperature" and "modules.temperature" — two
-- package.loaded entries, and without this guard the second require runs
-- the body again and paints a second item in the bar.
local INSTANCE_KEY = "temperatureWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")

-- An absolute path because hs.task does not consult the login shell's PATH,
-- which is where ~/dotfiles/bin_native/macos is added.
local HELPER = os.getenv("HOME") .. "/dotfiles/bin_native/macos/c-sensor-temps-macos"

-- A refresh costs about 2ms on the main thread plus a 5ms helper process
-- that runs off it, so the interval is a display choice rather than a cost
-- one. Temperature alone would sit happily at 15s, but load is spiky and a
-- stale percentage reads as a broken widget.
local REFRESH_SECONDS = 3

-- Above this the reading is drawn in orange.
local WARN_CELSIUS = 75

-- Above this it turns red: sustained throttling territory, not a spike.
local CRITICAL_CELSIUS = 92

-- Height of the macOS menubar, and the two rows the columns are drawn on:
-- each figure is centred in its own half of that height.
local BAR_HEIGHT = 22
local ROW_COUNT = 2

-- Points between one column and the next. Laid out in points rather than
-- padded with spaces, because the system font's digits are proportional.
-- Wide enough that the columns read as separate without a label between
-- them: the unit on each figure is what names it.
local COLUMN_GAP = 10

-- Separates the two figures of a column in the plain-text mirror only; on
-- the bar they are stacked instead.
local VALUE_SEPARATOR = " "
local COLUMN_SEPARATOR = "  "

-- Power is the one reading shown twice: what the machine draws right now
-- over the mean of the last minute, which is what a burst actually cost.
local POWER_AVERAGE_SECONDS = 60
local POWER_SAMPLE_LIMIT = POWER_AVERAGE_SECONDS / REFRESH_SECONDS
local WATTS_SUFFIX = "W"

-- Shown per figure when the helper is missing or a key stopped resolving.
local PLACEHOLDER = "--"

-- nf-md-eye_off — the banner glyph confirming the widget was hidden.
local HIDDEN_ICON = "󰛑"

local WARN_COLOR = { red = 1, green = 0.58, blue = 0, alpha = 1 }
local CRITICAL_COLOR = { red = 1, green = 0.23, blue = 0.19, alpha = 1 }
local LIGHT_COLOR = { white = 0, alpha = 1 }
local DARK_COLOR = { white = 1, alpha = 1 }

-- The macOS UI font, which is what the Stats app draws its widgets with
-- (NSFont.systemFont); the hidden PostScript name is how AppKit exposes it.
-- Two rows in the height of the menubar leave room for about 9pt, which is
-- the size Stats sets its own stacked widgets in.
local MENUBAR_FONT = { name = ".AppleSystemUIFont", size = 10 }

local BYTES_PER_GIGABYTE = 1024 * 1024 * 1024

-- Swap gets the same two-step treatment as temperature: a gigabyte is
-- pressure the compressor could not absorb, three is the machine paging for
-- real and the point where everything starts feeling slow.
local WARN_SWAP_BYTES = 1 * BYTES_PER_GIGABYTE
local CRITICAL_SWAP_BYTES = 3 * BYTES_PER_GIGABYTE

local menu = hs.menubar.new()
local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = BAR_HEIGHT })
local refreshTimer = nil
local readTask = nil

-- Plain-text mirror of what was last painted, for the `title` accessor.
local lastText = ""

-- Resting text colour. Read per refresh rather than cached, because the
-- appearance can flip under the running config (Auto mode at dusk).
local function restingColor()
  if hs.host.interfaceStyle() == "Dark" then
    return DARK_COLOR
  end

  return LIGHT_COLOR
end

-- Colour for one reading against its own pair of thresholds: red once
-- critical, orange once warm, otherwise the resting colour.
local function thresholdColor(value, warnAt, criticalAt)
  if value == nil then
    return restingColor()
  end

  if value >= criticalAt then
    return CRITICAL_COLOR
  end

  if value >= warnAt then
    return WARN_COLOR
  end

  return restingColor()
end

-- Styled run for one part of the row, in the colour that part carries.
local function styledValue(text, color)
  return hs.styledtext.new(text, { font = MENUBAR_FONT, color = color })
end

-- "45°" for a live reading.
local function formatCelsius(celsius)
  if celsius == nil then
    return PLACEHOLDER .. "°"
  end

  return string.format("%.0f°", celsius)
end

-- "12%" for a live figure.
local function formatPercent(percent)
  if percent == nil then
    return PLACEHOLDER .. "%"
  end

  return string.format("%.0f%%", percent)
end

-- "15G" — whole gigabytes: the decimal was noise at a glance, and dropping
-- it keeps the stacked column narrow.
local function formatGigabytes(bytes)
  if bytes == nil then
    return PLACEHOLDER
  end

  return string.format("%.0fG", bytes / BYTES_PER_GIGABYTE)
end

-- "18W" for a live figure, whole watts for the same reason.
local function formatWatts(watts)
  if watts == nil then
    return PLACEHOLDER .. WATTS_SUFFIX
  end

  return string.format("%.0f" .. WATTS_SUFFIX, watts)
end

-- The readings behind the rolling average, oldest first, with their running
-- total: the mean is wanted every refresh, and re-adding a dozen samples for
-- it is work the sum already did.
local powerSamples = {}
local powerTotal = 0

-- Take one reading into the window, dropping the oldest once the window is
-- full. A refresh that could not read power leaves the window untouched
-- rather than recording a zero, which would drag the mean down.
local function recordWatts(watts)
  if watts == nil then
    return
  end

  powerSamples[#powerSamples + 1] = watts
  powerTotal = powerTotal + watts

  if #powerSamples > POWER_SAMPLE_LIMIT then
    powerTotal = powerTotal - table.remove(powerSamples, 1)
  end
end

-- Mean of the window, or nil until the first reading lands.
local function averageWatts()
  local count = #powerSamples

  if count == 0 then
    return nil
  end

  return powerTotal / count
end

-- Tick counters from the previous refresh, against which this one is a
-- delta. hs.host.cpuUsage() would hand the percentages over ready-made, but
-- it blocks Hammerspoon for 100ms while it takes its own two samples —
-- measured at 101ms a call against 0.03ms for the raw counters. Diffing
-- across refreshes also widens the window from 100ms to the whole interval,
-- so a burst between two refreshes still shows up.
local previousCpuTicks = nil

-- Share of one core's ticks spent doing anything but idling, over the span
-- between the two samples. nil when the counters did not move, which is
-- what a wrapped or reset counter looks like.
local function coreActivePercent(core, previous)
  local activeTicks = (core.user - previous.user) + (core.system - previous.system)
    + (core.nice - previous.nice)
  local totalTicks = activeTicks + (core.idle - previous.idle)

  if totalTicks <= 0 then
    return nil
  end

  return 100 * activeTicks / totalTicks
end

-- Busiest single core and the mean across all of them, the same pairing the
-- temperature column uses: one pegged core is what a single-threaded build
-- looks like, and the mean alone hides it. Both are nil on the first
-- refresh, which has no earlier sample to diff against.
local function cpuUsagePercents()
  local ticks = hs.host.cpuUsageTicks()
  local previous = previousCpuTicks
  previousCpuTicks = ticks

  if ticks == nil or previous == nil or previous.n ~= ticks.n then
    return nil, nil
  end

  local busiest = nil
  local total = 0
  local counted = 0

  for index = 1, ticks.n do
    local percent = coreActivePercent(ticks[index], previous[index])

    if percent ~= nil then
      total = total + percent
      counted = counted + 1

      if busiest == nil or percent > busiest then
        busiest = percent
      end
    end
  end

  if counted == 0 then
    return nil, nil
  end

  return busiest, total / counted
end

-- Memory actually claimed: resident pages, plus what the kernel has pinned,
-- plus what the compressor holds. Free, inactive and speculative pages are
-- left out because macOS hands those back on demand — counting them is what
-- makes naive readouts scream 90% on an idle Mac.
local function ramUsedBytes()
  local stat = hs.host.vmStat()

  if stat == nil or stat.pageSize == nil then
    return nil
  end

  local pages = stat.pagesActive + stat.pagesWiredDown + stat.pagesUsedByVMCompressor

  return pages * stat.pageSize
end

-- One temperature figure, tinted by how close it is to throttling.
local function celsiusCell(celsius)
  return {
    text = formatCelsius(celsius),
    color = thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS),
  }
end

-- The four columns, left to right, unlabelled, each leading with the figure
-- that spikes over the one that qualifies it: busiest core over mean load,
-- hottest die over the mean of the sensor set, memory in use over swap,
-- current draw over the rolling mean. The GPU is not shown at all.
--
-- Only readings with a threshold take the warning colour: the load is not
-- what got hot, and the resident memory is not what is paging.
local function columns(reading, resting)
  local swapUsed = reading.swapUsed

  return {
    {
      top = { text = formatPercent(reading.cpuBusiestUsage), color = resting },
      bottom = { text = formatPercent(reading.cpuUsage), color = resting },
    },
    {
      top = celsiusCell(reading.cpuCelsius),
      bottom = celsiusCell(reading.cpuAverageCelsius),
    },
    {
      top = { text = formatGigabytes(reading.ramUsed), color = resting },
      bottom = {
        text = formatGigabytes(swapUsed),
        color = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES),
      },
    },
    {
      top = { text = formatWatts(reading.watts), color = resting },
      bottom = { text = formatWatts(averageWatts()), color = resting },
    },
  }
end

-- One text element, centred in its row: the two rows split the bar in half,
-- and the figure sits in the middle of its half whatever the font's own
-- line height turns out to be.
local function textElement(styled, x, row)
  local size = hs.drawing.getTextDrawingSize(styled)
  local rowHeight = BAR_HEIGHT / ROW_COUNT

  return {
    type = "text",
    text = styled,
    -- A point of slack on the width: the measured size rounds down often
    -- enough to clip the last glyph otherwise.
    frame = {
      x = x,
      y = row * rowHeight + (rowHeight - size.h) / 2,
      w = size.w + 1,
      h = size.h,
    },
  }, size.w
end

-- Lay the columns out left to right and hand the snapshot to the menubar.
-- The label heads the top row and the two figures share a left edge under
-- it, so the column reads as one block rather than two stray numbers.
local function render(reading)
  local resting = restingColor()
  local elements = {}
  local plainParts = {}
  local x = 0

  for _, column in ipairs(columns(reading, resting)) do
    local top = column.top
    local bottom = column.bottom
    local topElement, columnWidth = textElement(styledValue(top.text, top.color), x, 0)
    local plainText = top.text

    elements[#elements + 1] = topElement

    if bottom ~= nil then
      local bottomElement, bottomWidth = textElement(styledValue(bottom.text, bottom.color), x, 1)

      elements[#elements + 1] = bottomElement
      columnWidth = math.max(columnWidth, bottomWidth)
      plainText = plainText .. VALUE_SEPARATOR .. bottom.text
    end

    x = x + columnWidth + COLUMN_GAP
    plainParts[#plainParts + 1] = plainText
  end

  lastText = table.concat(plainParts, COLUMN_SEPARATOR)

  canvas:size({ w = x - COLUMN_GAP, h = BAR_HEIGHT })
  canvas:replaceElements(table.unpack(elements))

  -- template = false keeps the colours: the default treats the image as a
  -- mask and repaints the whole row in the menubar's own tint.
  menu:setIcon(canvas:imageFromCanvas(), false)
end

-- Everything the helper does not own is read here, so the row still carries
-- live load and RAM when the sensor binary never answered. Both calls are
-- counter reads rather than sampled measurements, which is what keeps the
-- refresh off the millisecond scale.
local function localReading()
  local busiestUsage, overallUsage = cpuUsagePercents()

  return {
    cpuBusiestUsage = busiestUsage,
    cpuUsage = overallUsage,
    ramUsed = ramUsedBytes(),
  }
end

-- hs.task completion: decode the helper's JSON, or fall back to
-- placeholders. A failed read must never leave a stale number on the bar —
-- a temperature frozen at 45° is worse than an obvious "--".
local function applyReading(exitCode, stdout)
  local reading = localReading()

  if exitCode ~= 0 or stdout == nil or stdout == "" then
    render(reading)
    return
  end

  local sensors = hs.json.decode(stdout)

  if sensors == nil then
    render(reading)
    return
  end

  reading.cpuCelsius = sensors.cpu
  reading.cpuAverageCelsius = sensors.cpu_avg
  reading.watts = sensors.watts
  reading.swapUsed = sensors.swap_bytes

  recordWatts(reading.watts)
  render(reading)
end

-- Kick off one asynchronous read. Skipped while a previous one is still in
-- flight, so a hung helper cannot pile up processes.
--
-- hs.task.new hands back a task object even for a path that does not exist;
-- the failure only shows up as start() returning false, and the completion
-- callback never fires. So the placeholders have to be painted here rather
-- than left to applyReading.
local function requestReading()
  if readTask ~= nil and readTask:isRunning() then
    return
  end

  readTask = hs.task.new(HELPER, applyReading)

  if readTask == nil or not readTask:start() then
    render(localReading())
  end
end

refreshTimer = hs.timer.new(REFRESH_SECONDS, requestReading)

-- Take the item out of the bar and stop polling with it: hidden, the widget
-- costs nothing — no helper process, no sysctl every five seconds.
local function hide()
  refreshTimer:stop()
  menu:removeFromMenuBar()

  canvasBanner.show({
    title = "Sensors hidden",
    subtitle = "hs -c 'require(\"temperature\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back and repaint immediately, so the restored item never shows the
-- reading it was hidden with.
local function show()
  menu:returnToMenuBar()
  requestReading()
  refreshTimer:start()
end

-- Clicking the readout is the only way to hide it, so nothing about the
-- widget needs a hotkey of its own.
menu:setClickCallback(hide)

-- Claim the menubar slot before the first read returns, so the item is
-- never a zero-width gap on startup.
render(localReading())
requestReading()
refreshTimer:start()

local widget = {
  refresh = requestReading,
  show = show,
  hide = hide,
  -- Plain text of the current readout, for checking it from `hs -c`
  -- without squinting at the menubar.
  title = function() return lastText end,
}

_G[INSTANCE_KEY] = widget

return widget
