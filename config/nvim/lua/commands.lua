--============================================================================
--====================== Commands ===========================================
--============================================================================
-- Toggles current window zoom
vim.cmd("command! ToggleCurrentWindowZoom lua ToggleCurrentWindowZoom()")

-- CopyCurrentFileRelativePathToClipboard

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

 function ReloadActiveChromeTab()
  -- local currentTerminalEmulator = vim.fn.system("xdotool getactivewindow")
  -- vim.fn.execute("!" ..
  --   "xdotool search --onlyvisible --class Chromium windowfocus key F5" ..
  --   " && xdotool windowfocus " .. currentTerminalEmulator)

  vim.fn.execute("!" .. "xdotool search --onlyvisible --class Chromium  windowactivate windowfocus key F5")

  -- local window_id = vim.fn.system("wmctrl -l | grep -i 'Chromium' | head -n 1 | awk '{print $1}'")
  -- vim.fn.system("xdotool key --window " .. window_id .. " F5")
  -- vim.fn.system("xdotool windowactivate " .. window_id)

  print("Chrome tab reloaded")
end

vim.cmd [[
  nnoremap R :lua ReloadActiveChromeTab() <CR>
]]


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

function CopyCurrentFileRelativePathToClipboard()
  local relpath = vim.fn.expand("%")
  vim.fn.setreg("+", relpath)
  vim.api.nvim_command('echo "Relative path " | echohl String | echon "' .. relpath .. '" | echohl None | echon " copied to clipboard!"')
end


vim.cmd("command! CopyCurrentFileRelativePathToClipboard lua CopyCurrentFileRelativePathToClipboard()")

function CopyCurrentFileNameToClipboard()
  local filename = vim.fn.expand("%:t")
  local basename = filename:match("^[^%.]+") or filename
  vim.fn.setreg('"', basename)
  vim.api.nvim_command(
    'echo "Filename " | echohl Type | echon "' .. basename .. '" | echohl None | echon " copied to vim default copy register!"'
  )
end

vim.cmd("command! CopyCurrentFileNameToClipboard lua CopyCurrentFileNameToClipboard()")
