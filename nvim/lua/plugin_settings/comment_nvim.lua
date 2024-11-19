
-- Comment line in visual mode
 vim.api.nvim_set_keymap('v', '<Leader><Tab>', 'gc', {})
--Comment line in normal mode
 vim.api.nvim_set_keymap('n', '<Leader><Tab>', 'gcc', {})

--  require('nvim-treesitter.configs').setup {
--   context_commentstring = {
--     enable = true,
--     commentary_integration = {
--       -- change default mapping
--       Commentary = 'g/',
--       -- disable default mapping
--       CommentaryLine = false,
--     },
--   },
-- }

-- vim.api.nvim_set_keymap('v', '\\', 'gc', {})

-- Tcomment
-- Comment line in visual mode
-- vim.api.nvim_set_keymap('v', '\\', ':TComment<CR>', { noremap = true })
-- -- Comment line in normal mode
-- vim.api.nvim_set_keymap('n', '\\', ':TComment<CR>', { noremap = true })
