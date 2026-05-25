--============================================================================
--====================== Autocommands ============================================
--============================================================================

-- Auto remove trailing blank spaces on each save
-- vim.api.nvim_command("autocmd BufWritePre * :%s/\\s\\+$//e")

-- Set textwidth 75 for markdown files
-- vim.api.nvim_command("autocmd BufRead,BufNewFile *.md setlocal textwidth=75")

-- Force Ruby syntax for Pry config file
-- vim.api.nvim_command("autocmd BufRead,BufNewFile .pryrc setlocal syntax=ruby")
-- Shared augroup for all user autocmds defined in this file. `clear = true`
-- makes re-sourcing idempotent (no duplicate handlers on :so $MYVIMRC).
local group = vim.api.nvim_create_augroup("UserAutocmds", { clear = true })

-- Auto-reload files changed outside of vim, except while typing a command.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = group,
  pattern = "*",
  command = "if mode() != 'c' | checktime | endif",
})


-- Highlight yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank({ higroup = "Type", timeout = 250 })
  end,
})

--============================================================================
--================== YAML / HTML / eruby settings ============================
--============================================================================
-- Force filetype + indent-based folding for yaml/html/erb on read.
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = group,
  pattern = { "*.yaml", "*.yml", "*.html", "*.erb" },
  callback = function(args)
    local ext_to_ft = { yaml = "yaml", yml = "yaml", html = "html", erb = "eruby" }
    local ext = args.file:match("%.([^.]+)$")
    local ft = ext_to_ft[ext]

    if ft then
      vim.bo[args.buf].filetype = ft
    end

    vim.wo.foldmethod = "indent"
  end,
})

-- Shared 2-space indent for yaml/html/eruby; yaml additionally opens folded.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "yaml", "html", "eruby" },
  callback = function(args)
    local o = vim.opt_local
    o.tabstop = 2
    o.softtabstop = 2
    o.shiftwidth = 2
    o.expandtab = true

    if args.match == "yaml" then
      o.foldenable = true
    end
  end,
})

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
  group = group,
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
  group = group,
  pattern = { "json", "jsonc", "json5" },
  callback = function() vim.opt_local.conceallevel = 0 end,
})
