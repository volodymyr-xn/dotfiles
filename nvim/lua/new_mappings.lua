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

vim.api.nvim_set_keymap('n', '<C-s>', '<C-w>v', {noremap = true, silent = false })

-- Free mappings for "s" button that works as prefix
vim.api.nvim_set_keymap('n', 's', '', {noremap = true, silent = false })
vim.api.nvim_set_keymap('n', 'st', '<C-w>s', {noremap = true, silent = false })

vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope jumplist<CR>', {noremap = true, silent = false })

-- vim.api.nvim_set_keymap('n', 'dn', 'bdiw', {})

-- Quick binding.pry
-- vim.cmd [[
--  nnoremap <leader>q o<Esc>==i binding.pry<Esc>==o<Esc>kko<Esc>j
-- ]]

-- Quick binding.pry
vim.api.nvim_set_keymap(
 'n',
 '<leader>q',
 'o<Esc>==i binding.pry<Esc>==',
 { noremap = true, silent = true }
)


-- vim.api.nvim_set_keymap('n', 'M', ':tabnext<CR>', { noremap = true })

-- Re-balance panes
-- vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true})
