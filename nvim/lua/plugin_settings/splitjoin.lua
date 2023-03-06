-- ==============================================================================
-- ================== Splitjoin settings =========================================
-- ==============================================================================
-- Split one line of code into multiple
vim.api.nvim_set_keymap('n', '<Leader>8', 'gS', {})
vim.api.nvim_set_keymap('v', '<Leader>8', 'gS', {})

-- Split multiple lines of code into one
vim.api.nvim_set_keymap('n', '<Leader>7', 'gJ', {})
vim.api.nvim_set_keymap('v', '<Leader>7', 'gJ', {})

-- Search yaml line by key provided by Einenlum/yaml-revealer ==
-- map <Leader>b :call SearchYamlKey()<CR>
-- nnoremap <Leader>u :call SearchYamlKey()<CR>
-- nnoremap R :call SearchYamlKey()<CR>
