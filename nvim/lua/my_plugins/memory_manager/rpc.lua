-- Cross-process discovery + per-process snapshot.
--
-- Uses `vim.system({"nvim", "--server", SOCK, "--remote-expr", ...}, {timeout=…})`
-- instead of `vim.fn.sockconnect`/`vim.rpcrequest`. The previous in-process
-- RPC approach blocked the editor main loop with no timeout when any sibling
-- nvim was wedged. `vim.system` enforces a hard timeout and isolates failure
-- per-process.

local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn
local cleaner_shared = require("my_plugins.memory_cleaner.shared")
local stats = require("my_plugins.memory_cleaner.stats")
local prune = require("my_plugins.memory_cleaner.prune")

local M = {}

local DEFAULT_TIMEOUT_MS = 1500

-- One-line lua snippet to evaluate on a remote nvim. Wrapped in an IIFE so
-- luaeval() sees it as a single expression. Returns a JSON string.
local REMOTE_SNAPSHOT_EXPR = [[luaeval("(function() local p=0 for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_loaded(b) and pcall(vim.treesitter.get_parser,b) then p=p+1 end end return vim.fn.json_encode({cwd=vim.fn.getcwd(),bufs=vim.fn.getbufinfo(),parsers=p}) end)()")]]

-- Run a vim expression on the remote nvim; returns stdout (string) or nil+err.
local function run_remote_expr(socket, expr, timeout_ms)
  local result = vim.system({
    "nvim", "--server", socket, "--remote-expr", expr,
  }, { text = true, timeout = timeout_ms or DEFAULT_TIMEOUT_MS }):wait()

  if result.code ~= 0 then
    local err = result.stderr ~= "" and result.stderr or ("exit " .. tostring(result.code))
    return nil, err
  end

  return (result.stdout or ""):gsub("\n$", ""), nil
end
M.run_remote_expr = run_remote_expr

-- Send an Ex command to the remote nvim (no return value).
function M.remote_exec(socket, cmd)
  -- Vim string literal: escape backslash and double-quote only.
  local escaped = cmd:gsub("\\", "\\\\"):gsub('"', '\\"')
  return run_remote_expr(socket, string.format([[execute("%s")]], escaped))
end

-- Unload (or wipe) a buffer in the remote nvim.
function M.remote_buf_delete(socket, bufnr, opts)
  local force = opts.force and "true" or "false"
  local unload = opts.unload and "true" or "false"
  local expr = string.format(
    [[luaeval("pcall(vim.api.nvim_buf_delete, %d, {force=%s, unload=%s})")]],
    bufnr, force, unload)

  return run_remote_expr(socket, expr, 2000)
end

-- Best-effort cwd lookup for a foreign pid (no RPC; works on stuck nvims too).
local function pid_cwd(pid)
  if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
    local r = vim.system({ "lsof", "-a", "-p", tostring(pid), "-d", "cwd", "-Fn" },
      { text = true, timeout = 800 }):wait()

    if r.code == 0 and r.stdout then
      for line in r.stdout:gmatch("[^\n]+") do
        if line:sub(1, 1) == "n" then
          return line:sub(2)
        end
      end
    end

    return "?"
  end

  local r = vim.system({ "readlink", "/proc/" .. tostring(pid) .. "/cwd" },
    { text = true, timeout = 500 }):wait()

  if r.code == 0 and r.stdout and r.stdout ~= "" then
    return (r.stdout:gsub("\n$", ""))
  end

  return "?"
end

-- True when the pid is still alive.
local function pid_alive(pid)
  local r = vim.system({ "kill", "-0", tostring(pid) },
    { text = true, timeout = 300 }):wait()

  return r.code == 0
end

-- Glob sibling sockets; parse pid from filename; cwd via lsof / proc.
function M.discover_processes()
  local tmp = vim.env.TMPDIR or "/tmp/"

  if not tmp:match("/$") then
    tmp = tmp .. "/"
  end

  local user = vim.env.USER or ""
  local pattern = tmp .. "nvim." .. user .. "/*/nvim.*.0"
  local paths = fn.glob(pattern, false, true) or {}
  local processes = {}
  local self_sock = vim.v.servername or ""

  for _, path in ipairs(paths) do
    if path ~= self_sock then
      local pid = tonumber(path:match("nvim%.(%d+)%.0$"))

      if pid and pid_alive(pid) then
        table.insert(processes, {
          pid = pid, cwd = pid_cwd(pid), socket = path,
          is_current = false, uptime = stats.lstart_for(pid),
        })
      end
    end
  end

  table.insert(processes, 1, {
    pid = fn.getpid(), cwd = fn.getcwd(), socket = self_sock,
    is_current = true, uptime = stats.lstart_for(fn.getpid()),
  })

  return processes
end

-- Local buffer snapshot (no RPC).
local function local_buffers()
  local bufs = {}
  local now_seconds = uv.hrtime() / 1e9

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if fn.buflisted(buf) == 1 or api.nvim_buf_is_loaded(buf) then
      local name = api.nvim_buf_get_name(buf)
      local has_parser = pcall(vim.treesitter.get_parser, buf)
      local last = cleaner_shared.last_left_at[buf]
      local idle_min = last and math.max(0, math.floor((now_seconds - last) / 60)) or 0
      table.insert(bufs, {
        bufnr = buf,
        name = (name ~= "" and name) or ("[No Name " .. buf .. "]"),
        loaded = api.nvim_buf_is_loaded(buf),
        modified = vim.bo[buf].modified,
        visible = fn.bufwinid(buf) ~= -1,
        buftype = vim.bo[buf].buftype,
        filetype = vim.bo[buf].filetype,
        line_count = api.nvim_buf_is_loaded(buf) and api.nvim_buf_line_count(buf) or 0,
        parser = has_parser,
        idle_min = idle_min,
        est_kb = prune.estimate_buf_kb(buf),
      })
    end
  end

  return bufs
end

-- Decode the remote snapshot JSON into the shared view-model shape.
local function decode_snapshot(json_str, proc)
  local ok, payload = pcall(vim.json.decode, json_str)

  if not ok or type(payload) ~= "table" then
    return nil, "invalid JSON from remote"
  end

  local bufs = {}
  local loaded_count = 0

  for _, b in ipairs(payload.bufs or {}) do
    local is_loaded = b.loaded == 1 or b.loaded == true

    if is_loaded then
      loaded_count = loaded_count + 1
    end

    local visible = false

    if type(b.windows) == "table" then
      visible = #b.windows > 0
    end

    table.insert(bufs, {
      bufnr = b.bufnr,
      name = (b.name ~= "" and b.name) or ("[No Name " .. b.bufnr .. "]"),
      loaded = is_loaded,
      modified = b.changed == 1 or b.changed == true,
      visible = visible,
      buftype = "",
      filetype = "",
      line_count = b.linecount or 0,
      parser = false,
      idle_min = 0,
      est_kb = math.floor((b.linecount or 0) * 60 / 1024),
    })
  end

  return {
    pid = proc.pid,
    cwd = payload.cwd or proc.cwd,
    buffers = bufs,
    loaded = loaded_count,
    parsers = payload.parsers or 0,
    rss_mb = stats.rss_mb_for(proc.pid),
    uptime = proc.uptime,
    error = nil,
  }, nil
end

-- Snapshot for one process (local or remote). Timeout-protected for remotes.
function M.stats_remote(proc)
  if proc.is_current then
    local s = stats.stats()
    return {
      pid = fn.getpid(), cwd = fn.getcwd(), buffers = local_buffers(),
      loaded = s.loaded, parsers = s.parsers, rss_mb = s.rss_mb,
      uptime = proc.uptime, error = nil,
    }
  end

  local out, err = run_remote_expr(proc.socket, REMOTE_SNAPSHOT_EXPR)

  if not out then
    return {
      pid = proc.pid, cwd = proc.cwd, buffers = {},
      loaded = 0, parsers = 0, rss_mb = stats.rss_mb_for(proc.pid),
      uptime = proc.uptime, error = err or "remote unreachable",
    }
  end

  local snap, derr = decode_snapshot(out, proc)

  if not snap then
    return {
      pid = proc.pid, cwd = proc.cwd, buffers = {},
      loaded = 0, parsers = 0, rss_mb = stats.rss_mb_for(proc.pid),
      uptime = proc.uptime, error = derr or "decode failed",
    }
  end

  return snap
end

return M
