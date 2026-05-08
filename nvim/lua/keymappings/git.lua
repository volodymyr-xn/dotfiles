local gitsigns = require('gitsigns')

-- Show git blame for current file
vim.api.nvim_set_keymap('n', '<Leader>gb', ':Git blame<CR>', { noremap = true, desc = "Git blame" })

-- Navigate between git hunks; wraps around via NavigateHunk (handles diff buffers)
vim.keymap.set('n', ')', function() NavigateHunk('next') end, { noremap = true, silent = true, desc = "Next git hunk" })
vim.keymap.set('n', '(', function() NavigateHunk('prev') end, { noremap = true, silent = true, desc = "Previous git hunk" })

-- Preview hunk diff inline below the current line
vim.keymap.set('n', 'gp', gitsigns.preview_hunk_inline, { noremap = true, silent = true, desc = "Preview git hunk" })
