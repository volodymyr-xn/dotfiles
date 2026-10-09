-- What a launchd job definition says about when it runs: the moment it next
-- fires, and the triggers behind that as short phrases ("Hourly at :00",
-- "At load") or, for a weekly calendar, as the set of weekdays and times it
-- fires at.
--
-- Pure functions of a definition (an hs.plist.read table) and a timestamp,
-- with nothing read from the system, so every rule here can be checked from
-- `hs -c` against a fixed moment rather than whatever today happens to be.
--
-- Calendar rules follow launchd.plist(5): a key missing from a
-- StartCalendarInterval entry means "every", Weekday 0 and 7 are both Sunday,
-- and Day with Weekday fires when either one matches.

local M = {}

-- How far ahead a calendar entry is searched for its next firing. Four years
-- covers the rarest date launchd can be given, the 29th of February.
local LOOKAHEAD_DAYS = 4 * 366

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE

local WEEKDAY_NAMES = { [0] = "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTH_NAMES = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}

-- Monday-first slot (1..7) of a launchd weekday, so Sunday lands last
-- whether it was written as 0 or 7.
function M.weekdaySlot(weekday)
  return (weekday % 7 + 6) % 7 + 1
end

-- StartCalendarInterval as a list of entries: launchd takes one dict or an
-- array of them.
function M.calendarEntries(definition)
  local interval = definition.StartCalendarInterval

  if interval == nil then
    return {}
  end

  if interval[1] == nil then
    return { interval }
  end

  return interval
end

-- Whether an entry fires on `date`, an os.date("*t") table.
local function firesOnDay(entry, date)
  if entry.Month ~= nil and entry.Month ~= date.month then
    return false
  end

  local dayMatches = entry.Day == date.day
  local weekdayMatches = entry.Weekday ~= nil
    and entry.Weekday % 7 == date.wday - 1

  if entry.Day ~= nil and entry.Weekday ~= nil then
    return dayMatches or weekdayMatches
  end

  return (entry.Day == nil or dayMatches)
    and (entry.Weekday == nil or weekdayMatches)
end

-- The hours or minutes an entry fires at: the one it names, or every value
-- from 0 to `last`.
local function candidateValues(value, last)
  if value ~= nil then
    return { value }
  end

  local values = {}

  for candidate = 0, last do
    values[#values + 1] = candidate
  end

  return values
end

-- The first of the day's candidate times that is still ahead of `now`.
local function firstFiringOnDay(date, hours, minutes, now)
  for _, hour in ipairs(hours) do
    for _, minute in ipairs(minutes) do
      local firing = os.time({
        year = date.year,
        month = date.month,
        day = date.day,
        hour = hour,
        min = minute,
        sec = 0,
      })

      if firing > now then
        return firing
      end
    end
  end

  return nil
end

-- The first moment after `now` an entry fires, walking forward a day at a
-- time rather than a minute at a time. nil when nothing matches within
-- LOOKAHEAD_DAYS.
function M.nextFiring(entry, now)
  local today = os.date("*t", now)
  local hours = candidateValues(entry.Hour, 23)
  local minutes = candidateValues(entry.Minute, 59)

  for offset = 0, LOOKAHEAD_DAYS do
    -- Noon, so a daylight-saving shift cannot tip the day into its neighbour.
    local date = os.date("*t", os.time({
      year = today.year,
      month = today.month,
      day = today.day + offset,
      hour = 12,
    }))

    if firesOnDay(entry, date) then
      local firing = firstFiringOnDay(date, hours, minutes, now)

      if firing ~= nil then
        return firing
      end
    end
  end

  return nil
end

-- The job's next start: the earliest calendar firing, or a StartInterval
-- counted on from the last run. nil when nothing time-based starts it.
function M.nextRun(definition, lastRunAt, now)
  local earliest = nil

  for _, entry in ipairs(M.calendarEntries(definition)) do
    local firing = M.nextFiring(entry, now)

    if firing ~= nil and (earliest == nil or firing < earliest) then
      earliest = firing
    end
  end

  local interval = definition.StartInterval

  if interval ~= nil and lastRunAt ~= nil then
    local firing = lastRunAt + interval

    if firing > now and (earliest == nil or firing < earliest) then
      earliest = firing
    end
  end

  return earliest
end

-- When in the day an entry fires.
local function entryTime(entry)
  if entry.Hour ~= nil and entry.Minute ~= nil then
    return string.format("at %02d:%02d", entry.Hour, entry.Minute)
  end

  if entry.Hour ~= nil then
    return string.format("every minute from %02d:00 to %02d:59",
      entry.Hour, entry.Hour)
  end

  if entry.Minute ~= nil then
    return string.format("hourly at :%02d", entry.Minute)
  end

  return "every minute"
end

-- Which days an entry fires on, or nil for every day.
local function entryDays(entry)
  local weekday = entry.Weekday ~= nil and WEEKDAY_NAMES[entry.Weekday % 7]
    or nil
  local monthDay = entry.Day ~= nil and ("day " .. entry.Day) or nil
  local days = weekday or monthDay

  if weekday ~= nil and monthDay ~= nil then
    days = monthDay .. " or " .. weekday
  end

  if entry.Month ~= nil then
    days = (days or "day") .. " in " .. MONTH_NAMES[entry.Month]
  end

  return days
end

-- One group of entries sharing a time, as a phrase: "Daily at 21:10",
-- "Hourly at :00", "Every Mon, Wed, Fri at 10:00".
local function cadencePhrase(group)
  if group.everyDay then
    if group.isClockTime then
      return "Daily " .. group.time
    end

    return group.time:sub(1, 1):upper() .. group.time:sub(2)
  end

  local joiner = group.isClockTime and " " or ", "

  return "Every " .. table.concat(group.days, ", ") .. joiner .. group.time
end

-- How often a calendar schedule fires. Entries that share a time fold into
-- one phrase, since launchd needs an entry per weekday for "Mon, Wed, Fri".
local function calendarCadence(entries)
  local groups = {}
  local ordered = {}

  for _, entry in ipairs(entries) do
    local time = entryTime(entry)
    local group = groups[time]

    if group == nil then
      group = {
        time = time,
        isClockTime = entry.Hour ~= nil and entry.Minute ~= nil,
        days = {},
        everyDay = false,
      }
      groups[time] = group
      ordered[#ordered + 1] = group
    end

    local days = entryDays(entry)

    if days == nil then
      group.everyDay = true
    else
      group.days[#group.days + 1] = days
    end
  end

  local phrases = {}

  for _, group in ipairs(ordered) do
    phrases[#phrases + 1] = cadencePhrase(group)
  end

  return table.concat(phrases, "; ")
end

-- StartInterval in the largest unit that divides it evenly.
local function intervalCadence(seconds)
  if seconds % SECONDS_PER_HOUR == 0 then
    return string.format("Every %dh", seconds // SECONDS_PER_HOUR)
  end

  if seconds % SECONDS_PER_MINUTE == 0 then
    return string.format("Every %dm", seconds // SECONDS_PER_MINUTE)
  end

  return string.format("Every %ds", seconds)
end

-- Every trigger besides the calendar, as phrases.
local function otherTriggers(definition)
  local triggers = {}

  if definition.StartInterval ~= nil then
    triggers[#triggers + 1] = intervalCadence(definition.StartInterval)
  end

  if definition.WatchPaths ~= nil then
    triggers[#triggers + 1] = "When a watched path changes"
  end

  if definition.QueueDirectories ~= nil then
    triggers[#triggers + 1] = "When a queue directory fills"
  end

  if definition.StartOnMount then
    triggers[#triggers + 1] = "On volume mount"
  end

  if definition.KeepAlive then
    triggers[#triggers + 1] = "Kept alive"
  end

  if definition.RunAtLoad then
    triggers[#triggers + 1] = "At load"
  end

  return triggers
end

-- The weekdays (Monday-first slots set to true) and clock times of a
-- calendar made only of weekday-and-time entries — the shape a weekday strip
-- can draw. nil for anything else: hourly, daily, monthly, or mixed.
local function weeklyPlan(entries)
  if #entries == 0 then
    return nil
  end

  local weekdays = {}
  local times = {}
  local seenTimes = {}

  for _, entry in ipairs(entries) do
    if entry.Weekday == nil or entry.Hour == nil or entry.Minute == nil
      or entry.Day ~= nil or entry.Month ~= nil then
      return nil
    end

    local time = string.format("%02d:%02d", entry.Hour, entry.Minute)

    weekdays[M.weekdaySlot(entry.Weekday)] = true

    if not seenTimes[time] then
      seenTimes[time] = true
      times[#times + 1] = time
    end
  end

  return { weekdays = weekdays, times = times }
end

-- Everything that starts the job:
--   calendar  the calendar as one phrase, nil without one
--   weekly    { weekdays, times } when the calendar is weekday-and-time only
--   others    the remaining triggers as phrases
function M.schedule(definition)
  local entries = M.calendarEntries(definition)

  return {
    calendar = #entries > 0 and calendarCadence(entries) or nil,
    weekly = weeklyPlan(entries),
    others = otherTriggers(definition),
  }
end

-- The whole schedule on one line, joined by `separator`; "On demand" when
-- nothing starts the job by itself.
function M.cadence(definition, separator)
  local schedule = M.schedule(definition)
  local phrases = { schedule.calendar }

  for _, trigger in ipairs(schedule.others) do
    phrases[#phrases + 1] = trigger
  end

  if #phrases == 0 then
    return "On demand"
  end

  return table.concat(phrases, separator)
end

return M
