--============================================================================
--====================== Autocommands ============================================
--============================================================================

-- Auto remove trailing blank spaces on each save
-- vim.api.nvim_command("autocmd BufWritePre * :%s/\\s\\+$//e")

-- Set textwidth 75 for markdown files
-- vim.api.nvim_command("autocmd BufRead,BufNewFile *.md setlocal textwidth=75")

-- Force Ruby syntax for Pry config file
-- vim.api.nvim_command("autocmd BufRead,BufNewFile .pryrc setlocal syntax=ruby")
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = "*",
})

if vim.fn.has("nvim") == 1 then
  -- Highligh text on yank
  vim.api.nvim_command("autocmd TextYankPost * silent! lua vim.highlight.on_yank {higroup=\"Type\", timeout=250}")
end

--============================================================================
--================== YAML settings ===========================================
--============================================================================
-- Set folding rules for yaml
vim.api.nvim_command("autocmd BufNewFile,BufReadPost *.{yaml,yml} set filetype=yaml foldmethod=indent")
-- By default fold just opened yaml file
vim.api.nvim_command("autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab foldenable")

-- Set folding rules for html and erb files
vim.api.nvim_command("autocmd BufNewFile,BufReadPost *.{html} set filetype=html foldmethod=indent")
vim.api.nvim_command("autocmd BufNewFile,BufReadPost *.{erb} set filetype=eruby foldmethod=indent")
-- vim.api.nvim_command("autocmd BufNewFile,BufReadPost *.{html} set filetype=html foldmethod=expr")
-- vim.api.nvim_command("autocmd BufNewFile,BufReadPost *.{erb} set filetype=eruby foldmethod=expr")
vim.api.nvim_command("autocmd FileType html setlocal ts=2 sts=2 sw=2 expandtab")
vim.api.nvim_command("autocmd FileType eruby setlocal ts=2 sts=2 sw=2 expandtab")

--local lsp_util = vim.lsp.util

--function code_action_listener()
--  local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
--   local params = lsp_util.make_range_params()
--   params.context = context
--   vim.lsp.buf_request(0, 'textDocument/codeAction', params, function(err, result, ctx, config)
--     -- do something with result - e.g. check if empty and show some indication such as a sign
--   end)
-- end

-- return M

-- vim.cmd [[
--  autocmd CursorHold,CursorHoldI * lua code_action_listener()
--]]


-- Correcly Focus cursor and go to insert mode in nvim-terminal widnow.
-- This is very import to have different types of terminal tui tools work correcly in nvim terminal window.
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    if vim.bo.buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end,
})

--============================================================================
--================== JSON: never conceal quotes ==============================
--============================================================================
-- Two independent conceal sources exist for JSON in this setup:
--   1. Neovim built-in syntax/json.vim — gated on g:vim_json_conceal
--   2. nvim-treesitter queries/json/highlights.scm — conceals every "
-- Both honor &conceallevel, so pinning it to 0 for json filetypes
-- (json, jsonc, json5) is the canonical kill-switch.
vim.g.vim_json_conceal = 0
vim.g.vim_json_syntax_conceal = 0
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc", "json5" },
  callback = function() vim.opt_local.conceallevel = 0 end,
})
