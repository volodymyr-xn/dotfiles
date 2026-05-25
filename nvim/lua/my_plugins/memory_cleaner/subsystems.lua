-- Subsystem clears for the manual `:MemClear*` family.
--
-- Each function returns a count of what it actually reclaimed so the user
-- command can report results. Treesitter / fugitive / LSP each have their
-- own escape hatch and a combined `clear_all` runner.

local api = vim.api
local fn = vim.fn

local M = {}

-- Stop every treesitter parser/highlighter currently attached. Safe to call
-- when none are active. Counts buffers where stop succeeded.
function M.clear_treesitter()
  local stopped = 0
  local ts_active = (vim.treesitter.highlighter and vim.treesitter.highlighter.active) or {}

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) and ts_active[buf] then
      if pcall(vim.treesitter.stop, buf) then
        stopped = stopped + 1
      end
    end
  end

  return stopped
end

-- Wipe every fugitive buffer (blames, diffs, fugitive://… URIs). These
-- accumulate during a long session even with the BufHidden auto-wipe.
function M.clear_fugitive()
  local wiped = 0

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) then
      local ft = vim.bo[buf].filetype or ""
      local name = api.nvim_buf_get_name(buf) or ""
      local is_fugitive = ft:match("^fugitive")
        or name:match("^fugitive://")
        or name:match("/%.fugitiveblame$")
        or name:match("/%d+%.fugitiveblame$")

      if is_fugitive then
        if pcall(api.nvim_buf_delete, buf, { force = true }) then
          wiped = wiped + 1
        end
      end
    end
  end

  return wiped
end

-- Stop every LSP client unconditionally — even those still attached to
-- buffers. Caller is expected to be in a "reclaim now" mood. Use the
-- background prune sweep for orphan-only cleanup.
function M.clear_lsp()
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  local stopped = 0

  for _, client in ipairs(get_clients()) do
    if pcall(vim.lsp.stop_client, client.id, true) then
      stopped = stopped + 1
    end
  end

  return stopped
end

-- Force Lua GC twice — second pass collects cycles freed by the first.
function M.gc()
  collectgarbage("collect")
  collectgarbage("collect")
end

-- Run all three subsystem clears + GC. Returns a result table.
function M.clear_all()
  local result = {
    treesitter = M.clear_treesitter(),
    fugitive = M.clear_fugitive(),
    lsp = M.clear_lsp(),
  }
  M.gc()
  return result
end

return M
