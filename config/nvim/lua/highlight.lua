vim.cmd [[
  hi! link Macro Statement
  hi! link TabLineSel Function
  hi! link Todo Type
  hi! link todo Type
  hi NonText guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
  hi SpecialKey guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE


  function! Highlight(group, color)
    exec "hi " a:group . " guifg=" . a:color
  endfunction

  function! ItalicHighlight(group, color)
    exec "hi " a:group . " guifg=" . a:color . " gui=italic"
  endfunction
]]

-- vim.cmd("hi! link TabLineSel Function")
-- vim.cmd("hi NonText guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")
-- vim.cmd("hi SpecialKey guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE")

-- Custom highlight function
-- Requires vim 'set termguicolors'
-- vim.cmd [[
-- ]]

-- Custom highlight function with italic text
-- Requires vim 'set termguicolors'
-- vim.cmd [[
-- ]]
