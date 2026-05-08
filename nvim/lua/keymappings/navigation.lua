-- Go to beginning of line (normal and visual)
vim.api.nvim_set_keymap('n', 'H', '^', { noremap = true, desc = "Go to beginning of line" })
vim.api.nvim_set_keymap('v', 'H', '^', { noremap = true, silent = true, desc = "Go to beginning of line" })

-- Go to end of line (normal and visual)
vim.api.nvim_set_keymap('n', 'L', '$', { noremap = true, desc = "Go to end of line" })
vim.api.nvim_set_keymap('v', 'L', '$', { noremap = true, silent = true, desc = "Go to end of line" })

-- Move by visible lines when text is wrapped
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, desc = "Move down by visual line" })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, desc = "Move up by visual line" })

-- Move to end of WORD (skips punctuation)
vim.api.nvim_set_keymap('n', 'e', 'E', { noremap = true, desc = "Move to end of WORD" })

-- Toggle fold under cursor
vim.api.nvim_set_keymap('n', '0', 'za', { noremap = true, desc = "Toggle fold" })

-- Open code outline panel
vim.keymap.set('n', 'go', ':Outline<CR>', { noremap = true, silent = true, desc = "Outline" })
