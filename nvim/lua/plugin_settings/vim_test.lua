--============================================================================
--=================== vim-test settings ======================================
--============================================================================
-- Open ruby test in tmux pane
vim.g['test#strategy'] = 'vimux'

-- Use bundle exec for ruby tests
vim.g['test#ruby#bundle_exec'] = 1

-- Run rspec with spring preloader
-- Temporary disable for current project without spring
-- vim.g.test#ruby#rspec#executable = 'rsx'
--
--- ============================================================================
--- =================== vimux settings =========================================
--- ============================================================================
-- Use vertical tmux slpit for vimux commands
vim.g['VimuxOrientation'] = "h"

--- Open vimux tmux pane with 50% width of screen
vim.g['VimuxHeight'] = "80"
vim.g['VimuxWidth'] = "80"
