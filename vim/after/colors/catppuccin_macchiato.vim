" Catppuccin Macchiato overrides — mirrors nvim/lua/colors.lua
" (catppuccin/nvim color_overrides + custom_highlights + italic comments).
"
" Loaded automatically by Vim after the upstream
" colors/catppuccin_macchiato.vim, via the runtimepath `after/` hook.
"
" Palette differences from upstream macchiato:
"   text   #cad3f5 -> #ffffff (pure white)
"   peach  #f5a97f -> #F5B07F
"   mauve  #c6a0f6 -> #C69FF6 (nvim setup calls this "violet")
"   base   #24273a -> #212433 (slightly bluer/darker)

" --- Surfaces ----------------------------------------------------------
highlight Normal       guifg=#ffffff guibg=#212433 ctermbg=NONE
highlight NormalNC     guifg=#ffffff guibg=#212433
highlight NormalFloat  guifg=#ffffff guibg=#212433
highlight SignColumn   guibg=#212433
highlight LineNr       guibg=#212433
highlight CursorLineNr guibg=#212433
highlight EndOfBuffer  guibg=#212433
highlight VertSplit    guibg=#212433
highlight WinSeparator guibg=#212433
highlight FoldColumn   guibg=#212433

" Slightly darker chrome to separate from Normal.
highlight StatusLine   guibg=#1e2030
highlight StatusLineNC guibg=#1e2030
highlight TabLine      guibg=#1e2030
highlight TabLineFill  guibg=#1e2030
highlight Pmenu        guibg=#1e2030

" --- Italic comments (matches catppuccin nvim styles.comments) ---------
highlight Comment      cterm=italic gui=italic

" --- Peach repaint (constants, numbers, special tokens) ----------------
highlight Constant     guifg=#F5B07F
highlight Number       guifg=#F5B07F
highlight Float        guifg=#F5B07F
highlight Boolean      guifg=#F5B07F
highlight Special      guifg=#F5B07F

" --- Mauve / violet repaint (keywords, types, control flow) -----------
highlight Statement    guifg=#C69FF6
highlight Conditional  guifg=#C69FF6
highlight Repeat       guifg=#C69FF6
highlight Label        guifg=#C69FF6
highlight Keyword      guifg=#C69FF6
highlight Type         guifg=#C69FF6
highlight StorageClass guifg=#C69FF6
highlight Structure    guifg=#C69FF6
highlight PreProc      guifg=#C69FF6
highlight Include      guifg=#C69FF6
highlight Define       guifg=#C69FF6
highlight Macro        guifg=#C69FF6

" --- Matching paren — keep peach accent on the highlight match --------
highlight MatchParen   guibg=#363a4f guifg=#F5B07F gui=bold
