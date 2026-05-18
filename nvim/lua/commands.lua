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

-- Reloads the active tab of the frontmost Chrome window and focuses it.
-- macOS delegates to bin/c-chrome-reload-work-tab; Linux falls back to
-- xdotool against any Chromium window.
function ReloadActiveChromeTab()
  local sysname = vim.loop.os_uname().sysname

  local cmd
  if sysname == "Darwin" then
    cmd = { "c-chrome-reload-work-tab" }
  elseif sysname == "Linux" then
    cmd = { "sh", "-c", "xdotool search --onlyvisible --class Chromium windowactivate windowfocus key F5" }
  else
    vim.api.nvim_echo({{"ReloadActiveChromeTab: unsupported OS " .. sysname, "ErrorMsg"}}, true, {})
    return
  end

  local output = vim.fn.system(cmd)
  local ok = vim.v.shell_error == 0

  if ok then
    vim.api.nvim_echo({{"Chrome work tab reloaded ✅", "Keyword"}}, false, {})
  else
    local msg = (output and output ~= "") and output or "unknown error"
    msg = msg:gsub("%s+$", "")
    vim.api.nvim_echo({{"Reload failed: " .. msg, "ErrorMsg"}}, true, {})
  end
end

-- Reload active Chrome tab in the "1 Work" profile
vim.keymap.set("n", "R", ReloadActiveChromeTab, { silent = true, desc = "Reload active Chrome work-profile tab" })


-- Returns true if a Neo-tree window is open in the current tab
local function neotree_is_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      return true
    end
  end
  return false
end

-- Returns true if the :Neotree user command is defined (plugin loaded)
local function neotree_command_exists()
  return vim.fn.exists(":Neotree") == 2
end

function ToggleCurrentWindowZoom()
  if vim.g.currentWindowZoomed == nil then
    vim.g.currentWindowZoomed = false
    vim.g.neotreeWasOpenBeforeZoom = false
  end

  if vim.g.currentWindowZoomed then
    vim.cmd("wincmd =")
    if vim.g.neotreeWasOpenBeforeZoom and neotree_command_exists() then
      vim.cmd("Neotree show")
    end
    vim.g.currentWindowZoomed = false
  else
    vim.g.neotreeWasOpenBeforeZoom = neotree_is_open()
    if neotree_command_exists() then
      vim.cmd("Neotree close")
    end
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

  CopyToClipboardAndNotify(relpath)
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
