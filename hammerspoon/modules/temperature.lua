-- Menubar readout of CPU load and die temperature alongside the RAM and
-- swap in use, the machine's power draw and its throughput, refreshed on a
-- timer. Six unlabelled columns of stacked figures, the way the Stats app
-- lays its widgets out; the unit on each figure is what names it. A reading
-- turns orange, then red, as it crosses the warning and critical thresholds.
--
-- The GPU has no column — the bar has no width for one — but the helper
-- still reports its temperature and load, and the detail menu shows them.
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
-- Clicking the item opens a menu with everything the row has no width for,
-- and the hide action lives at the bottom of it. Once hidden, `hs -c
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

-- Absolute paths because hs.task does not consult the login shell's PATH,
-- which is where ~/dotfiles/bin_native/macos is added.
local NATIVE_DIRECTORY = os.getenv("HOME") .. "/dotfiles/bin_native/macos/"
local SENSOR_HELPER = NATIVE_DIRECTORY .. "c-sensor-temps-macos"
local NETWORK_HELPER = NATIVE_DIRECTORY .. "c-net-counters-macos"

-- Both helpers are started once in `watch` mode and stream a line per
-- interval, rather than being spawned per refresh: the spawn cost about
-- 13ms of Hammerspoon's main thread — six times the actual reading — and it
-- was paid on every tick.
--
-- Both on the same second: throughput is the spikiest reading and was worth
-- twice the cadence on its own, but every extra line lands a repaint, and a
-- repaint costs more than the readings behind it.
local SENSOR_INTERVAL_MILLISECONDS = 2000
local NETWORK_INTERVAL_MILLISECONDS = 2000

-- How often a dead stream is noticed and restarted. Loose because a helper
-- that dies at all is the unexpected case — this is a backstop, not a poll.
local SUPERVISOR_SECONDS = 10

-- Repaints are driven by this rather than by the streams themselves. A paint
-- costs about 5ms, nearly all of it measuring strings, and the two streams
-- would otherwise land three paints a second between them — a third of which
-- redraw figures no reader could have seen change. Matching the faster
-- stream keeps the row as fresh as its freshest source and no fresher.
local PAINT_INTERVAL_SECONDS = NETWORK_INTERVAL_MILLISECONDS / 1000

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
local POWER_SAMPLE_LIMIT = POWER_AVERAGE_SECONDS * 1000 / SENSOR_INTERVAL_MILLISECONDS
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

-- Roughly the share of a line box the system font leaves below the baseline.
-- Half of it is what a digits-only figure has to come down by to sit on the
-- optical centre rather than the geometric one.
local DESCENDER_SHARE = 0.09

-- The interface counters are 32-bit and wrap every 4GB — a delta modulo
-- that is exact as long as under one wrap happens between two refreshes,
-- which at this interval means anything short of a 11Gbit/s link.
local COUNTER_WRAP = 2 ^ 32

-- Rates are shown as "49 KB/s", the form Stats uses; plain sizes get the
-- one-letter form instead, because they share a column with the readings.
local BYTES_PER_KILOBYTE = 1024
local RATE_UNITS = { "B", "KB", "MB", "GB" }
local SIZE_UNITS = { "B", "K", "M", "G", "T" }
local RATE_SUFFIX = "/s"

-- The throughput column alone is reserved at the width of its widest reading
-- and its figures are right-aligned inside that. Rates swing between "0 B/s"
-- and "999 MB/s" from one second to the next, several digits at a time; the
-- other columns move by a digit at most, and reserving them too left visible
-- gaps between the figures.
--
-- Eights because they are the widest digit in a proportional face.
local RATE_WIDTH_TEMPLATE = "888 MB" .. RATE_SUFFIX

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

-- A column carrying one figure spans both rows, so it can afford a size the
-- stacked columns cannot.
local SOLO_COLUMN_FONT = { name = ".AppleSystemUIFont", size = 13.9 }

-- The detail menu takes the system font at the size macOS sets its own menu
-- items in, so the panel reads as a native menu rather than a terminal.
local MENU_FONT = { name = ".AppleSystemUIFont", size = 13 }

local BYTES_PER_MEGABYTE = 1024 * 1024
local BYTES_PER_GIGABYTE = 1024 * BYTES_PER_MEGABYTE

-- Swap gets the same two-step treatment as temperature: 200MB means the
-- compressor stopped absorbing the pressure, three gigabytes means the
-- machine is paging for real and everything starts feeling slow.
local WARN_SWAP_BYTES = 200 * BYTES_PER_MEGABYTE
local CRITICAL_SWAP_BYTES = 3 * BYTES_PER_GIGABYTE

local menu = hs.menubar.new()
local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = BAR_HEIGHT })
local sensorTask = nil
local networkTask = nil
local supervisorTimer = nil
local paintTimer = nil

-- Set when a stream reports something the row does not show yet, cleared by
-- the paint that shows it.
local readingChanged = false
local lastPaintMilliseconds = 0

-- Plain-text mirror of what was last painted, for the `title` accessor, and
-- the snapshot behind it, which the detail menu reads when it opens.
local lastText = ""
local lastReading = {}

-- Raw SVG source per file, and rendered images per file-and-colour. Both are
-- permanent: two icons across at most a handful of colours.
local iconSources = {}
local iconImages = {}

-- Resting colour for the detail menu, which macOS paints in the appearance
-- of the moment: white text on the dark panel, black on the light one. Read
-- per open rather than cached, because the appearance can flip under the
-- running config (Auto mode at dusk).
local function menuTextColor()
  if hs.host.interfaceStyle() == "Dark" then
    return DARK_COLOR
  end

  return LIGHT_COLOR
end

-- The row follows the system appearance, same as the menu: white text in
-- Dark, black in Light. It does not follow the wallpaper the way macOS tints
-- its own items — that needs the strip behind the bar sampled, which nothing
-- in Hammerspoon exposes.
local function barTextColor()
  return menuTextColor()
end

-- Colour for one reading against its own pair of thresholds: red once
-- critical, orange once warm, otherwise the resting colour it was handed —
-- which differs between the bar and the menu, so it is passed in rather
-- than looked up here.
local function thresholdColor(value, warnAt, criticalAt, resting)
  if value == nil then
    return resting
  end

  if value >= criticalAt then
    return CRITICAL_COLOR
  end

  if value >= warnAt then
    return WARN_COLOR
  end

  return resting
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

-- Styled run for one part of the row, in the colour and size that part
-- carries; a cell without a font of its own takes the stacked-row one.
local function styledValue(text, color, font)
  return hs.styledtext.new(text, { font = font or MENUBAR_FONT, color = color })
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

-- "15GB" — whole gigabytes: the decimal was noise at a glance, and dropping
-- it keeps the column narrow.
local function formatGigabytes(bytes)
  if bytes == nil then
    return PLACEHOLDER
  end

  return string.format("%.0fGB", bytes / BYTES_PER_GIGABYTE)
end

-- "512M", "3G", "1.2T" — a size in the largest unit it fills, one letter and
-- no space so it stays column-width. Swap needs the finer units because it
-- turns orange at 200MB, and a warning colour on a figure reading "0G" looks
-- like a bug rather than a warning.
local function formatBytes(bytes)
  if bytes == nil then
    return PLACEHOLDER
  end

  local value = bytes
  local unit = 1

  while value >= BYTES_PER_KILOBYTE and unit < #SIZE_UNITS do
    value = value / BYTES_PER_KILOBYTE
    unit = unit + 1
  end

  local format = (value < 10 and unit > 1) and "%.1f%s" or "%.0f%s"

  return string.format(format, value, SIZE_UNITS[unit])
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
-- measured rather than assumed to match the helper's interval: lines arrive
-- when the scheduler gets to them, and at half a second that jitter is a
-- visible share of the divisor.
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

-- Floor and ceiling of the same window, for the detail menu: the mean says
-- what a stretch cost, these two say how spiky it was.
local function wattsRange()
  local lowest = nil
  local highest = nil

  for _, watts in ipairs(powerSamples) do
    if lowest == nil or watts < lowest then
      lowest = watts
    end

    if highest == nil or watts > highest then
      highest = watts
    end
  end

  return lowest, highest
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

-- Memory actually claimed, split the way the menu shows it — Activity
-- Monitor's own formula: app memory (anonymous pages minus what is
-- purgeable on demand), what the kernel has pinned, and what the
-- compressor holds. Anonymous rather than active, because inactive
-- anonymous pages still hold app data; counting only the active ones
-- undercounts by whatever the apps have not touched lately.
local function memoryUsage()
  local stat = hs.host.vmStat()

  if stat == nil or stat.pageSize == nil then
    return nil
  end

  local pageSize = stat.pageSize
  local app = (stat.anonymousPages - stat.pagesPurgeable) * pageSize
  local wired = stat.pagesWiredDown * pageSize
  local compressed = stat.pagesUsedByVMCompressor * pageSize

  return {
    app = app,
    wired = wired,
    compressed = compressed,
    used = app + wired + compressed,
  }
end

-- Width a column claims whatever it currently reads: its widest form, plus
-- the icon and the gap after it when the column carries one. Measured once
-- per template and kept — the fonts never change under a running config, and
-- measuring is the most expensive thing a repaint does.
local reservedWidths = {}

local function reservedWidth(template, font, withIcon)
  local key = template .. (font or MENUBAR_FONT).size .. tostring(withIcon)
  local cached = reservedWidths[key]

  if cached ~= nil then
    return cached
  end

  local width = hs.drawing.getTextDrawingSize(styledValue(template, barTextColor(), font)).w

  if withIcon then
    width = width + ICON_SIZE + ICON_TEXT_GAP
  end

  reservedWidths[key] = width

  return width
end

-- One temperature figure, tinted by how close it is to throttling.
local function celsiusCell(celsius, resting)
  return {
    text = formatCelsius(celsius),
    color = thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS, resting),
  }
end

-- The six columns, left to right, unlabelled: memory in use, swap in use,
-- busiest core over mean load, hottest die over the mean of the sensor set,
-- current draw over the rolling mean, and upload over download. Memory leads
-- because it is the figure worth a glance; it and swap carry one value each
-- and span both rows, the way a column with nothing to qualify it does. The
-- GPU is not shown at all.
--
-- Throughput is the one column carrying icons — the arrows name the two
-- rates the way the units name the other columns.
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
      top = {
        text = formatBytes(swapUsed),
        color = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting),
        font = SOLO_COLUMN_FONT,
      },
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
      bottom = { text = formatWatts(averageWatts()), color = resting },
    },
    {
      reservedWidth = reservedWidth(RATE_WIDTH_TEMPLATE, nil, true),
      top = { icon = UPLOAD_ICON, text = formatRate(reading.uploadRate), color = resting },
      bottom = { icon = DOWNLOAD_ICON, text = formatRate(reading.downloadRate), color = resting },
    },
  }
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

-- One text element, from a run whose size the caller already measured.
-- Measuring is the single most expensive thing a repaint does — 0.38ms a
-- string against 0.2ms for the whole canvas — so it happens once per cell
-- and the result is passed along rather than asked for twice.
local function textElement(styled, size, x, row, span)
  return {
    type = "text",
    text = styled,
    -- A point of slack on the width: the measured size rounds down often
    -- enough to clip the last glyph otherwise.
    frame = { x = x, y = rowOrigin(row, span, size.h), w = size.w + 1, h = size.h },
  }
end

-- The icon that heads one row, or nil when the row carries none or its file
-- failed to load — a missing asset costs the arrow, not the reading.
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
local function bandElements(cell, x, row, span, boxWidth, elements)
  local textX = x
  local iconWidth = 0

  if cell.icon ~= nil then
    local icon = iconElement(cell.icon, cell.color, x, row, span)

    if icon ~= nil then
      elements[#elements + 1] = icon
      iconWidth = ICON_SIZE + ICON_TEXT_GAP
      textX = x + iconWidth
    end
  end

  local styled = styledValue(cell.text, cell.color, cell.font)
  local size = hs.drawing.getTextDrawingSize(styled)

  if boxWidth ~= nil then
    textX = x + boxWidth - size.w
  end

  elements[#elements + 1] = textElement(styled, size, textX, row, span)

  return iconWidth + size.w
end

-- Lay the columns out left to right and hand the snapshot to the menubar.
-- The two rows of a column share a left edge, so the pair reads as one block
-- rather than two stray numbers.
local function render(reading)
  local resting = barTextColor()
  local elements = {}
  local plainParts = {}
  local x = 0

  lastReading = reading

  for _, column in ipairs(columns(reading, resting)) do
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

  lastText = table.concat(plainParts, COLUMN_SEPARATOR)

  canvas:size({ w = x - COLUMN_GAP, h = BAR_HEIGHT })
  canvas:replaceElements(table.unpack(elements))

  -- template = false keeps the colours: the default treats the image as a
  -- mask and repaints the whole row in the menubar's own tint.
  menu:setIcon(canvas:imageFromCanvas(), false)
end

-- One reading merged from both streams, because they arrive on different
-- cadences and either one landing should repaint the whole row rather than
-- blank the readings the other owns.
local reading = {}

-- What the helpers do not own is read on the sensor tick: hs.host counters,
-- which are counter reads rather than sampled measurements and so cost
-- microseconds.
local function applySensorLine(line)
  local sensors = hs.json.decode(line)

  if sensors == nil then
    return
  end

  local busiestUsage, overallUsage = cpuUsagePercents()
  local memory = memoryUsage()

  reading.cpuBusiestUsage = busiestUsage
  reading.cpuUsage = overallUsage
  reading.memory = memory
  reading.ramUsed = memory ~= nil and memory.used or nil
  reading.cpuCelsius = sensors.cpu
  reading.cpuAverageCelsius = sensors.cpu_avg
  reading.gpuCelsius = sensors.gpu
  reading.gpuAverageCelsius = sensors.gpu_avg
  reading.gpuUsage = sensors.gpu_usage
  reading.watts = sensors.watts
  reading.swapUsed = sensors.swap_bytes
  reading.ramTotal = sensors.ram_total_bytes

  recordWatts(reading.watts)
  readingChanged = true
end

-- Counters in, rates out. Taking a rate consumes the previous counters, so
-- it happens exactly once per line — never in the layout, which runs again
-- whenever the other stream reports.
local function applyNetworkLine(line)
  local counters = hs.json.decode(line)

  if counters == nil then
    return
  end

  reading.networkReceived = counters["in"]
  reading.networkSent = counters.out
  reading.networkInterface = counters.interface
  reading.uploadRate, reading.downloadRate =
    networkRates(reading.networkReceived, reading.networkSent)

  readingChanged = true
end

-- A streaming callback that hands whole lines to `handleLine`. hs.task
-- delivers whatever the pipe had, which is usually one line and occasionally
-- half of one, so the remainder is carried to the next call.
local function lineReader(handleLine)
  local pending = ""

  return function(_, stdout, _)
    if stdout == nil then
      return true
    end

    pending = pending .. stdout

    while true do
      local newline = pending:find("\n")

      if newline == nil then
        break
      end

      handleLine(pending:sub(1, newline - 1))
      pending = pending:sub(newline + 1)
    end

    return true
  end
end

-- Start one helper in watch mode, or nil when the binary is missing.
-- hs.task.new hands back a task object even for a path that does not exist;
-- the failure only shows up as start() returning false.
local function startStream(path, intervalMilliseconds, handleLine)
  local task = hs.task.new(path, nil, lineReader(handleLine),
    { "watch", tostring(intervalMilliseconds) })

  if task == nil or not task:start() then
    return nil
  end

  return task
end

local function startStreams()
  if sensorTask == nil or not sensorTask:isRunning() then
    sensorTask = startStream(SENSOR_HELPER, SENSOR_INTERVAL_MILLISECONDS, applySensorLine)
  end

  if networkTask == nil or not networkTask:isRunning() then
    networkTask = startStream(NETWORK_HELPER, NETWORK_INTERVAL_MILLISECONDS, applyNetworkLine)
  end
end

local function stopStream(task)
  if task ~= nil and task:isRunning() then
    task:terminate()
  end
end

local function stopStreams()
  stopStream(sensorTask)
  stopStream(networkTask)

  sensorTask = nil
  networkTask = nil
end

-- Paint only what a stream actually changed, and only on this cadence: the
-- row is redrawn at most twice a second however many lines arrive.
local function paintIfChanged()
  if not readingChanged then
    return
  end

  readingChanged = false

  local started = hs.timer.absoluteTime()
  render(reading)
  lastPaintMilliseconds = (hs.timer.absoluteTime() - started) / 1e6
end

-- A helper that dies takes its readings with it and nothing else notices, so
-- this is the backstop that starts it again.
supervisorTimer = hs.timer.new(SUPERVISOR_SECONDS, startStreams)
paintTimer = hs.timer.new(PAINT_INTERVAL_SECONDS, paintIfChanged)

-- Take the item out of the bar and kill both helpers with it: hidden, the
-- widget costs nothing, not even the two processes.
local function hide()
  supervisorTimer:stop()
  paintTimer:stop()
  stopStreams()
  menu:removeFromMenuBar()

  canvasBanner.show({
    title = "Sensors hidden",
    subtitle = "hs -c 'require(\"temperature\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back and start the streams again. The first line lands within an
-- interval, and until then the row shows the placeholders it was built with
-- rather than the readings it was hidden on.
local function show()
  menu:returnToMenuBar()
  startStreams()
  supervisorTimer:start()
  paintTimer:start()
end

-- Clicking a readout row should do nothing, but the row still needs an
-- action: AppKit disables any menu item without one and paints disabled
-- items grey, which overrides the colour the row asks for. A no-op keeps
-- the text at full strength.
local function ignoreClick() end

-- One detail row: the name, then the figures, styled in the same colour the
-- bar uses — white against the dark menu, black against the light one.
local function detailRow(name, value)
  local text = string.format("%-5s  %s", name, value)

  return { title = styledValue(text, menuTextColor(), MENU_FONT), fn = ignoreClick }
end

-- Everything the bar has no width for, rebuilt each time the menu opens so
-- it carries the current refresh rather than the one the menu was built on.
local function detailMenu()
  local reading = lastReading
  local memory = reading.memory or {}
  local lowestWatts, highestWatts = wattsRange()
  local interface = reading.networkInterface or PLACEHOLDER

  return {
    detailRow("CPU", string.format("busiest %s  ·  mean %s",
      formatPercent(reading.cpuBusiestUsage), formatPercent(reading.cpuUsage))),
    detailRow("Temp", string.format("hottest %s  ·  mean %s",
      formatCelsius(reading.cpuCelsius), formatCelsius(reading.cpuAverageCelsius))),
    detailRow("GPU", string.format("%s hottest  ·  %s mean  ·  %s busy",
      formatCelsius(reading.gpuCelsius), formatCelsius(reading.gpuAverageCelsius),
      formatPercent(reading.gpuUsage))),
    { title = "-" },
    detailRow("RAM", string.format("%s of %s used",
      formatGigabytes(reading.ramUsed), formatGigabytes(reading.ramTotal))),
    detailRow("", string.format("app %s  ·  wired %s  ·  compressed %s",
      formatBytes(memory.app), formatBytes(memory.wired), formatBytes(memory.compressed))),
    detailRow("Swap", formatBytes(reading.swapUsed) .. " in use"),
    { title = "-" },
    detailRow("Power", string.format("%s now  ·  %s mean over %ds",
      formatWatts(reading.watts), formatWatts(averageWatts()), POWER_AVERAGE_SECONDS)),
    detailRow("", string.format("%s low  ·  %s peak",
      formatWatts(lowestWatts), formatWatts(highestWatts))),
    { title = "-" },
    detailRow("Net", string.format("%s up  ·  %s down  (%s)",
      formatRate(reading.uploadRate), formatRate(reading.downloadRate), interface)),
    -- Not "since boot": the kernel counter these come from is 32-bit and
    -- starts over every 4G, so the totals are since its last wrap.
    detailRow("", string.format("%s in  ·  %s out since the 4G counter wrap",
      formatBytes(reading.networkReceived), formatBytes(reading.networkSent))),
    { title = "-" },
    { title = styledValue("Hide sensors", menuTextColor(), MENU_FONT), fn = hide },
  }
end

-- A menu rather than a click callback: hs.menubar honours one or the other,
-- and the hide action lives in the menu now that the click opens it.
menu:setMenu(detailMenu)

-- Restart both helpers, which is the only "refresh" a streaming widget has:
-- the readings arrive on their own, and the useful manual action is bringing
-- a stream back after killing its process by hand.
local function restart()
  stopStreams()
  startStreams()
end

-- Claim the menubar slot before the first line arrives, so the item is never
-- a zero-width gap on startup.
render(reading)
startStreams()
supervisorTimer:start()
paintTimer:start()

local widget = {
  refresh = restart,
  show = show,
  hide = hide,
  -- Plain text of the current readout and of the menu behind it, for
  -- checking both from `hs -c` without squinting at the menubar.
  title = function() return lastText end,
  paintCost = function() return lastPaintMilliseconds end,
  details = function()
    local lines = {}

    for _, row in ipairs(detailMenu()) do
      local title = row.title

      -- Separator rows are plain strings; the rest are styled runs, whose
      -- text has to be asked for by name.
      lines[#lines + 1] = type(title) == "string" and title or title:getString()
    end

    return table.concat(lines, "\n")
  end,
}

_G[INSTANCE_KEY] = widget

return widget
