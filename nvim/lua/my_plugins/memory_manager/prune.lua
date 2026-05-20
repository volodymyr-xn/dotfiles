-- Idle-buffer prune pass + LSP auto-stop + per-buffer reclaim estimate.

local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn
local shared = require("my_plugins.memory_manager.shared")

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

  for _, name in ipairs(shared.config.never_stop_lsp) do
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
-- Returns `{ unloaded, lsp_stopped, freed_kb, threshold_minutes }` so callers
-- can surface a meaningful "what got reclaimed" message.
function M.prune(opts)
  opts = opts or {}
  local threshold_minutes = opts.force_minutes or shared.config.idle_minutes
  local now_seconds = uv.hrtime() / 1e9
  local unloaded = 0
  local freed_kb = 0

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if not M.is_exempt(buf) then
      local last = shared.last_left_at[buf] or now_seconds
      local idle_seconds = now_seconds - last

      if threshold_minutes == 0 or idle_seconds >= (threshold_minutes * 60) then
        -- Estimate reclaimable bytes BEFORE unload (after unload the buffer
        -- text is gone and our estimator returns 0).
        local est_kb = M.estimate_buf_kb(buf)
        pcall(vim.treesitter.stop, buf)
        local ok = pcall(api.nvim_buf_delete, buf, { unload = true })

        if ok then
          shared.last_left_at[buf] = nil
          shared.buf_bytes_cache[buf] = nil
          unloaded = unloaded + 1
          freed_kb = freed_kb + est_kb
        end
      end
    end
  end

  local lsp_stopped = stop_orphan_lsp_clients()

  return {
    unloaded = unloaded,
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
  local parser_kb = shared.config.parser_estimate_kb[ft] or 0

  return math.floor(bytes / 1024) + parser_kb
end

-- Human-readable summary of a prune result; used by manual + auto callers.
function M.format_result(result)
  if result.unloaded == 0 and result.lsp_stopped == 0 then
    return string.format("[mem] prune: nothing to reclaim (threshold %dm)",
      result.threshold_minutes)
  end

  local pieces = {}

  if result.unloaded > 0 then
    if result.freed_kb >= 1024 then
      pieces[#pieces + 1] = string.format("%d buffers (~%.1fM freed)",
        result.unloaded, result.freed_kb / 1024)
    else
      pieces[#pieces + 1] = string.format("%d buffers (~%dK freed)",
        result.unloaded, result.freed_kb)
    end
  end

  if result.lsp_stopped > 0 then
    pieces[#pieces + 1] = string.format("%d LSP client%s stopped",
      result.lsp_stopped, result.lsp_stopped == 1 and "" or "s")
  end

  return string.format("[mem] prune: %s (threshold %dm)",
    table.concat(pieces, ", "), result.threshold_minutes)
end

return M
