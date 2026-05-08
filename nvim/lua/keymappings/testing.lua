-- vim-test mappings
vim.api.nvim_set_keymap('n', '<Leader>t', ':TestNearest<CR>', { silent = true, desc = "Test nearest" })
vim.api.nvim_set_keymap('n', '<Leader>T', ':TestFile<CR>', { silent = true, desc = "Test file" })
vim.api.nvim_set_keymap('n', '<Leader>l', ':TestLast<CR>', { silent = true, desc = "Test last" })
