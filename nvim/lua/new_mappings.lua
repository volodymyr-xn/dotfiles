-- Copy relative path of the current file to the clipboard
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = @%<CR>', { noremap = true, silent = true })

-- Switch between tabs
vim.api.nvim_set_keymap('n', '<C-q>', ':tabprev<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-k>', ':tabprev<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-j>', ':tabnext<CR>', {noremap = true, silent = true })

-- Split window vertically by presing shift + M
vim.api.nvim_set_keymap('n', 'M', ':vsplit<CR>', { noremap = true, silent = true })
-- Go to the beginning of the line
vim.api.nvim_set_keymap('v', 'H', '^', {noremap = true, silent = true })
-- Go to the end of the line
vim.api.nvim_set_keymap('v', 'L', '$', {noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<C-3>', '#', {noremap = true, silent = true })


-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '`', ':CopyCurrentFileRelativePathToClipboard<CR>', { noremap = true })

vim.api.nvim_set_keymap('n', '<Leader>!', ':Ack "binding.pry"<CR>', {noremap = true, silent = false })

vim.api.nvim_set_keymap('n', 's', ':tabnext<CR>', {noremap = true, silent = false })

-- vim.api.nvim_set_keymap('n', 'M', ':tabnext<CR>', { noremap = true })

-- Re-balance panes
-- vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true})
