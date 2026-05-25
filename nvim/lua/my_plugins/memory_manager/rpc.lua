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
-- luaeval() sees it as a single expression. Returns a JSON string carrying
-- buffer/parser counts plus extras for the dashboard sub-row (LSP names,
-- Lua heap, treesitter language list + byte estimate, fugitive count + bytes).
-- Parser detection uses `highlighter.active[buf]` (matches what
-- :MemClearTreesitter would actually stop) instead of `pcall(get_parser)`,
-- which falsely counts custom buftypes that have no registered grammar.
-- ts_bytes counts source-text bytes of buffers with an active parser; the
-- dashboard renders ts_bytes × 3 as a rough parser-tree memory estimate.
local REMOTE_SNAPSHOT_EXPR = [[luaeval("(function() local p=0 local langs={} local ts_bytes=0 local fug_count=0 local fug_bytes=0 local ts=(vim.treesitter.highlighter and vim.treesitter.highlighter.active) or {} for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_valid(b) then local loaded=vim.api.nvim_buf_is_loaded(b) local ft=loaded and vim.bo[b].filetype or '' local name=vim.api.nvim_buf_get_name(b) or '' local is_fug=(ft:match('^fugitive') or name:match('^fugitive://') or name:match('fugitiveblame')) and true or false if is_fug then fug_count=fug_count+1 end if loaded and ts[b] then p=p+1 if ft and ft~='' then langs[ft]=true end end if loaded and (ts[b] or is_fug) then local ok,info=pcall(vim.api.nvim_buf_call,b,function() return vim.fn.wordcount().bytes end) if ok and info then if ts[b] then ts_bytes=ts_bytes+info end if is_fug then fug_bytes=fug_bytes+info end end end end end local langs_list={} for k in pairs(langs) do table.insert(langs_list,k) end table.sort(langs_list) local lsp_names={} local gc=vim.lsp.get_clients or vim.lsp.get_active_clients for _,c in ipairs(gc()) do table.insert(lsp_names,c.name) end table.sort(lsp_names) return vim.fn.json_encode({cwd=vim.fn.getcwd(),bufs=vim.fn.getbufinfo(),parsers=p,ts_langs=langs_list,ts_bytes=ts_bytes,fug_count=fug_count,fug_bytes=fug_bytes,lsp_names=lsp_names,lua_heap_kb=math.floor(collectgarbage('count'))}) end)()")]]

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

-- LSP servers we recognize by binary/comm name. The matcher is forgiving:
-- it accepts the full name OR a prefix. Add new servers freely — anything
-- not on the list still shows up in the "other" bucket when its name
-- contains "language-server".
local LSP_SERVER_HINTS = {
  "language%-server",
  "tsserver",
  "typescript%-language",
  "pyright",
  "pylsp",
  "ruby%-lsp",
  "solargraph",
  "lua%-language%-server",
  "lua%-ls",
  "rust%-analyzer",
  "gopls",
  "clangd",
  "eslint",
  "stylelint",
  "vscode%-",
}

local function looks_like_lsp(comm)
  if not comm or comm == "" then return false end
  for _, pat in ipairs(LSP_SERVER_HINTS) do
    if comm:lower():match(pat) then return true end
  end
  return false
end

-- Scan a full `ps args` line and return a short display name iff any token
-- in the command line looks like an LSP server binary. Examples:
--   "node /…/mason/bin/vscode-json-language-server --stdio"
--     → "vscode-json-language-server"
--   "/…/lua-language-server -E /…/main.lua"
--     → "lua-language-server"
-- Returns nil when nothing matches (the process is some other nvim child).
local function lsp_name_from_args(args_line)
  for word in args_line:gmatch("(%S+)") do
    local basename = word:match("([^/]+)$") or word

    if looks_like_lsp(basename) then
      return basename
    end
  end

  return nil
end

-- Enumerate child processes of `pid` that look like LSP servers, returning
-- `{ items = {{pid=, kb=, name=}, ...}, total_kb = N }`. Names come from the
-- full ps args (not comm) because language servers are typically launched
-- via `node /path/to/<server>` and would otherwise all show as "node".
local function lsp_processes_for(pid)
  -- macOS pgrep requires a pattern arg; "." matches every command line so
  -- the `-P` filter alone decides what's returned. Works on Linux pgrep too.
  local r = vim.system({ "pgrep", "-P", tostring(pid), "." },
    { text = true, timeout = 500 }):wait()

  if r.code ~= 0 or not r.stdout or r.stdout == "" then
    return { items = {}, total_kb = 0 }
  end

  local pids = {}

  for line in r.stdout:gmatch("[^\n]+") do
    local p = tonumber(line)

    if p then
      table.insert(pids, tostring(p))
    end
  end

  if #pids == 0 then
    return { items = {}, total_kb = 0 }
  end

  local r2 = vim.system({ "ps", "-o", "pid=,rss=,args=", "-p", table.concat(pids, ",") },
    { text = true, timeout = 800 }):wait()

  if r2.code ~= 0 or not r2.stdout then
    return { items = {}, total_kb = 0 }
  end

  local items = {}
  local total_kb = 0

  for line in r2.stdout:gmatch("[^\n]+") do
    local cp, kb, args = line:match("^%s*(%d+)%s+(%d+)%s+(.+)$")

    if cp and kb and args then
      local name = lsp_name_from_args(args)

      if name then
        local kb_n = tonumber(kb)
        table.insert(items, { pid = tonumber(cp), kb = kb_n, name = name })
        total_kb = total_kb + kb_n
      end
    end
  end

  return { items = items, total_kb = total_kb }
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
          is_current = false,
          uptime = stats.lstart_for(pid),
          uptime_seconds = stats.etime_seconds_for(pid),
        })
      end
    end
  end

  local self_pid = fn.getpid()
  table.insert(processes, 1, {
    pid = self_pid, cwd = fn.getcwd(), socket = self_sock,
    is_current = true,
    uptime = stats.lstart_for(self_pid),
    uptime_seconds = stats.etime_seconds_for(self_pid),
  })

  return processes
end

-- Gather LSP names, Lua heap, and distinct treesitter languages for the
-- current process. Mirrors what REMOTE_SNAPSHOT_EXPR collects on remote
-- nvims so the dashboard sub-row renders identically for both.
-- Heuristic: is this buffer a fugitive buffer? Matches blames, fugitive://
-- URIs, and the per-file fugitiveblame swap-buffer naming.
local function is_fugitive_buf(buf)
  local ft = vim.bo[buf].filetype or ""
  local name = api.nvim_buf_get_name(buf) or ""
  return ft:match("^fugitive") ~= nil
    or name:match("^fugitive://") ~= nil
    or name:match("fugitiveblame") ~= nil
end

local function buf_bytes(buf)
  local ok, info = pcall(api.nvim_buf_call, buf, function()
    return fn.wordcount().bytes
  end)
  return (ok and info) or 0
end

local function local_extras()
  local langs_set = {}
  local ts_active = (vim.treesitter.highlighter and vim.treesitter.highlighter.active) or {}
  local ts_bytes = 0
  local fug_count = 0
  local fug_bytes = 0

  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(b) then
      local is_fug = is_fugitive_buf(b)

      if is_fug then
        fug_count = fug_count + 1
      end

      if api.nvim_buf_is_loaded(b) then
        if ts_active[b] then
          local ft = vim.bo[b].filetype

          if ft and ft ~= "" then
            langs_set[ft] = true
          end

          ts_bytes = ts_bytes + buf_bytes(b)
        end

        if is_fug then
          fug_bytes = fug_bytes + buf_bytes(b)
        end
      end
    end
  end

  local ts_langs = {}

  for k in pairs(langs_set) do
    table.insert(ts_langs, k)
  end

  table.sort(ts_langs)

  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local lsp_names = {}

  for _, c in ipairs(get_clients()) do
    table.insert(lsp_names, c.name)
  end

  table.sort(lsp_names)

  return {
    ts_langs = ts_langs,
    ts_bytes = ts_bytes,
    fug_count = fug_count,
    fug_bytes = fug_bytes,
    lsp_names = lsp_names,
    lua_heap_kb = math.floor(collectgarbage("count")),
  }
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
    uptime_seconds = proc.uptime_seconds,
    ts_langs = payload.ts_langs or {},
    ts_bytes = payload.ts_bytes or 0,
    fug_count = payload.fug_count or 0,
    fug_bytes = payload.fug_bytes or 0,
    lsp_names = payload.lsp_names or {},
    lsp_procs = lsp_processes_for(proc.pid),
    lua_heap_kb = payload.lua_heap_kb,
    error = nil,
  }, nil
end

-- Snapshot for one process (local or remote). Timeout-protected for remotes.
function M.stats_remote(proc)
  if proc.is_current then
    local s = stats.stats()
    local extras = local_extras()
    local lsp_procs = lsp_processes_for(fn.getpid())
    return {
      pid = fn.getpid(), cwd = fn.getcwd(), buffers = local_buffers(),
      loaded = s.loaded, parsers = s.parsers, rss_mb = s.rss_mb,
      uptime = proc.uptime, uptime_seconds = proc.uptime_seconds,
      ts_langs = extras.ts_langs,
      ts_bytes = extras.ts_bytes,
      fug_count = extras.fug_count,
      fug_bytes = extras.fug_bytes,
      lsp_names = extras.lsp_names,
      lsp_procs = lsp_procs,
      lua_heap_kb = extras.lua_heap_kb,
      error = nil,
    }
  end

  local out, err = run_remote_expr(proc.socket, REMOTE_SNAPSHOT_EXPR)

  if not out then
    return {
      pid = proc.pid, cwd = proc.cwd, buffers = {},
      loaded = 0, parsers = 0, rss_mb = stats.rss_mb_for(proc.pid),
      uptime = proc.uptime, uptime_seconds = proc.uptime_seconds,
      error = err or "remote unreachable",
    }
  end

  local snap, derr = decode_snapshot(out, proc)

  if not snap then
    return {
      pid = proc.pid, cwd = proc.cwd, buffers = {},
      loaded = 0, parsers = 0, rss_mb = stats.rss_mb_for(proc.pid),
      uptime = proc.uptime, uptime_seconds = proc.uptime_seconds,
      error = derr or "decode failed",
    }
  end

  return snap
end

return M
