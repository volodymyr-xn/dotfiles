-- RSS sampler, lualine accessors, and the 24h sparkline ring buffer.

local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn
local shared = require("my_plugins.memory_cleaner.shared")

local M = {}

-- ============================================================================
-- RSS sampler
-- ============================================================================

-- Read process RSS via `ps -o rss=` (Darwin/Linux) with /proc fallback for self.
local function read_rss_kb_for_pid(pid)
  local ok_ps, ps_out = pcall(fn.system, { "ps", "-o", "rss=", "-p", tostring(pid) })

  if ok_ps and ps_out then
    local num = tonumber((ps_out:gsub("%s+", "")))

    if num and num > 0 then
      return num
    end
  end

  if pid == fn.getpid() then
    local f = io.open("/proc/self/statm", "r")

    if f then
      local statm = f:read("*l")
      f:close()
      local rss_pages = tonumber((statm or ""):match("%S+%s+(%S+)"))

      if rss_pages then
        local page_kb = 4 -- standard 4KB page on Linux
        return rss_pages * page_kb
      end
    end
  end

  return nil
end

-- Current process RSS in MB or nil on failure; cached for config.rss_cache_seconds.
function M.rss_mb()
  local now = os.time()
  local cache = shared.rss_cache

  if cache.value ~= nil and (now - cache.at) < shared.config.rss_cache_seconds then
    return cache.value
  end

  local kb = read_rss_kb_for_pid(fn.getpid())
  local mb = kb and math.floor(kb / 1024) or nil
  cache.value = mb
  cache.at = now

  return mb
end

-- RSS in MB for an arbitrary pid; uncached, used by the dashboard.
function M.rss_mb_for(pid)
  local kb = read_rss_kb_for_pid(pid)

  return kb and math.floor(kb / 1024) or nil
end

-- Process start time as a human-readable string ("uptime"); macOS lstart / Linux etime.
function M.lstart_for(pid)
  local ok, out = pcall(fn.system, { "ps", "-o", "lstart=", "-p", tostring(pid) })

  if ok and out then
    out = out:gsub("^%s+", ""):gsub("%s+$", "")

    if out ~= "" then
      return out
    end
  end

  return "?"
end

-- ============================================================================
-- Lualine stats
-- ============================================================================

-- Loaded-buffer + live-parser counts (cheap; lualine calls this often).
function M.stats()
  local loaded = 0
  local parsers = 0

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      loaded = loaded + 1

      if pcall(vim.treesitter.get_parser, buf) then
        parsers = parsers + 1
      end
    end
  end

  return { loaded = loaded, parsers = parsers, rss_mb = M.rss_mb() }
end

-- Statusline string with nerd-font glyphs; `MEM_MANAGER_NO_NERD=1` for fallback.
function M.stats_string()
  local s = M.stats()
  local i = shared.config.icons
  local rss = s.rss_mb and (s.rss_mb .. "M") or "?M"

  if vim.env.MEM_MANAGER_NO_NERD == "1" then
    return string.format("B:%d · T:%d · M:%s", s.loaded, s.parsers, rss)
  end

  return string.format("%s %d · %s %d · %s %s", i.buffer, s.loaded, i.parser, s.parsers, i.memory, rss)
end

-- ============================================================================
-- RSS history sampler (appendix: sparkline)
-- ============================================================================

-- Load persisted ring buffer from disk at setup time; silent on missing/bad file.
function M.load_history()
  local f = io.open(shared.config.rss_history_path, "r")

  if not f then
    return
  end

  local raw = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.json.decode, raw)

  if ok and type(decoded) == "table" then
    shared.rss_history = decoded
  end
end

-- Persist the ring buffer; silent on failure (cache, not source of truth).
local function save_history()
  local dir = vim.fs.dirname(shared.config.rss_history_path)
  pcall(fn.mkdir, dir, "p")
  local f = io.open(shared.config.rss_history_path, "w")

  if not f then
    return
  end

  f:write(vim.json.encode(shared.rss_history))
  f:close()
end

-- Push current RSS into the ring buffer (called by the 20-min timer).
function M.sample_history()
  local mb = M.rss_mb()

  if not mb then
    return
  end

  table.insert(shared.rss_history, mb)

  while #shared.rss_history > shared.config.rss_history_max do
    table.remove(shared.rss_history, 1)
  end

  save_history()
end

-- Render the unicode sparkline from current history (relative min/max).
function M.render_sparkline()
  local hist = shared.rss_history

  if #hist < 2 then
    return ""
  end

  local chars = shared.config.icons.spark
  local mn, mx = math.huge, -math.huge

  for _, v in ipairs(hist) do
    if v < mn then mn = v end
    if v > mx then mx = v end
  end

  local range = math.max(1, mx - mn)
  local out = {}

  for _, v in ipairs(hist) do
    local idx = math.floor(((v - mn) / range) * (#chars - 1)) + 1
    out[#out + 1] = chars[idx]
  end

  return table.concat(out)
end

return M
