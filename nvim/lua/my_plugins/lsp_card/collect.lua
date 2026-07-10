-- Data collection for the LSP / treesitter card: one snapshot of every
-- language server, every treesitter parser, and the diagnostics attached to
-- each buffer in this nvim.

local api = vim.api
local fn = vim.fn
local rpc = require("my_plugins.memory_manager.rpc")

local M = {}

local SEVERITY_ORDER = {
  vim.diagnostic.severity.ERROR,
  vim.diagnostic.severity.WARN,
  vim.diagnostic.severity.INFO,
  vim.diagnostic.severity.HINT,
}

-- Diagnostic counts for one buffer (or the whole session when bufnr is nil),
-- returned as `{ error, warn, info, hint, total }`.
local function diagnostic_counts(bufnr)
  local counts = { 0, 0, 0, 0, total = 0 }

  for index, severity in ipairs(SEVERITY_ORDER) do
    local items = vim.diagnostic.get(bufnr, { severity = severity })
    counts[index] = #items
    counts.total = counts.total + #items
  end

  return counts
end
M.diagnostic_counts = diagnostic_counts

-- Source bytes of a buffer; the treesitter memory estimate is derived from it.
local function buf_bytes(bufnr)
  local ok, bytes = pcall(api.nvim_buf_call, bufnr, function()
    return fn.wordcount().bytes
  end)

  return (ok and bytes) or 0
end

-- Treesitter state for one buffer: whether a highlighter is active, the
-- parser's language, the injected languages, and a rough memory estimate
-- (source bytes × 3, the same heuristic the memory dashboard uses).
local function treesitter_info(bufnr)
  local active = (vim.treesitter.highlighter and vim.treesitter.highlighter.active) or {}

  if not active[bufnr] then
    return nil
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)

  if not ok or not parser then
    return nil
  end

  local languages = {}

  for lang in pairs(parser:children()) do
    table.insert(languages, lang)
  end

  table.sort(languages)
  local bytes = buf_bytes(bufnr)

  return {
    lang = parser:lang(),
    injections = languages,
    bytes = bytes,
    est_kb = math.floor(bytes * 3 / 1024),
  }
end

-- Path of the LSP log file. `vim.lsp.get_log_path()` is deprecated in recent
-- nvim, so prefer the log module and fall back to the stdpath location.
local function lsp_log_path()
  local ok, log = pcall(require, "vim.lsp.log")

  if ok and log.get_filename then
    return log.get_filename()
  end

  return fn.stdpath("state") .. "/lsp.log"
end

-- Servers lspconfig knows about, for the ":LspInfo"-style trailing line.
-- Returns an empty list when lspconfig isn't installed.
local function configured_servers()
  local ok, util = pcall(require, "lspconfig.util")

  if not ok or not util.available_servers then
    return {}
  end

  local ok_list, servers = pcall(util.available_servers)

  if not ok_list or type(servers) ~= "table" then
    return {}
  end

  table.sort(servers)

  return servers
end

-- Language servers running in this nvim, enriched with the real RSS of their
-- child processes (matched by name against `pgrep -P <nvim pid>`).
local function collect_clients(attached_to)
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local procs = rpc.lsp_processes_for(fn.getpid())
  local rss_by_name = {}

  for _, item in ipairs(procs.items) do
    rss_by_name[item.name] = (rss_by_name[item.name] or 0) + item.kb
  end

  local clients = {}

  for _, client in ipairs(get_clients()) do
    local buffers = vim.lsp.get_buffers_by_client_id(client.id)
    -- Server binaries rarely match the client name exactly (client "lua_ls"
    -- runs the binary "lua-language-server"), so fall back to a fuzzy match
    -- on the normalized name before giving up on the RSS column.
    local normalized = client.name:gsub("[_%-]", "")
    local rss_kb = rss_by_name[client.name]

    if not rss_kb then
      for name, kb in pairs(rss_by_name) do
        if name:gsub("[_%-]", ""):lower():find(normalized:lower(), 1, true) then
          rss_kb = kb
          break
        end
      end
    end

    local config = client.config or {}
    local cmd = config.cmd

    if type(cmd) == "table" then
      cmd = table.concat(cmd, " ")
    end

    table.sort(buffers)

    table.insert(clients, {
      id = client.id,
      name = client.name,
      root_dir = client.root_dir or config.root_dir or "",
      cmd = type(cmd) == "string" and cmd or "cmd not defined",
      autostart = config.autostart ~= false,
      filetypes = config.filetypes or {},
      buffer_numbers = buffers,
      buffers = #buffers,
      rss_kb = rss_kb,
      stopped = client.is_stopped and client:is_stopped() or false,
      attached = vim.tbl_contains(buffers, attached_to or -1),
    })
  end

  table.sort(clients, function(a, b)
    return (a.rss_kb or 0) > (b.rss_kb or 0)
  end)

  return clients, procs.total_kb
end

-- Every listed/loaded buffer with its servers, parser, and diagnostics.
-- `current` is the buffer the user was in when the card opened (the card's
-- own scratch buffer is passed as `exclude` so it never lists itself).
local function collect_buffers(current, exclude)
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local buffers = {}

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if bufnr ~= exclude
      and api.nvim_buf_is_valid(bufnr)
      and (fn.buflisted(bufnr) == 1 or api.nvim_buf_is_loaded(bufnr)) then
      local names = {}

      for _, client in ipairs(get_clients({ bufnr = bufnr })) do
        table.insert(names, client.name)
      end

      table.sort(names)
      local name = api.nvim_buf_get_name(bufnr)

      table.insert(buffers, {
        bufnr = bufnr,
        name = (name ~= "" and name) or ("[No Name " .. bufnr .. "]"),
        filetype = vim.bo[bufnr].filetype,
        loaded = api.nvim_buf_is_loaded(bufnr),
        is_current = bufnr == current,
        clients = names,
        treesitter = api.nvim_buf_is_loaded(bufnr) and treesitter_info(bufnr) or nil,
        diagnostics = diagnostic_counts(bufnr),
      })
    end
  end

  table.sort(buffers, function(a, b)
    if a.is_current ~= b.is_current then
      return a.is_current
    end

    if a.diagnostics.total ~= b.diagnostics.total then
      return a.diagnostics.total > b.diagnostics.total
    end

    return a.bufnr < b.bufnr
  end)

  return buffers
end

-- Whole snapshot consumed by the renderer.
function M.snapshot(opts)
  opts = opts or {}
  local clients, lsp_rss_kb = collect_clients(opts.current_buf)
  local buffers = collect_buffers(opts.current_buf, opts.exclude_buf)
  local parser_count = 0
  local parser_est_kb = 0
  local languages = {}

  for _, buffer in ipairs(buffers) do
    local ts = buffer.treesitter

    if ts then
      parser_count = parser_count + 1
      parser_est_kb = parser_est_kb + ts.est_kb
      languages[ts.lang] = true

      for _, lang in ipairs(ts.injections) do
        languages[lang] = true
      end
    end
  end

  local language_list = {}

  for lang in pairs(languages) do
    table.insert(language_list, lang)
  end

  table.sort(language_list)

  local origin = opts.current_buf
  local origin_valid = origin and api.nvim_buf_is_valid(origin)

  return {
    clients = clients,
    buffers = buffers,
    lsp_rss_kb = lsp_rss_kb,
    parser_count = parser_count,
    parser_est_kb = parser_est_kb,
    languages = language_list,
    diagnostics = diagnostic_counts(nil),
    buffer_diagnostics = origin_valid and diagnostic_counts(origin)
      or { 0, 0, 0, 0, total = 0 },
    log_path = lsp_log_path(),
    filetype = origin_valid and vim.bo[origin].filetype or "",
    configured_servers = configured_servers(),
  }
end

return M
