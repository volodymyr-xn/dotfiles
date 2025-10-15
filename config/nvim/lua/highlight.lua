vim.cmd [[
  hi! link Macro Statement
  hi! link TabLineSel Function
  hi! link Todo Type
  hi! link todo Type
  hi NonText guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
  hi SpecialKey guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE

  " hi CursorColumn guifg=#bebebe ctermfg=238 guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
  hi! link Search TermCursor


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
--
--
vim.opt.fillchars = {
  horiz = "─",
  horizup = "┴",
  horizdown = "┬",
  vert = "│",
  vertleft = "┤",
  vertright = "├",
  verthoriz = "┼",
}
vim.cmd("hi! WinSeparator guifg=#89b4fa")
vim.cmd("hi! VertSplit guifg=#89b4fa")
-- WinSeparator   xxx guifg=#181926
-- VertSplit      xxx guifg=#181926

-- Custom highlight function
-- Requires vim 'set termguicolors'
-- vim.cmd [[
-- ]]

-- Custom highlight function with italic text
-- Requires vim 'set termguicolors'
-- vim.cmd [[
-- ]]
