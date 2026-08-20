" Orange return types in D function declarations.
"
" Neovim gets this from the treesitter query in after/queries/d/highlights.scm,
" which knows where a declaration actually starts; this file is the classic-vim
" approximation and would only fight it.
if has('nvim')
  finish
endif

" A `syn match` cannot win here: vim's d.vim lists `string`, `int` and friends
" as `syn keyword dType`, and keywords outrank matches at the same position
" whatever order they are defined in. matchadd() draws above the syntax layer
" instead, which is also how the ruby method highlights in
" nvim/lua/plugin_settings/treesitter.lua are done.

" Storage classes and attributes that may sit between the start of the line and
" the return type. Consumed before \zs so they keep their own colour.
let s:attributes = '%(%(private|protected|public|package|export|static|final|override|abstract|deprecated|nothrow|pure|shared|__gshared|extern\s*\([^)]*\)|extern|[@]\w+)\s+)*'

" Statement keywords that would otherwise read as a type: `return foo(...)` has
" the same shape as `string text(...)` to a regex.
let s:not_keyword = '%(%(return|if|else|while|do|for|foreach|foreach_reverse|switch|case|default|break|continue|goto|with|scope|try|catch|finally|throw|assert|cast|new|delete|mixin|import|module|version|debug|unittest|struct|class|union|interface|enum|alias|template|typeof|synchronized|invariant|is|super)>)@!'

" A type expression: either a qualifier applied to a parenthesised type
" (`const(char)`) or a dotted name with optional `!` template arguments,
" followed by any number of array or pointer suffixes.
let s:type = '%(%(const|immutable|inout|shared)\s*\([^)]*\)|\h\w*%(\.\h\w*)*%(!%(\([^)]*\)|\h\w*))?)%(\[\]|\[\h\w*\]|\*)*'

" What follows the return type: the function name, its optional template
" parameter list, and the opening paren of the real parameter list.
let s:declaration = '\s+\h\w*%(\([^)]*\))?\s*\('

let s:pattern = '\v^\s*' . s:attributes . '\zs' . s:not_keyword . s:type . '\ze' . s:declaration

" Peach, matching the catppuccin palette override in nvim/lua/colors.lua.
highlight default dReturnType guifg=#F5B07F ctermfg=216

call matchadd('dReturnType', s:pattern, 200)
