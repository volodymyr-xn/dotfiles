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
