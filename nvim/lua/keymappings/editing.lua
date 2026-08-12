-- Yank word under cursor into default register
vim.api.nvim_set_keymap('n', '*', 'viwy', { silent = true, noremap = true, desc = "Select word under cursor" })

-- Indent and keep visual selection active
vim.api.nvim_set_keymap('v', '<', '<gv', { noremap = true, desc = "Indent left and reselect" })
vim.api.nvim_set_keymap('v', '>', '>gv', { noremap = true, desc = "Indent right and reselect" })

-- Auto-indent selected lines
vim.api.nvim_set_keymap('v', '<Tab>', '=', { noremap = true, desc = "Auto-indent selection" })

-- Copy visual selection to system clipboard
vim.api.nvim_set_keymap('v', 'm', '"+y', { noremap = true, desc = "Copy to system clipboard" })

-- Move selected lines up/down and re-indent
vim.api.nvim_set_keymap('v', 'K', ":m '<-2<CR>gv=gv", { noremap = true, desc = "Move lines up" })
vim.api.nvim_set_keymap('v', 'J', ":m '>+1<CR>gv=gv", { noremap = true, desc = "Move lines down" })

-- Leave cursor at end of pasted/yanked text
vim.api.nvim_set_keymap('n', 'p', 'p`]', { noremap = true, desc = "Paste and move to end" })
vim.api.nvim_set_keymap('v', 'y', 'y`]', { noremap = true, desc = "Yank and move to end" })
vim.api.nvim_set_keymap('v', 'p', 'p`]', { noremap = true, desc = "Paste and move to end" })

-- Paste over selection without overwriting the unnamed register
vim.api.nvim_set_keymap('x', 'p', '"_dP', { noremap = true, desc = "Paste without yanking" })

-- Change surrounding single quotes to double quotes (vim-surround)
vim.api.nvim_set_keymap('n', '-', 'cs\'\"', { desc = "Change single to double quotes" })

-- Readline-style navigation in insert mode
vim.keymap.set('i', '<C-a>', '<Home>', { noremap = true, desc = "Go to beginning of line" })
vim.keymap.set('i', '<C-e>', '<End>', { noremap = true, desc = "Go to end of line" })
vim.keymap.set('i', '<C-f>', '<C-Left>', { noremap = true, desc = "Move backward one word" })
vim.keymap.set('i', '<C-b>', '<C-Right>', { noremap = true, desc = "Move forward one word" })

-- Delete to first non-blank char (where I lands) and enter insert mode
vim.keymap.set('n', 'K', 'c^', { noremap = true, desc = "Change to start of line" })