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

-- A refresh costs about 2ms on the main thread plus a 13ms helper process
-- that runs off it, so the interval is a display choice rather than a cost
-- one. Temperature alone would sit happily at 15s, but load and throughput
-- are spiky and a stale figure reads as a broken widget.
local REFRESH_SECONDS = 1

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

-- Throughput is the one column with glyphs: an arrow says which direction a
-- rate belongs to in less width than any word would.
local ICON_DIRECTORY = hs.configdir .. "/assets/"
local UPLOAD_ICON = "arrow_up"
local DOWNLOAD_ICON = "arrow_down"

-- The token every icon paints itself with. Substituted for a hex colour at
-- render, which is how one file serves the light bar and the dark one;
-- SVG's own `currentColor` never resolves inside an NSImage.
local ICON_COLOR_TOKEN = "currentColor"

-- Square, sized to the row it sits in rather than the whole bar, with a
-- point of air after it.
local ICON_SIZE = BAR_HEIGHT / ROW_COUNT - 2
local ICON_TEXT_GAP = 2

-- The interface counters are 32-bit and wrap every 4GB — a delta modulo
-- that is exact as long as under one wrap happens between two refreshes,
-- which at this interval means anything short of a 11Gbit/s link.
local COUNTER_WRAP = 2 ^ 32

-- Rates are shown as "49 KB/s", the form Stats uses.
local BYTES_PER_KILOBYTE = 1024
local RATE_UNITS = { "B", "KB", "MB", "GB" }
local RATE_SUFFIX = "/s"

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

local BYTES_PER_MEGABYTE = 1024 * 1024
local BYTES_PER_GIGABYTE = 1024 * BYTES_PER_MEGABYTE

-- Swap gets the same two-step treatment as temperature: 200MB means the
-- compressor stopped absorbing the pressure, three gigabytes means the
-- machine is paging for real and everything starts feeling slow.
local WARN_SWAP_BYTES = 200 * BYTES_PER_MEGABYTE
local CRITICAL_SWAP_BYTES = 3 * BYTES_PER_GIGABYTE

local menu = hs.menubar.new()
local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = BAR_HEIGHT })
local refreshTimer = nil
local readTask = nil

-- Plain-text mirror of what was last painted, for the `title` accessor.
local lastText = ""

-- Raw SVG source per file, and rendered images per file-and-colour. Both are
-- permanent: two icons across at most a handful of colours.
local iconSources = {}
local iconImages = {}

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

-- "512M" under a gigabyte, "3G" above it. Swap needs the finer unit because
-- it turns orange at 200MB, and a warning colour on a figure reading "0G"
-- looks like a bug rather than a warning.
local function formatSwap(bytes)
  if bytes == nil then
    return PLACEHOLDER
  end

  if bytes < BYTES_PER_GIGABYTE then
    return string.format("%.0fM", bytes / BYTES_PER_MEGABYTE)
  end

  return formatGigabytes(bytes)
end

-- "18.1W" — one decimal, because idle draw moves in tenths and the whole
-- number alone made the column look frozen.
local function formatWatts(watts)
  if watts == nil then
    return PLACEHOLDER .. WATTS_SUFFIX
  end

  return string.format("%.1f" .. WATTS_SUFFIX, watts)
end

-- "49 KB/s" — the largest unit the rate fits in, with a decimal only below
-- ten so the column stays narrow while a slow link still shows movement.
local function formatRate(bytesPerSecond)
  if bytesPerSecond == nil then
    return PLACEHOLDER .. RATE_SUFFIX
  end

  local value = bytesPerSecond
  local unit = 1

  while value >= BYTES_PER_KILOBYTE and unit < #RATE_UNITS do
    value = value / BYTES_PER_KILOBYTE
    unit = unit + 1
  end

  local format = (value < 10 and unit > 1) and "%.1f %s" or "%.0f %s"

  return string.format(format, value, RATE_UNITS[unit]) .. RATE_SUFFIX
end

-- Counters from the previous refresh with the moment they were taken, so
-- throughput is a delta the same way CPU load is. The elapsed time is
-- measured rather than assumed to be REFRESH_SECONDS: the helper answers
-- asynchronously, and at a one-second interval that jitter is a visible
-- share of the divisor.
local previousNetworkCounters = nil

-- Bytes moved since the previous reading, unwrapping the 32-bit counter.
local function counterDelta(current, previous)
  if current >= previous then
    return current - previous
  end

  return current + COUNTER_WRAP - previous
end

-- Upload and download rates in bytes per second, or nil on the first
-- refresh, when there is no earlier counter to subtract.
local function networkRates(receivedBytes, sentBytes)
  if receivedBytes == nil or sentBytes == nil then
    return nil, nil
  end

  local previous = previousNetworkCounters
  local now = hs.timer.secondsSinceEpoch()
  previousNetworkCounters = { received = receivedBytes, sent = sentBytes, at = now }

  if previous == nil then
    return nil, nil
  end

  local elapsed = now - previous.at

  if elapsed <= 0 then
    return nil, nil
  end

  return counterDelta(sentBytes, previous.sent) / elapsed,
    counterDelta(receivedBytes, previous.received) / elapsed
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

-- The six columns, left to right, unlabelled: busiest core over mean load,
-- hottest die over the mean of the sensor set, memory in use, swap in use,
-- current draw over the rolling mean, and upload over download. Memory and
-- swap carry one figure each and sit on the top row, the way a column with
-- nothing to qualify it does. The GPU is not shown at all.
--
-- Throughput is the one column carrying icons — the arrows name the two
-- rates the way the units name the other columns.
--
-- Only readings with a threshold take the warning colour: the load is not
-- what got hot, and the resident memory is not what is paging.
local function columns(reading, resting)
  local swapUsed = reading.swapUsed
  local uploadRate, downloadRate = networkRates(reading.networkReceived, reading.networkSent)

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
    },
    {
      top = {
        text = formatSwap(swapUsed),
        color = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES),
      },
    },
    {
      top = { text = formatWatts(reading.watts), color = resting },
      bottom = { text = formatWatts(averageWatts()), color = resting },
    },
    {
      top = { icon = UPLOAD_ICON, text = formatRate(uploadRate), color = resting },
      bottom = { icon = DOWNLOAD_ICON, text = formatRate(downloadRate), color = resting },
    },
  }
end

-- Vertical placement for one of the two rows: they split the bar in half and
-- the content sits in the middle of its half, whatever height it turns out
-- to have.
local function rowOrigin(row, height)
  local rowHeight = BAR_HEIGHT / ROW_COUNT

  return row * rowHeight + (rowHeight - height) / 2
end

-- One text element and the width it claimed.
local function textElement(styled, x, row)
  local size = hs.drawing.getTextDrawingSize(styled)

  return {
    type = "text",
    text = styled,
    -- A point of slack on the width: the measured size rounds down often
    -- enough to clip the last glyph otherwise.
    frame = { x = x, y = rowOrigin(row, size.h), w = size.w + 1, h = size.h },
  }, size.w
end

-- The icon that heads one row, or nil when the row carries none or its file
-- failed to load — a missing asset costs the arrow, not the reading.
local function iconElement(name, color, x, row)
  local image = iconImage(name, color)

  if image == nil then
    return nil
  end

  return {
    type = "image",
    image = image,
    imageScaling = "scaleProportionally",
    frame = { x = x, y = rowOrigin(row, ICON_SIZE), w = ICON_SIZE, h = ICON_SIZE },
  }
end

-- One row of a column: its icon, if any, then the figure. Returns the width
-- the pair claimed, so the column can size itself to its widest row.
local function rowElements(cell, x, row, elements)
  local textX = x
  local iconWidth = 0

  if cell.icon ~= nil then
    local icon = iconElement(cell.icon, cell.color, x, row)

    if icon ~= nil then
      elements[#elements + 1] = icon
      iconWidth = ICON_SIZE + ICON_TEXT_GAP
      textX = x + iconWidth
    end
  end

  local element, textWidth = textElement(styledValue(cell.text, cell.color), textX, row)
  elements[#elements + 1] = element

  return iconWidth + textWidth
end

-- Lay the columns out left to right and hand the snapshot to the menubar.
-- The two rows of a column share a left edge, so the pair reads as one block
-- rather than two stray numbers.
local function render(reading)
  local resting = restingColor()
  local elements = {}
  local plainParts = {}
  local x = 0

  for _, column in ipairs(columns(reading, resting)) do
    local top = column.top
    local bottom = column.bottom
    local columnWidth = rowElements(top, x, 0, elements)
    local plainText = top.text

    if bottom ~= nil then
      columnWidth = math.max(columnWidth, rowElements(bottom, x, 1, elements))
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
  reading.networkReceived = sensors.net_in_bytes
  reading.networkSent = sensors.net_out_bytes

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
