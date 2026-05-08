-- Clear search highlight
vim.api.nvim_set_keymap('n', '<Leader>n', ':nohl<CR>', { silent = true, noremap = true, desc = "Clear search highlight" })

-- Search and replace in current file (cursor left to fill pattern)
vim.api.nvim_set_keymap('n', '<Leader>@', ':%s///g<Left><Left><Left>', { noremap = true, desc = "Search and replace in file" })

-- Search and replace across all quickfix entries
vim.api.nvim_set_keymap('n', '@', ":cfdo %s///g | update <c-b><right><right><right><right><right><right><right><right>", { noremap = true, desc = "Search and replace in quickfix" })

-- Search word under cursor forwards (opposite of default * direction)
vim.keymap.set('n', '#', "*N", { noremap = true, silent = true, desc = "Search word forwards" })

-- Grep project for binding.pry (Ruby debugger)
vim.api.nvim_set_keymap('n', '<Leader>!', ':Ack "binding.pry"<CR>', { noremap = true, silent = false, desc = "Search for binding.pry" })
