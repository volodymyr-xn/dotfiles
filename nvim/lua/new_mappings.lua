-- Copy relative path of the current file to the clipboard
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = @%<CR>', { noremap = true, silent = true })

-- Switch between tabs
-- vim.api.nvim_set_keymap('n', '<C-q>', ':tabprev<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', {noremap = true, silent = true, desc = "Next tab" })
vim.api.nvim_set_keymap('n', '<M-k>', ':tabprev<CR>', {noremap = true, silent = true, desc = "Previous tab" })
vim.api.nvim_set_keymap('n', '<M-j>', ':tabnext<CR>', {noremap = true, silent = true, desc = "Next tab" })

-- Split window vertically by presing shift + M
vim.api.nvim_set_keymap('n', 'M', ':vsplit<CR>', { noremap = true, silent = true, desc = "Split window vertically" })
-- Go to the beginning of the line
vim.api.nvim_set_keymap('v', 'H', '^', {noremap = true, silent = true, desc = "Go to beginning of line" })
-- Go to the end of the line
vim.api.nvim_set_keymap('v', 'L', '$', {noremap = true, silent = true, desc = "Go to end of line" })

-- vim.api.nvim_set_keymap('n', '<C-3>', '#', {noremap = true, silent = true })


-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
-- Copy current file relative path to clipboard
vim.api.nvim_set_keymap('n', '`', ':CopyCurrentFileRelativePathToClipboard<CR>', { noremap = true, desc = "Copy file path to clipboard" })
-- vim.api.nvim_set_keymap('n', '~', ':CopyCurrentFileNameToClipboard<CR>', { noremap = true })

-- Search for binding.pry
vim.api.nvim_set_keymap('n', '<Leader>!', ':Ack "binding.pry"<CR>', {noremap = true, silent = false, desc = "Search for binding.pry" })

-- vim.api.nvim_set_keymap('n', '<C-s>', '<C-w>v', {noremap = true, silent = false })

-- Free mappings for "s" button that works as prefix
vim.api.nvim_set_keymap('n', 's', '', {noremap = true, silent = false, desc = "Prefix key" })
-- Split window horizontally
-- vim.api.nvim_set_keymap('n', 'st', '<C-w>s', {noremap = true, silent = false, desc = "Split window horizontally" })

-- vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope jumplist<CR>', {noremap = true, silent = false })
-- vim.api.nvim_set_keymap('n', '<Leader>q', ':Telescope buffers<CR>', {noremap = true, silent = false })
-- Telescope buffers
vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope buffers<CR>', {noremap = true, silent = false, desc = "Telescope buffers" })


-- vim.api.nvim_set_keymap('n', 'dn', 'bdiw', {})

-- Quick binding.pry
-- vim.cmd [[
--  nnoremap <leader>q o<Esc>==i binding.pry<Esc>==o<Esc>kko<Esc>j
-- ]]

-- Insert debug
-- vim.keymap.set("n", "<Leader>q", CustomInsertDebug, { noremap = true, silent = true })
vim.keymap.set("n", "K", ":tabnext<CR>", { noremap = true, silent = true, desc = "Next tab" })
vim.keymap.set("n", "<leader>K", CustomInsertDebug, { noremap = true, silent = true, desc = "Insert debug statement" })

vim.keymap.set("n", "<Leader>`", SendFileToTmux, { noremap = true, silent = true, desc = "Send file path to tmux" })
vim.keymap.set("v", "<Leader>`", SendSelectionToTmux, { noremap = true, silent = true, desc = "Send file + selection to tmux" })

-- vim.keymap.set('n', 's', ':tabnext<CR>', { noremap = true })

-- vim.keymap.set('n', '@', highlight_word_under_cursor, { noremap = true, silent = true })
-- Search word under cursor backwards
vim.keymap.set('n', '#', "*N", { noremap = true, silent = true, desc = "Search word backwards" })


-- vim.keymap.set('n', 'K', ':OutlineFocus<CR>', { noremap = true, silent = true })
-- vim.keymap.set('n', '<leader>k', ':Outline!<CR>', { noremap = true, silent = true })
-- Test current file
-- vim.keymap.set('n', '<leader>k', ':TestFile<CR>', { noremap = true, silent = true, desc = "Test file" })

-- Start FzfLua menu
-- vim.keymap.set('n', 'sj', ':FzfLua<cr>', { noremap = true, silent = true, desc = "FzfLua select" })

vim.keymap.set('n', 'go', ':Outline<CR>', { noremap = true, silent = true, desc = "Outline" })

vim.keymap.set('n', '<Leader>e', function()
  local ok, onediff = pcall(require, "my_plugins.onediff")
  if ok then onediff.refresh() end
end, { noremap = true, silent = true, desc = "Refresh OneDiff diffs" })

-- Re-balance panes
-- vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true})
--

local gitsigns = require('gitsigns')

vim.keymap.set('n', ')', function() NavigateHunk('next') end, { noremap = true, silent = true, desc = "Next git hunk" })
vim.keymap.set('n', '(', function() NavigateHunk('prev') end, { noremap = true, silent = true, desc = "Previous git hunk" })
vim.keymap.set('n', 'gp', gitsigns.preview_hunk_inline, { noremap = true, silent = true, desc = "Preview git hunk" })
