local ack = require('my_plugins.ack')

ack.setup({
  ackprg = 'ag --vimgrep',
  highlight = false,
  autoclose = false,
  use_cword_for_empty_search = true,
})

vim.api.nvim_set_keymap('n', '!', ':Ack<SPACE>', {})
vim.api.nvim_set_keymap('n', '@', '*N:Ack <C-R><C-W><CR>', {})
vim.api.nvim_set_keymap('n', '<leader>]', ':cn<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>[', ':cp<CR>', {})
