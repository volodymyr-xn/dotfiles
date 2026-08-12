local config = require("ack.config")

local M = {}

-- Which of the two apply_*mappings options governs this search.
local function using_list_mappings(using_loclist)
  local options = config.options
  if using_loclist then
    return options.apply_lmappings
  end
  return options.apply_qmappings
end

-- Buffer-local mappings for the result window: window-splitting jumps, a
-- close mapping, and optional preview-on-move when g:ackpreview is set.
function M.apply_mappings(using_loclist)
  if not using_list_mappings(using_loclist) or vim.bo.filetype ~= "qf" then
    return
  end

  local options = config.options
  local closemap = ":" .. (using_loclist and "l" or "c") .. "close<CR>"
  local opts = { buffer = true, silent = true, noremap = true }

  local mappings = vim.tbl_extend("force", options.mappings, { q = closemap })

  for key, mapping in pairs(mappings) do
    vim.keymap.set("n", key, options.autoclose and mapping .. closemap or mapping, opts)
  end

  if options.autoclose then
    vim.keymap.set("n", "<CR>", "<CR>" .. closemap, opts)
  end

  if vim.g.ackpreview then
    vim.keymap.set("n", "j", "j<CR><C-W><C-P>", opts)
    vim.keymap.set("n", "k", "k<CR><C-W><C-P>", opts)
    vim.keymap.set("n", "<Down>", "j", opts)
    vim.keymap.set("n", "<Up>", "k", opts)
  end
end

-- Load the searched pattern into the search register so the matches are
-- highlighted in the opened buffers.
function M.highlight_pattern(args)
  if not config.options.highlight then
    return
  end

  local pattern = vim.fn.matchstr(args, [=[\v(-)@<!(\<)@<=\w+|['"]zs.{-}ze['"]]=])
  if pattern ~= "" then
    vim.fn.setreg("/", pattern)
    local keys = vim.api.nvim_replace_termcodes(":let &hlsearch=1 | echo <CR>", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

-- Open the result window with the configured handler and map it.
function M.show_results(using_loclist)
  local options = config.options
  vim.cmd(using_loclist and options.lhandler or options.qhandler)
  M.apply_mappings(using_loclist)
  vim.cmd("redraw!")
end

return M
