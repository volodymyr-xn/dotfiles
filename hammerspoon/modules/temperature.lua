-- Menubar readout of CPU load and die temperature alongside the RAM and
-- swap in use, the machine's power draw and its throughput, refreshed on a
-- timer. Six unlabelled columns of stacked figures, the way the Stats app
-- lays its widgets out; the unit on each figure is what names it. A reading
-- turns orange, then red, as it crosses the warning and critical thresholds.
--
-- The GPU has no column — the bar has no width for one — and the streamed
-- report no longer carries it either: everything the row cannot show is
-- fetched separately when the dropdown opens.
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
-- Clicking the item opens a panel with everything the row has no width for,
-- drawn into canvases the same way the row is: sections of gauges rather
-- than lines of text, because a share of a limit is a bar and reads as one.
-- The hide action lives at the bottom of it. Once hidden, `hs -c
-- 'require("temperature").show()'` or a config reload brings it back.
--
-- The panel's readings come from a second, separate call to the same helper
-- — `c-sensor-temps-macos details` — taken once per open. It reports every
-- die sensor by name, the GPU, total memory, uptime, load and the heaviest
-- processes; the streamed report carries four figures and nothing else, so
-- the cost of all that lands on a menu that has not been drawn yet rather
-- than on every tick of a row nobody is looking at.

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

-- The sensor helper's other report, which the dropdown asks for by itself.
local DETAILS_SUBCOMMAND = " details"

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

-- The dropdown is drawn rather than typed: each section is a canvas image on
-- its own menu item, because AppKit has no gauge for a menu item and
-- hs.menubar takes a title or an image. One image per section rather than
-- one for the whole panel, so the hover highlight lands on a block the size
-- of a menu row instead of lighting up everything at once.
-- Asymmetric on purpose: AppKit indents a menu item's image by the width of
-- the checkmark column it reserves, so a left inset of its own lands on top
-- of that one and the panel reads as pushed off centre. The right side gets
-- the full margin, which is all the panel actually needs.
local PANEL_WIDTH = 340
local PANEL_LEFT_MARGIN = 4
local PANEL_RIGHT_MARGIN = 14
local PANEL_CONTENT_WIDTH = PANEL_WIDTH - PANEL_LEFT_MARGIN - PANEL_RIGHT_MARGIN

-- Above the header and below the last row of a section. Two of these plus
-- the menu's own separator are the whole gap between one section and the
-- next, so it buys twice what it reads as.
local PANEL_SECTION_PADDING = 5

-- Section heading: small, uppercase and faded, the way macOS labels a group
-- inside one of its own panels.
local PANEL_HEADER_SIZE = 10
local PANEL_HEADER_HEIGHT = 13
local PANEL_HEADER_GAP = 5

-- A reading's own line — its name on the left, its figures on the right —
-- and the smaller line that qualifies it underneath.
local PANEL_VALUE_SIZE = 12.5
local PANEL_VALUE_HEIGHT = 16
local PANEL_DETAIL_SIZE = 10.5
local PANEL_DETAIL_HEIGHT = 14

-- The bar under a reading: a full-width track with the reading's share
-- filled in, rounded enough to read as a bar rather than as a rule.
local GAUGE_HEIGHT = 4
local GAUGE_RADIUS = 2
local GAUGE_GAP = 5
local ROW_GAP = 9

-- One slot per die sensor, each filled from the bottom by how hot that one
-- sensor is: twelve cores as twelve columns, which is the shape of the
-- reading the "hottest over mean" pair only summarises.
local STRIP_HEIGHT = 16
local STRIP_GAP = 2

-- Strength of the resting colour for the panel's furniture: labels and the
-- qualifying lines at the first, the empty part of a gauge at the second.
local FADED_ALPHA = 0.52
local TRACK_ALPHA = 0.13

-- A gauge with nothing to be a share of still needs a full scale. Power gets
-- a fixed ceiling — an Apple Silicon laptop pulling this much is at its
-- sustained limit — rather than the window's own peak, which would move
-- under the bar and make a steady draw look like it was climbing.
local POWER_CEILING_WATTS = 40

-- How many processes each of the two rankings shows. The helper hands over
-- more candidates than this for the CPU one, which is re-ranked here.
local TOP_PROCESS_COUNT = 4

-- Characters a process name gets before it is cut short. An Electron helper
-- runs past the figure it shares a line with otherwise.
local PROCESS_NAME_LIMIT = 24

-- Bounds on the gap between two `details` calls that a CPU share may be
-- measured over: under the first, the figure is noise; over the second, it
-- is a mean across a stretch nobody was watching, and the process's own
-- lifetime mean is the more honest answer.
local PROCESS_SAMPLE_MINIMUM_SECONDS = 1
local PROCESS_SAMPLE_MAXIMUM_SECONDS = 600

local MILLISECONDS_PER_SECOND = 1000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

-- Separates the two figures of a detail line. Wider than a space on each
-- side because the two are different readings, not one phrase.
local DETAIL_SEPARATOR = "  ·  "

local menu = hs.menubar.new()
local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = BAR_HEIGHT })

-- Sized and painted once per section, then snapshotted: one canvas serves
-- every section of every open, the same way the row's own canvas is reused
-- across repaints.
local panelCanvas = hs.canvas.new({ x = 0, y = 0, w = PANEL_WIDTH, h = PANEL_WIDTH })

-- The previous `details` call, kept so a process's CPU share can be measured
-- between two openings rather than over its whole life.
local previousDetails = nil
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

-- The same figure for a single process, which needs a decimal the machine
-- total does not: an idle desktop is a dozen processes at a fraction of a
-- percent each, and whole numbers render that ranking as a column of zeroes.
local function formatProcessPercent(percent)
  if percent == nil then
    return PLACEHOLDER .. "%"
  end

  if percent >= 10 then
    return string.format("%.0f%%", percent)
  end

  return string.format("%.1f%%", percent)
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
  reading.watts = sensors.watts
  reading.swapUsed = sensors.swap_bytes

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

-- Clicking a panel section should do nothing, but a menu item still needs an
-- action: AppKit disables any item without one, and it draws a disabled item
-- dimmed — which would fade the whole section image, gauges included.
local function ignoreClick() end

-- One `details` call, decoded. Synchronous, because hs.menubar wants its
-- menu returned there and then and an hs.task cannot answer in time; the
-- helper takes about 7ms including the spawn, and it is paid against a panel
-- that has not been drawn yet rather than on a timer.
local function fetchDetails()
  local output = hs.execute(SENSOR_HELPER .. DETAILS_SUBCOMMAND)

  if output == nil or output == "" then
    return nil
  end

  return hs.json.decode(output)
end

-- The resting colour at reduced strength, for the panel's own furniture:
-- labels, qualifying lines, and the empty part of a gauge.
local function fadedColor(resting, alpha)
  return { white = resting.white, alpha = alpha }
end

-- Share of a scale, clamped: a reading past its ceiling fills the track
-- rather than overflowing it, and one below zero cannot happen but would
-- draw backwards if it did.
local function gaugeFraction(value, ceiling)
  if value == nil or ceiling == nil or ceiling <= 0 then
    return 0
  end

  return math.max(0, math.min(1, value / ceiling))
end

-- "3d 4h", "4h 12m", "12m" — two units, because the third never changes what
-- the first two already said.
local function formatUptime(seconds)
  if seconds == nil then
    return PLACEHOLDER
  end

  local days = math.floor(seconds / SECONDS_PER_DAY)
  local hours = math.floor(seconds % SECONDS_PER_DAY / SECONDS_PER_HOUR)
  local minutes = math.floor(seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE)

  if days > 0 then
    return string.format("%dd %dh", days, hours)
  end

  if hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end

  return string.format("%dm", minutes)
end

-- The three windows getloadavg reports, in the order it reports them.
local function formatLoadAverages(averages)
  if averages == nil or #averages == 0 then
    return PLACEHOLDER
  end

  local windows = {}

  for _, average in ipairs(averages) do
    windows[#windows + 1] = string.format("%.2f", average)
  end

  return table.concat(windows, DETAIL_SEPARATOR)
end

-- A process name that fits the label column. An Electron helper's name runs
-- past the figure it shares a line with otherwise.
local function shortenName(name)
  if name == nil then
    return PLACEHOLDER
  end

  if #name <= PROCESS_NAME_LIMIT then
    return name
  end

  return name:sub(1, PROCESS_NAME_LIMIT - 1) .. "…"
end

-- The previous call's samples by pid, so a process can be matched to its own
-- earlier reading.
local function processesByPid(samples)
  local byPid = {}

  for _, sample in ipairs(samples or {}) do
    byPid[sample.pid] = sample
  end

  return byPid
end

-- Share of one core a process took, out of cumulative CPU time: the helper
-- reports the total it has burned since it started, because a percentage
-- needs two samples and it takes one.
--
-- With an earlier call to diff against, this is the share over the gap
-- between the two — and the gap is read off the two ages rather than a clock,
-- so a line that arrived late cannot skew it. Without one, it is the mean
-- over the process's whole life, which is the honest answer for a menu that
-- was last open an hour ago.
local function processCpuPercent(sample, previous)
  if previous ~= nil and sample.cpu_ms >= previous.cpu_ms then
    local elapsed = sample.age_seconds - previous.age_seconds

    if elapsed >= PROCESS_SAMPLE_MINIMUM_SECONDS
      and elapsed <= PROCESS_SAMPLE_MAXIMUM_SECONDS then
      return 100 * (sample.cpu_ms - previous.cpu_ms) / (elapsed * MILLISECONDS_PER_SECOND)
    end
  end

  if sample.age_seconds > 0 then
    return 100 * sample.cpu_ms / (sample.age_seconds * MILLISECONDS_PER_SECOND)
  end

  return nil
end

-- The helper's candidates re-ranked by what they are doing now rather than
-- by what they have done in total, which is the order it could hand over.
local function rankedByCpu(samples, previousSamples)
  local previousByPid = processesByPid(previousSamples)
  local ranked = {}

  for _, sample in ipairs(samples or {}) do
    ranked[#ranked + 1] = {
      name = sample.name,
      percent = processCpuPercent(sample, previousByPid[sample.pid]),
    }
  end

  table.sort(ranked, function(left, right)
    return (left.percent or 0) > (right.percent or 0)
  end)

  return ranked
end

-- A panel under construction: the elements drawn so far and the vertical pen
-- they are laid against. Every row appends and advances it, which is the
-- whole layout — nothing has to know its own height in advance.
local function newPanel()
  return { elements = {}, y = PANEL_SECTION_PADDING }
end

-- One line of text at the pen's height. The label and the figure share the
-- line and the full content width, separated by their alignment alone, which
-- is also what lines the figure up with the right edge of the gauge below it
-- without a single string being measured.
local function addText(panel, text, size, height, color, alignment)
  local elements = panel.elements

  elements[#elements + 1] = {
    type = "text",
    text = text,
    textFont = MENU_FONT.name,
    textSize = size,
    textColor = color,
    textAlignment = alignment,
    frame = { x = PANEL_LEFT_MARGIN, y = panel.y, w = PANEL_CONTENT_WIDTH, h = height },
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

-- A reading's share of its scale. The track is drawn whatever the reading
-- is, so a figure at zero still shows what it is being measured against.
local function addGauge(panel, fraction, color, trackColor)
  local elements = panel.elements

  elements[#elements + 1] =
    barElement(PANEL_LEFT_MARGIN, panel.y, PANEL_CONTENT_WIDTH, GAUGE_HEIGHT, trackColor)

  if fraction > 0 then
    elements[#elements + 1] =
      barElement(PANEL_LEFT_MARGIN, panel.y, PANEL_CONTENT_WIDTH * fraction, GAUGE_HEIGHT, color)
  end

  panel.y = panel.y + GAUGE_HEIGHT
end

-- Several shares of one scale laid end to end, for a total worth breaking
-- down: what the apps hold, what the kernel pinned, what the compressor took.
local function addSegments(panel, parts, trackColor)
  local elements = panel.elements
  local x = PANEL_LEFT_MARGIN

  elements[#elements + 1] =
    barElement(PANEL_LEFT_MARGIN, panel.y, PANEL_CONTENT_WIDTH, GAUGE_HEIGHT, trackColor)

  for _, part in ipairs(parts) do
    local width = PANEL_CONTENT_WIDTH * part.fraction

    if width > 0 then
      elements[#elements + 1] = barElement(x, panel.y, width, GAUGE_HEIGHT, part.color)
      x = x + width
    end
  end

  panel.y = panel.y + GAUGE_HEIGHT
end

-- One column per die sensor, filled from the bottom by how hot that sensor
-- is: the shape the "hottest over mean" pair only summarises, and the reason
-- the helper reports the set rather than the summary of it.
local function addStrip(panel, readings, resting, trackColor)
  local count = #readings

  if count == 0 then
    return
  end

  local elements = panel.elements
  local slotWidth = (PANEL_CONTENT_WIDTH - STRIP_GAP * (count - 1)) / count

  for index, sensor in ipairs(readings) do
    local x = PANEL_LEFT_MARGIN + (slotWidth + STRIP_GAP) * (index - 1)
    local celsius = sensor.c
    local filled = STRIP_HEIGHT * gaugeFraction(celsius, CRITICAL_CELSIUS)

    elements[#elements + 1] = barElement(x, panel.y, slotWidth, STRIP_HEIGHT, trackColor)

    if filled > 0 then
      elements[#elements + 1] = barElement(x, panel.y + STRIP_HEIGHT - filled, slotWidth, filled,
        thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS, fadedColor(resting, 0.7)))
    end
  end

  panel.y = panel.y + STRIP_HEIGHT
end

-- One row: its line of text, whichever bar it carries, and the smaller line
-- that qualifies it. A row is described by which of those it has rather than
-- by a kind, so a plain reading and a gauged one are the same table with one
-- field more or less.
local function addRow(panel, row, resting)
  local faded = fadedColor(resting, FADED_ALPHA)
  local track = fadedColor(resting, TRACK_ALPHA)
  local hasBar = row.fraction ~= nil or row.parts ~= nil or row.readings ~= nil

  if row.label ~= nil then
    addText(panel, row.label, PANEL_VALUE_SIZE, PANEL_VALUE_HEIGHT, faded, "left")
  end

  if row.value ~= nil then
    addText(panel, row.value, PANEL_VALUE_SIZE, PANEL_VALUE_HEIGHT, row.color or resting, "right")
  end

  if row.label ~= nil or row.value ~= nil then
    panel.y = panel.y + PANEL_VALUE_HEIGHT + (hasBar and GAUGE_GAP or 0)
  end

  if row.fraction ~= nil then
    addGauge(panel, row.fraction, row.gaugeColor, track)
  elseif row.parts ~= nil then
    addSegments(panel, row.parts, track)
  elseif row.readings ~= nil then
    addStrip(panel, row.readings, resting, track)
  end

  if row.detail ~= nil then
    panel.y = panel.y + GAUGE_GAP
    addText(panel, row.detail, PANEL_DETAIL_SIZE, PANEL_DETAIL_HEIGHT, faded, "left")
    panel.y = panel.y + PANEL_DETAIL_HEIGHT
  end
end

-- One section, painted and snapshotted. The canvas is resized to whatever
-- the rows turned out to need rather than to a figure worked out in advance.
local function sectionImage(section, resting)
  local panel = newPanel()
  local rows = section.rows

  addText(panel, section.header, PANEL_HEADER_SIZE, PANEL_HEADER_HEIGHT,
    fadedColor(resting, FADED_ALPHA), "left")

  panel.y = panel.y + PANEL_HEADER_HEIGHT + PANEL_HEADER_GAP

  for index, row in ipairs(rows) do
    if index > 1 then
      panel.y = panel.y + ROW_GAP
    end

    addRow(panel, row, resting)
  end

  panelCanvas:size({ w = PANEL_WIDTH, h = panel.y + PANEL_SECTION_PADDING })
  panelCanvas:replaceElements(table.unpack(panel.elements))

  return panelCanvas:imageFromCanvas()
end

-- One die reading as a row of the temperature summary: hottest over mean,
-- against the threshold that decides its colour.
local function temperatureRow(label, hottest, average, resting)
  return {
    label = label,
    value = formatCelsius(hottest) .. " hottest" .. DETAIL_SEPARATOR
      .. formatCelsius(average) .. " mean",
    color = thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS, resting),
    fraction = gaugeFraction(hottest, CRITICAL_CELSIUS),
    gaugeColor = thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS,
      fadedColor(resting, 0.75)),
  }
end

-- Both dies in one place, which is the question the widget is named after
-- and the one the row itself can only answer for the CPU. The sensor sets
-- these summarise stay with the unit they belong to, further down.
local function temperatureSection(details, resting)
  return {
    header = "Temperature",
    rows = {
      temperatureRow("CPU", details.cpu, details.cpu_avg, resting),
      temperatureRow("GPU", details.gpu, details.gpu_avg, resting),
    },
  }
end

-- Load, then the whole sensor set the summary above was reduced from. The
-- load figures stay Hammerspoon's own: the helper has no CPU utilisation to
-- report, because hs.host.cpuUsageTicks() already does.
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
        fraction = gaugeFraction(busiest, 100),
        gaugeColor = fadedColor(resting, 0.75),
      },
      { label = "Cores", readings = details.cpu_sensors or {} },
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
        fraction = gaugeFraction(usage, 100),
        gaugeColor = fadedColor(resting, 0.75),
      },
      { label = "Dies", readings = details.gpu_sensors or {} },
    },
  }
end

-- Memory read again here rather than taken from the last tick: it is a
-- counter read, and the panel is a snapshot of the moment it opened.
local function memorySection(details, resting)
  local memory = memoryUsage() or {}
  local total = details.ram_total_bytes
  local swapUsed = details.swap_bytes

  return {
    header = "Memory",
    rows = {
      {
        label = "RAM",
        value = formatGigabytes(memory.used) .. " of " .. formatGigabytes(total),
        parts = {
          { fraction = gaugeFraction(memory.app, total), color = fadedColor(resting, 0.85) },
          { fraction = gaugeFraction(memory.wired, total), color = fadedColor(resting, 0.55) },
          { fraction = gaugeFraction(memory.compressed, total), color = fadedColor(resting, 0.3) },
        },
        detail = "app " .. formatBytes(memory.app) .. DETAIL_SEPARATOR
          .. "wired " .. formatBytes(memory.wired) .. DETAIL_SEPARATOR
          .. "compressed " .. formatBytes(memory.compressed),
      },
      {
        label = "Swap",
        value = formatBytes(swapUsed) .. " in use",
        color = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting),
        fraction = gaugeFraction(swapUsed, CRITICAL_SWAP_BYTES),
        gaugeColor = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES,
          fadedColor(resting, 0.75)),
      },
    },
  }
end

-- The rolling window stays Hammerspoon's: it is built from the streamed
-- readings, one every couple of seconds, which is the only place a minute of
-- history exists.
local function powerSection(details, resting)
  local lowestWatts, highestWatts = wattsRange()

  return {
    header = "Power",
    rows = {
      {
        label = "Draw",
        value = formatWatts(details.watts) .. " now" .. DETAIL_SEPARATOR
          .. formatWatts(averageWatts()) .. " mean",
        fraction = gaugeFraction(details.watts, POWER_CEILING_WATTS),
        gaugeColor = fadedColor(resting, 0.75),
        detail = string.format("%s low%s%s peak over the last %ds",
          formatWatts(lowestWatts), DETAIL_SEPARATOR, formatWatts(highestWatts),
          POWER_AVERAGE_SECONDS),
      },
    },
  }
end

-- Throughput comes from the other helper's stream, and rates are a delta
-- across two of its lines, so there is nothing here for a one-shot call to
-- report.
local function networkSection()
  local reading = lastReading

  return {
    header = "Network",
    rows = {
      {
        label = reading.networkInterface or PLACEHOLDER,
        value = "↑ " .. formatRate(reading.uploadRate) .. "   ↓ "
          .. formatRate(reading.downloadRate),
        -- Not "since boot": the kernel counter these come from is 32-bit and
        -- starts over every 4G, so the totals are since its last wrap.
        detail = formatBytes(reading.networkReceived) .. " in" .. DETAIL_SEPARATOR
          .. formatBytes(reading.networkSent) .. " out since the 4G counter wrap",
      },
    },
  }
end

-- Load average rather than another CPU percentage: it counts threads waiting
-- for a turn, so a machine at 20% with a load of twelve is stuck on
-- something the utilisation figures cannot show.
local function systemSection(details)
  return {
    header = "System",
    rows = {
      { label = "Uptime", value = formatUptime(details.uptime_seconds) },
      { label = "Load avg", value = formatLoadAverages(details.load_avg) },
    },
  }
end

local function topCpuSection(details, resting)
  local ranked = rankedByCpu(details.top_cpu, previousDetails and previousDetails.top_cpu)
  local rows = {}

  for index = 1, math.min(TOP_PROCESS_COUNT, #ranked) do
    local process = ranked[index]

    rows[#rows + 1] = {
      label = shortenName(process.name),
      value = formatProcessPercent(process.percent),
      fraction = gaugeFraction(process.percent, 100),
      gaugeColor = fadedColor(resting, 0.6),
    }
  end

  return { header = "Top by CPU", rows = rows }
end

local function topMemorySection(details, resting)
  local total = details.ram_total_bytes
  local samples = details.top_memory or {}
  local rows = {}

  for index = 1, math.min(TOP_PROCESS_COUNT, #samples) do
    local process = samples[index]

    rows[#rows + 1] = {
      label = shortenName(process.name),
      value = formatBytes(process.rss_bytes),
      fraction = gaugeFraction(process.rss_bytes, total),
      gaugeColor = fadedColor(resting, 0.6),
    }
  end

  return { header = "Top by memory", rows = rows }
end

-- Everything the bar has no width for, rebuilt each time the panel opens so
-- it carries the reading of the moment it was opened rather than the one the
-- menu was built on.
local function detailSections(resting)
  local details = fetchDetails() or {}
  -- Memory leads, the way it leads the row: it is the figure worth a glance.
  -- The temperature summary follows, and the per-unit sections after it.
  local sections = {
    memorySection(details, resting),
    temperatureSection(details, resting),
    cpuSection(details, resting),
    gpuSection(details, resting),
    powerSection(details, resting),
    networkSection(),
    systemSection(details),
    topCpuSection(details, resting),
    topMemorySection(details, resting),
  }

  previousDetails = details

  return sections
end

local function detailMenu()
  local resting = menuTextColor()
  local items = {}

  for _, section in ipairs(detailSections(resting)) do
    if #section.rows > 0 then
      -- template = false keeps the colours, the same way the row's own icon
      -- does: the default treats the image as a mask and repaints it in the
      -- menu's own tint.
      local image = sectionImage(section, resting):template(false)

      items[#items + 1] = { title = "", image = image, fn = ignoreClick }
      items[#items + 1] = { title = "-" }
    end
  end

  items[#items + 1] = { title = styledValue("Hide sensors", resting, MENU_FONT), fn = hide }

  return items
end

-- A menu rather than a click callback: hs.menubar honours one or the other,
-- and the hide action lives in the menu now that the click opens it.
menu:setMenu(detailMenu)

-- The plain-text mirror of one panel row, for reading the panel from `hs -c`
-- without opening it. A gauge has no text to mirror; the sensor strip does,
-- and it is the one thing the panel shows that no line of the old menu ever
-- did.
local function rowText(row)
  local lines = {}

  if row.value ~= nil then
    lines[#lines + 1] = string.format("  %-27s %s", row.label or "", row.value)
  elseif row.label ~= nil then
    lines[#lines + 1] = "  " .. row.label
  end

  if row.readings ~= nil then
    local sensors = {}

    for _, sensor in ipairs(row.readings) do
      sensors[#sensors + 1] = sensor.key .. " " .. formatCelsius(sensor.c)
    end

    lines[#lines + 1] = "  " .. table.concat(sensors, "  ")
  end

  if row.detail ~= nil then
    lines[#lines + 1] = "  " .. row.detail
  end

  return table.concat(lines, "\n")
end

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

    for _, section in ipairs(detailSections(menuTextColor())) do
      lines[#lines + 1] = section.header

      for _, row in ipairs(section.rows) do
        lines[#lines + 1] = rowText(row)
      end
    end

    return table.concat(lines, "\n")
  end,
}

_G[INSTANCE_KEY] = widget

return widget
