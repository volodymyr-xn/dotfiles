require("plugins_install")
require("general_settings")
require("plugins_require")
require("mappings")
require("autocommands")

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

 function ReloadActiveChromeTab()
  local currentTerminalEmulator = vim.fn.system("xdotool getactivewindow")

  vim.fn.execute("!" ..
    "xdotool search --onlyvisible --class Chrome windowfocus key F5" ..
    " && xdotool windowfocus " .. currentTerminalEmulator)

  print("Chrome tab reloaded")
end

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


-- Custom highlight function
-- Requires vim 'set termguicolors'
vim.cmd [[
  function! Highlight(group, color)
    exec "hi " a:group . " guifg=" . a:color
  endfunction
]]

-- Custom highlight function with italic text
-- Requires vim 'set termguicolors'
vim.cmd [[
  function! ItalicHighlight(group, color)
    exec "hi " a:group . " guifg=" . a:color . " gui=italic"
  endfunction
]]

-- ===================== Custom highlighting  ====================================
vim.cmd("hi! link TabLineSel Function")
vim.cmd("hi NonText guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")
vim.cmd("hi SpecialKey guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")
vim.g.vim_jsx_pretty_colorful_config = 1 -- default 0

-- ========================= Helper for vim snippets =======================
function Current_Filename(...)
  local template = select(1, ...) or "$1"
  local arg2 = select(2, ...) or ""

  local basename = vim.fn.expand('%:t:r')

  if basename == '' then
    return arg2
  else
    return vim.fn.substitute(template, '$1', basename, 'g')
  end
end
