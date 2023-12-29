require('Comment').setup()

-- vim.api.nvim_set_keymap('v', '\\', 'gc', {})
-- -- Comment line in normal mode
-- vim.api.nvim_set_keymap('n', '\\', 'gcc', {})
--
vim.api.nvim_set_keymap('v', '<Leader><Tab>', 'gc', {})
-- Comment line in normal mode
vim.api.nvim_set_keymap('n', '<Leader><Tab>', 'gcc', {})

-- Tcomment
-- Comment line in visual mode
-- vim.api.nvim_set_keymap('v', '\\', ':TComment<CR>', { noremap = true })
-- -- Comment line in normal mode
-- vim.api.nvim_set_keymap('n', '\\', ':TComment<CR>', { noremap = true })
