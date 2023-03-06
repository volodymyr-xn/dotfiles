vim.cmd [[
  hi! link Macro Statement
]]

vim.cmd("hi! link TabLineSel Function")
vim.cmd("hi NonText guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")
vim.cmd("hi SpecialKey guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")

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
