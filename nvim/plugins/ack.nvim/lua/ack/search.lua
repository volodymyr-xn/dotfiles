local util = require("ack.util")

local M = {}

-- Bang form of a grep command, which fills the list without jumping to the
-- first match. The jump is issued separately (see jump_to_first) so errors
-- raised while loading a result file are not mistaken for search failures.
local function without_jump(grepcmd)
  if grepcmd:find("!", 1, true) then
    return grepcmd
  end

  return grepcmd .. "!"
end

-- Run the search through :grep/:lgrep with 'grepprg' and 'grepformat'
-- swapped in for the duration of the call, then restored. Returns whether
-- the search itself ran without error.
function M.with_grep(grepcmd, grepprg, grepargs, grepformat)
  local grepprg_bak = vim.o.grepprg
  local grepformat_bak = vim.o.grepformat

  vim.o.grepprg = grepprg
  vim.o.grepformat = grepformat

  local ok, err = pcall(vim.cmd, "silent " .. without_jump(grepcmd) .. " " .. grepargs)

  vim.o.grepprg = grepprg_bak
  vim.o.grepformat = grepformat_bak

  if not ok and err then
    util.warn("Search failed: " .. tostring(err))
  end

  return ok
end

-- How many entries the search left in whichever list it filled. The bang
-- form never raises E480, so an empty result has to be detected here.
function M.result_count(using_loclist)
  if using_loclist then
    return vim.fn.getloclist(0, { size = 0 }).size
  end

  return vim.fn.getqflist({ size = 0 }).size
end

-- Jump to the first result, the part of :grep that the bang suppresses.
-- Opening that file runs its autocommands and modelines, whose errors (a
-- malformed modeline, say) say nothing about the search that found it.
function M.jump_to_first(using_loclist)
  local ok, err = pcall(vim.cmd, "silent " .. (using_loclist and "lfirst" or "cfirst"))

  if not ok and err then
    util.warn("Error while opening the first result: " .. tostring(err))
  end
end

-- Run the search asynchronously through vim-dispatch, which reads
-- 'makeprg'/'errorformat' rather than the grep options.
function M.with_dispatch(grepprg, grepargs, grepformat)
  local makeprg_bak = vim.bo.makeprg
  local errorformat_bak = vim.bo.errorformat

  -- Dispatch hands 'makeprg' to the shell as-is, so the pipe escaping that
  -- Vim's own command-line parsing needs would reach the shell literally.
  vim.bo.makeprg = grepprg:gsub("\\|", "|") .. " " .. grepargs
  vim.bo.errorformat = grepformat

  local ok, err = pcall(vim.cmd, "Make")

  vim.bo.makeprg = makeprg_bak
  vim.bo.errorformat = errorformat_bak

  if not ok and err then
    util.warn("Dispatch search failed: " .. tostring(err))
  end
end

-- Keep only the first match per file+line so multiple hits on one line
-- don't produce duplicated entries. Relevant only for per-match output
-- (`--vimgrep`); gated by the remove_duplicates option at the call site.
function M.dedupe(using_loclist)
  local list = using_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()

  local seen = {}
  local unique = {}
  for _, item in ipairs(list) do
    local key = item.bufnr .. ":" .. item.lnum
    if not seen[key] then
      seen[key] = true
      table.insert(unique, item)
    end
  end

  if #unique == #list then
    return
  end

  if using_loclist then
    vim.fn.setloclist(0, {}, "r", { items = unique })
  else
    vim.fn.setqflist({}, "r", { items = unique })
  end
end

return M
