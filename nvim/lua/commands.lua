--============================================================================
--====================== Commands ===========================================
--============================================================================
-- Toggles current window zoom
vim.cmd("command! ToggleCurrentWindowZoom lua ToggleCurrentWindowZoom()")

-- Fix save file typos
vim.cmd("command! W w")
vim.cmd("command! WQ wq")
vim.cmd("command! Wq wq")
vim.cmd("command! Q q")

--============================================================================
--====================== Functions ===========================================
--============================================================================

-- DEPRECATED
-- function! RestartServers()
--   execute system("tmux send-keys -t 2.left C-c \" bundle exec rails s\" C-m")
--   execute system("tmux send-keys -t 3.left C-c \" bundle exec rails s -p 3001\" C-m")
--   execute system("tmux send-keys -t 5.left C-c \" bundle exec sidekiq\" C-m")
--   echo "Servers reloaded"
-- endfunction

--  function ReloadActiveChromeTab()
--   local currentTerminalEmulator = vim.fn.system("xdotool getactivewindow")
--
--   vim.fn.execute("!" ..
--     "xdotool search --onlyvisible --class Chrome windowfocus key F5" ..
--     " && xdotool windowfocus " .. currentTerminalEmulator)
--
--   print("Chrome tab reloaded")
-- end

-- Toggle zoom of current window
function ToggleCurrentWindowZoom()
  if not vim.g.currentWindowZoomed then
    vim.g.currentWindowZoomed = false
    -- TODO check nerdtree state
  end

  if vim.g.currentWindowZoomed then
    vim.cmd('execute "normal \\<C-W>="')
    vim.g.currentWindowZoomed = false
  else
    -- vim.cmd("NvimTreeClose")
    vim.cmd("Neotree close")
    vim.cmd('execute "normal \\<C-W>\\| \\<C-W>_"')
    vim.g.currentWindowZoomed = true
  end
end

