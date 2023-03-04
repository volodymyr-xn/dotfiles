--=========================================================================
--====================== Ack settings =====================================
--=========================================================================
-- Ack mappings
vim.api.nvim_set_keymap('n', '!', ':Ack<SPACE>', {})

-- Ack: To go to the next search result
vim.api.nvim_set_keymap('n', '<leader>]', ':cn<CR>', {})

-- Ack: To go to the previous search results
vim.api.nvim_set_keymap('n', '<leader>[', ':cp<CR>', {})

-- TODO add mapping for spliting tmux and running rails console
-- Maps gX to use xdg-open with the filepath under cursor
vim.api.nvim_set_keymap('n', 'gx', ':silent :execute "!xdg-open " . expand("%:p:h") . "/" . expand("<cfile>") . " &"<CR>', {})
