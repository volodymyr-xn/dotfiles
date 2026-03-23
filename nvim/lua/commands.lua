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
    -- Detect OS
  local sysname = vim.loop.os_uname().sysname

  -- ANSI escape codes for purple text
  local purple = "\27[35m"
  local reset = "\27[0m"

  local success = false

  if sysname == "Linux" then
    -- Linux: use xdotool
    vim.fn.system("xdotool search --onlyvisible --class Chromium windowactivate windowfocus key F5")
    if vim.v.shell_error == 0 then
      success = true
    end

  elseif sysname == "Darwin" then
    -- macOS: use AppleScript via osascript
    local applescript = [[
      osascript -e '
        tell application "Google Chrome"
          if (count of windows) > 0 then
            tell active tab of front window to reload
          end if
          activate
        end tell
      '
    ]]
    vim.fn.system(applescript)
    if vim.v.shell_error == 0 then
      success = true
    end
  end

  if success then
    vim.api.nvim_echo({{"Chrome tab reloaded ✅", "Keyword"}}, false, {})
  else
    print("Error reloading chrome tab ✅")
  end
end

-- Reload active Chrome tab
vim.keymap.set("n", "R", ReloadActiveChromeTab, { silent = true, desc = "Reload active Chrome tab" })


function ToggleCurrentWindowZoom()
  if vim.g.currentWindowZoomed == nil then
    vim.g.currentWindowZoomed = false
  end

  if vim.g.currentWindowZoomed then
    vim.cmd("wincmd =")
    vim.g.currentWindowZoomed = false
  else
    vim.cmd("Neotree close")
    vim.cmd("wincmd |")
    vim.cmd("wincmd _")
    vim.g.currentWindowZoomed = true
  end
end

function CopyCurrentFileRelativePathToClipboard()
  -- local relpath = vim.fn.getcwd()
  -- vim.fn.setreg("+", relpath)

  -- vim.cmd("let @+ = @%")
  -- local relpath = vim.fn.getreg('+')
  -- vim.api.nvim_command('echohl Type | echo "Path ' .. clipboard_content .. ' copied!" | echohl None')
    -- Try git root, fallback to cwd
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error ~= 0 then
    git_root = vim.fn.getcwd()
  end

  local filepath = vim.fn.expand("%:p")
  local relpath = filepath
  if filepath:sub(1, #git_root) == git_root then
    relpath = filepath:sub(#git_root + 2)
  end

  -- Copy to clipboard
  vim.fn.setreg("+", relpath)

  vim.api.nvim_command('echohl String | echon "' .. relpath .. '" | echohl None | echon " copied!"')
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
