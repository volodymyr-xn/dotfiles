-- Show git blame for current file
vim.api.nvim_set_keymap('n', '<Leader>gb', ':Git blame<CR>', { noremap = true, desc = "Git blame" })

-- Navigate between git hunks; wraps around via NavigateHunk (handles diff buffers)
vim.keymap.set('n', ')', function() NavigateHunk('next') end, { noremap = true, silent = true, desc = "Next git hunk" })
vim.keymap.set('n', '(', function() NavigateHunk('prev') end, { noremap = true, silent = true, desc = "Previous git hunk" })

-- Toggle a persistent background highlight on every added/changed line in the
-- buffer. Deleted lines stay invisible: gitsigns leaves `GitSignsDeleteLn`
-- (and its `GitSignsTopdeleteLn` fallback) undefined, so delete markers paint
-- nothing. `linehl` is a global gitsigns flag, so this applies to all buffers.
vim.keymap.set('n', 'sf', function() require('gitsigns').toggle_linehl() end,
  { noremap = true, silent = true, desc = "Toggle changed-line highlight" })

-- Preview hunk diff inline below the current line. Lazy-require gitsigns so
-- its `event = "BufReadPre"` actually defers — top-level require would
-- trip lazy.nvim's auto-loader and eager-load the plugin at startup.
vim.keymap.set('n', 'gp', function() require('gitsigns').preview_hunk_inline() end,
  { noremap = true, silent = true, desc = "Preview git hunk" })
