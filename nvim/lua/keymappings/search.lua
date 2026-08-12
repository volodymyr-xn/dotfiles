-- Clear search highlight
vim.api.nvim_set_keymap('n', '<Leader>n', ':nohl<CR>', { silent = true, noremap = true, desc = "Clear search highlight" })

-- Search and replace in current file (cursor left to fill pattern)
vim.api.nvim_set_keymap('n', '<Leader>r', ':%s///g<Left><Left><Left>', { noremap = true, desc = "Search and replace in file" })
vim.api.nvim_set_keymap('n', '<Leader>@', ':%s///g<Left><Left><Left>', { noremap = true, desc = "Search and replace in file" })

-- Search and replace across all quickfix entries
vim.api.nvim_set_keymap('n', '@', ":cfdo %s///g | update <c-b><right><right><right><right><right><right><right><right>", { noremap = true, desc = "Search and replace in quickfix" })

-- Search word under cursor forwards (opposite of default * direction)
vim.keymap.set('n', '#', "*N", { noremap = true, silent = true, desc = "Search word forwards" })

-- Grep project for binding.pry (Ruby debugger)
vim.api.nvim_set_keymap('n', '<Leader>!', ':Ack "binding.pry"<CR>', { noremap = true, silent = false, desc = "Search for binding.pry" })

-- Walk the quickfix list. Plain :cnext/:cprev, so they must stay independent
-- of ack.nvim (which lazy only loads on an :Ack* command).
vim.api.nvim_set_keymap('n', '<Leader>]', ':cn<CR>', { desc = "Next quickfix entry" })
vim.api.nvim_set_keymap('n', '<Leader>[', ':cp<CR>', { desc = "Previous quickfix entry" })
vim.api.nvim_set_keymap('n', '}', ':cn<CR>', { desc = "Next quickfix entry" })
vim.api.nvim_set_keymap('n', '{', ':cp<CR>', { desc = "Previous quickfix entry" })
