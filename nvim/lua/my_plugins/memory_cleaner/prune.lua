-- Idle-buffer prune pass + LSP auto-stop + per-buffer reclaim estimate.

local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn
local shared = require("my_plugins.memory_cleaner.shared")

local M = {}

-- True when a buffer must never be auto-unloaded (visible, modified, special).
function M.is_exempt(buf)
  if not api.nvim_buf_is_valid(buf) then
    return true
  end

  if fn.bufwinid(buf) ~= -1 then
    return true
  end

  if vim.bo[buf].modified then
    return true
  end

  if vim.bo[buf].buftype ~= "" then
    return true
  end

  return false
end

-- Stop LSP clients whose last attached buffer just went away (appendix).
-- Returns the number of clients actually stopped.
local function stop_orphan_lsp_clients()
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local clients = get_clients()
  local allow = {}
  local stopped = 0

  for _, name in ipairs(shared.config.lsp_clients_never_auto_stop) do
    allow[name] = true
  end

  for _, client in ipairs(clients) do
    if not allow[client.name] then
      local bufs = vim.lsp.get_buffers_by_client_id(client.id)

      if #bufs == 0 then
        local ok = pcall(vim.lsp.stop_client, client.id)

        if ok then
          stopped = stopped + 1
        end
      end
    end
  end

  return stopped
end

-- Unload all non-exempt buffers idle for >= force_minutes (0 = ignore idle).
-- Returns `{ unloaded, parsers_stopped, lsp_stopped, freed_kb,
-- threshold_minutes }` so callers can surface a per-category "what got
-- reclaimed" message.
function M.prune(opts)
  opts = opts or {}
  local threshold_minutes = opts.force_minutes
    or shared.config.unload_buffer_after_idle_minutes
  local now_seconds = uv.hrtime() / 1e9
  local unloaded = 0
  local parsers_stopped = 0
  local freed_kb = 0
  -- Snapshot active treesitter highlighters so we can count parsers that
  -- actually existed *before* the unload (post-unload the registry is empty).
  local ts_active = (vim.treesitter.highlighter and vim.treesitter.highlighter.active) or {}

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if not M.is_exempt(buf) then
      local last = shared.last_left_at[buf] or now_seconds
      local idle_seconds = now_seconds - last

      if threshold_minutes == 0 or idle_seconds >= (threshold_minutes * 60) then
        -- Estimate reclaimable bytes BEFORE unload (after unload the buffer
        -- text is gone and our estimator returns 0).
        local est_kb = M.estimate_buf_kb(buf)
        local had_parser = ts_active[buf] ~= nil
        pcall(vim.treesitter.stop, buf)
        local ok = pcall(api.nvim_buf_delete, buf, { unload = true })

        if ok then
          shared.last_left_at[buf] = nil
          shared.buf_bytes_cache[buf] = nil
          unloaded = unloaded + 1
          freed_kb = freed_kb + est_kb

          if had_parser then
            parsers_stopped = parsers_stopped + 1
          end
        end
      end
    end
  end

  local lsp_stopped = stop_orphan_lsp_clients()

  return {
    unloaded = unloaded,
    parsers_stopped = parsers_stopped,
    lsp_stopped = lsp_stopped,
    freed_kb = freed_kb,
    threshold_minutes = threshold_minutes,
  }
end

-- Estimated KB reclaimable if this buffer is unloaded (text + parser).
function M.estimate_buf_kb(buf)
  if not api.nvim_buf_is_loaded(buf) then
    return 0
  end

  local bytes = shared.buf_bytes_cache[buf]

  if not bytes then
    local ok, info = pcall(api.nvim_buf_call, buf, function()
      return fn.wordcount().bytes
    end)
    bytes = (ok and info) or 0
    shared.buf_bytes_cache[buf] = bytes
  end

  local ft = vim.bo[buf].filetype
  local parser_kb = shared.config.parser_memory_estimate_kb_by_filetype[ft] or 0

  return math.floor(bytes / 1024) + parser_kb
end

-- Format the bytes freed in the most readable unit (K below 1M).
local function format_freed(freed_kb)
  if freed_kb >= 1024 then
    return string.format("~%.1fM freed", freed_kb / 1024)
  end

  return string.format("~%dK freed", freed_kb)
end

-- Human-readable summary of a prune result; used by manual + auto callers.
-- Compact per-category line: counts each category (buffers, parsers, LSP),
-- the total freed, and the idle threshold used for this sweep.
function M.format_result(result)
  if result.unloaded == 0 and result.lsp_stopped == 0 then
    return string.format("[mem] prune → nothing to reclaim (idle ≥ %dm)",
      result.threshold_minutes)
  end

  local pieces = {
    string.format("%d buf", result.unloaded),
    string.format("%d parsers", result.parsers_stopped or 0),
    string.format("%d LSP", result.lsp_stopped),
    format_freed(result.freed_kb),
  }

  return string.format("[mem] prune → %s (idle ≥ %dm)",
    table.concat(pieces, ", "), result.threshold_minutes)
end

return M
