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
-- What this file owns is the row, the panel and the cadence they refresh on.
-- Taking the readings does not live here: cpu_ticks, memory_usage,
-- net_counters and power_window each own one source and the baseline it needs
-- to be a rate, and line_stream owns the helper processes they read from.
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
local netCounters = require("net_counters")
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
local formatRate = statFormat.rate
local PLACEHOLDER = statFormat.PLACEHOLDER

-- Absolute paths because hs.task does not consult the login shell's PATH,
-- which is where ~/dotfiles/bin_native/macos is added.
local NATIVE_DIRECTORY = os.getenv("HOME") .. "/dotfiles/bin_native/macos/"
local SENSOR_HELPER = NATIVE_DIRECTORY .. "c-system-sensors-macos"
local NETWORK_HELPER = NATIVE_DIRECTORY .. "c-net-counters-macos"

-- The sensor helper's other report, which the dropdown asks for by itself
-- rather than reading off the stream.
local DETAILS_SUBCOMMAND = " details"

-- Both helpers stream a line per interval through lib/line_stream, which
-- carries why that beats spawning one per refresh.
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

-- The reserved-width template below is measured in these, so the suffix has
-- to match the one stat_format puts on a rate.
local RATE_SUFFIX = "/s"

-- The throughput column alone is reserved at the width of its widest reading
-- and its figures are right-aligned inside that. Rates swing between "0 B/s"
-- and "999 MB/s" from one second to the next, several digits at a time; the
-- other columns move by a digit at most, and reserving them too left visible
-- gaps between the figures.
--
-- Eights because they are the widest digit in a proportional face.
local RATE_WIDTH_TEMPLATE = "888 MB" .. RATE_SUFFIX

-- nf-md-eye_off — the banner glyph confirming the widget was hidden.
local HIDDEN_ICON = "󰛑"

local WARN_COLOR = { red = 1, green = 0.58, blue = 0, alpha = 1 }
local CRITICAL_COLOR = { red = 1, green = 0.23, blue = 0.19, alpha = 1 }

-- The macOS UI font, which is what the Stats app draws its widgets with
-- (NSFont.systemFont); the hidden PostScript name is how AppKit exposes it.
-- Two rows in the height of the menubar leave room for about 9pt, which is
-- the size Stats sets its own stacked widgets in.
local MENUBAR_FONT = { name = ".AppleSystemUIFont", size = 10 }

-- A column carrying one figure spans both rows, so it can afford a size the
-- stacked columns cannot.
local SOLO_COLUMN_FONT = { name = ".AppleSystemUIFont", size = 13.9 }

-- The idle-swap word is the one cell carrying prose instead of a figure, so
-- it is set bold to keep the weight of a reading next to the numbers.
local SOLO_COLUMN_BOLD_FONT = { name = ".AppleSystemUIFontBold", size = 13.9 }

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

-- The row follows the system appearance, same as the panel behind it: white
-- text in Dark, black in Light. It does not follow the wallpaper the way macOS
-- tints its own items — that needs the strip behind the bar sampled, which
-- nothing in Hammerspoon exposes.
local function barTextColor()
  return statPanel.textColor()
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

-- Rate, load and memory readings all come from lib collectors; the two that
-- need a baseline (throughput, CPU load) get an instance of their own here,
-- so nothing else in this Lua state can consume the span between two of this
-- widget's refreshes.
local networkTracker = netCounters.new()
local cpuSampler = cpuTicks.new()
local wattsWindow = powerWindow.new(POWER_SAMPLE_LIMIT)

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

-- Idle swap reads "No swap" rather than "0B": zero paging is a state, and the
-- word says so where a zeroed size looks like a stalled reading.
local function swapCell(bytes, resting)
  local color = thresholdColor(bytes, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting)

  if bytes == 0 then
    return { text = NO_SWAP_TEXT, color = color, font = SOLO_COLUMN_BOLD_FONT }
  end

  return { text = formatBytes(bytes), color = color, font = SOLO_COLUMN_FONT }
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
    networkTracker.rates(reading.networkReceived, reading.networkSent)

  readingChanged = true
end

-- Start one helper in watch mode, at the cadence it should report on.
-- "watch" is this pair of helpers' own subcommand, not something lib knows.
local function startStream(path, intervalMilliseconds, handleLine)
  return lineStream.start(path, { "watch", tostring(intervalMilliseconds) }, handleLine)
end

local function startStreams()
  if not lineStream.isRunning(sensorTask) then
    sensorTask = startStream(SENSOR_HELPER, SENSOR_INTERVAL_MILLISECONDS, applySensorLine)
  end

  if not lineStream.isRunning(networkTask) then
    networkTask = startStream(NETWORK_HELPER, NETWORK_INTERVAL_MILLISECONDS, applyNetworkLine)
  end
end

local function stopStreams()
  lineStream.stop(sensorTask)
  lineStream.stop(networkTask)

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
    subtitle = "hs -c 'require(\"system_stats\").show()'",
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
    color = thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS, resting),
    fraction = statPanel.fraction(hottest, CRITICAL_CELSIUS),
    gaugeColor = thresholdColor(hottest, WARN_CELSIUS, CRITICAL_CELSIUS,
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
      color = thresholdColor(celsius, WARN_CELSIUS, CRITICAL_CELSIUS, resting70),
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
        color = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES, resting),
        fraction = statPanel.fraction(swapUsed, CRITICAL_SWAP_BYTES),
        gaugeColor = thresholdColor(swapUsed, WARN_SWAP_BYTES, CRITICAL_SWAP_BYTES,
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

-- Everything the bar has no width for, rebuilt each time the panel opens so it
-- carries the reading of the moment it was opened rather than the one the menu
-- was built on.
--
-- Processes, uptime and load average are not here: they have a menubar item of
-- their own, and the helper behind it never runs for this one.
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
    networkSection(),
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
    return statPanel.stackText(detailSections(statPanel.textColor()))
  end,
}

_G[INSTANCE_KEY] = widget

return widget
