-- Shared helpers used across my_plugins/*. Pure functions, no side effects.

local M = {}

-- Format a KB count as a compact human-readable size:
-- "892 KB", "8.7 MB", "1.2 GB". Treats nil as 0.
function M.fmt_kb(kb)
  kb = kb or 0

  if kb < 1024 then
    return string.format("%d KB", kb)
  end

  local mb = kb / 1024

  if mb < 1024 then
    return string.format("%.1f MB", mb)
  end

  return string.format("%.1f GB", mb / 1024)
end

-- Format an MB count via fmt_kb so units roll up to GB when warranted.
-- Returns nil when mb is nil so callers can fall back to a placeholder.
function M.fmt_mb(mb)
  if mb == nil then
    return nil
  end

  return M.fmt_kb(mb * 1024)
end

-- Render a duration in seconds as a compact human-readable "X ago" string.
-- Examples: "12 seconds ago", "5 minutes ago", "3 hours ago", "1 day 12 hours ago".
-- Returns nil when seconds is nil so callers can fall back to a placeholder.
function M.fmt_uptime(seconds)
  if seconds == nil then
    return nil
  end

  if seconds < 60 then
    return string.format("%d seconds ago", seconds)
  end

  if seconds < 3600 then
    return string.format("%d minutes ago", math.floor(seconds / 60))
  end

  if seconds < 86400 then
    return string.format("%d hours ago", math.floor(seconds / 3600))
  end

  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)

  if hours == 0 then
    return string.format("%d day%s ago", days, days == 1 and "" or "s")
  end

  return string.format("%d day%s %d hour%s ago",
    days, days == 1 and "" or "s",
    hours, hours == 1 and "" or "s")
end

return M
