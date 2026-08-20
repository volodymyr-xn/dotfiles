-- Readings as the strings a panel row shows them in. Shared by the two
-- menubar widgets, which report different things in the same units and would
-- otherwise each carry their own copy of "bytes in the largest unit they fit".
--
-- Every one of these takes nil and answers with a placeholder rather than
-- erroring: a reading that could not be taken is the normal case for a helper
-- that has not reported yet, and a row showing "--" is more use than a row
-- that is missing.
--
-- Formatting only. What a figure means — its ceiling, its thresholds, whether
-- it is worth colouring — belongs to whoever owns the reading.

local format = {}

-- Shown per figure when a helper is missing or a key stopped resolving.
format.PLACEHOLDER = "--"

local BYTES_PER_KILOBYTE = 1024
local BYTES_PER_MEGABYTE = 1024 * BYTES_PER_KILOBYTE
local BYTES_PER_GIGABYTE = 1024 * BYTES_PER_MEGABYTE

-- Rates are shown as "49 KB/s", the form Stats uses; plain sizes get the
-- one-letter form instead, because they share a column with other readings.
local RATE_UNITS = { "B", "KB", "MB", "GB" }
local SIZE_UNITS = { "B", "K", "M", "G", "T" }
local RATE_SUFFIX = "/s"
local WATTS_SUFFIX = "W"

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

-- Below this a figure earns a decimal, above it the decimal is noise.
local DECIMAL_BELOW = 10

-- Climb the unit ladder until the value fits, and report where it stopped.
local function scaled(value, units)
  local remaining = value
  local unit = 1

  while remaining >= BYTES_PER_KILOBYTE and unit < #units do
    remaining = remaining / BYTES_PER_KILOBYTE
    unit = unit + 1
  end

  return remaining, units[unit], unit
end

-- "45°" for a live reading.
function format.celsius(celsius)
  if celsius == nil then
    return format.PLACEHOLDER .. "°"
  end

  return string.format("%.0f°", celsius)
end

-- "12%" for a live figure.
function format.percent(percent)
  if percent == nil then
    return format.PLACEHOLDER .. "%"
  end

  return string.format("%.0f%%", percent)
end

-- The same figure for a single process, which needs a decimal the machine
-- total does not: an idle desktop is a dozen processes at a fraction of a
-- percent each, and whole numbers render that ranking as a column of zeroes.
function format.processPercent(percent)
  if percent == nil then
    return format.PLACEHOLDER .. "%"
  end

  if percent >= DECIMAL_BELOW then
    return string.format("%.0f%%", percent)
  end

  return string.format("%.1f%%", percent)
end

-- "15GB" — whole gigabytes: the decimal was noise at a glance, and dropping it
-- keeps the column narrow.
function format.gigabytes(bytes)
  if bytes == nil then
    return format.PLACEHOLDER
  end

  return string.format("%.0fGB", bytes / BYTES_PER_GIGABYTE)
end

-- "512M", "3G", "1.2T" — a size in the largest unit it fills, one letter and
-- no space so it stays column-width. The finer units matter because swap turns
-- orange at 200MB, and a warning colour on a figure reading "0G" looks like a
-- bug rather than a warning.
function format.bytes(bytes)
  if bytes == nil then
    return format.PLACEHOLDER
  end

  local value, unit, index = scaled(bytes, SIZE_UNITS)
  local pattern = (value < DECIMAL_BELOW and index > 1) and "%.1f%s" or "%.0f%s"

  return string.format(pattern, value, unit)
end

-- "49 KB/s" — the largest unit the rate fits in, with a decimal only below ten
-- so the column stays narrow while a slow link still shows movement.
function format.rate(bytesPerSecond)
  if bytesPerSecond == nil then
    return format.PLACEHOLDER .. RATE_SUFFIX
  end

  local value, unit, index = scaled(bytesPerSecond, RATE_UNITS)
  local pattern = (value < DECIMAL_BELOW and index > 1) and "%.1f %s" or "%.0f %s"

  return string.format(pattern, value, unit) .. RATE_SUFFIX
end

-- "18.1W" — one decimal, because idle draw moves in tenths and the whole
-- number alone made the column look frozen.
function format.watts(watts)
  if watts == nil then
    return format.PLACEHOLDER .. WATTS_SUFFIX
  end

  return string.format("%.1f" .. WATTS_SUFFIX, watts)
end

-- The same for one process, where the interesting figures are a hundredth of
-- the machine's and one decimal would round most of them to nothing.
function format.processWatts(watts)
  if watts == nil then
    return format.PLACEHOLDER .. " " .. WATTS_SUFFIX
  end

  return string.format("%.2f " .. WATTS_SUFFIX, watts)
end

-- "3d 4h", "4h 12m", "12m" — two units, because the third never changes what
-- the first two already said.
function format.uptime(seconds)
  if seconds == nil then
    return format.PLACEHOLDER
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
function format.loadAverages(averages, separator)
  if averages == nil or #averages == 0 then
    return format.PLACEHOLDER
  end

  local windows = {}

  for index, average in ipairs(averages) do
    windows[index] = string.format("%.2f", average)
  end

  return table.concat(windows, separator)
end

-- A name that fits the label column. An Electron helper runs past the figure
-- it shares a line with otherwise.
function format.shortened(name, limit)
  if name == nil then
    return format.PLACEHOLDER
  end

  if #name <= limit then
    return name
  end

  return name:sub(1, limit - 1) .. "…"
end

return format
