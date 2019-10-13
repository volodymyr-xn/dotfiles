syntax match rubyBindingPry /binding\.pry/
syntax match rubyNewConstructorMethod /.new(/
syntax match rubySaveConstructorMethod /.save(/
syntax match rubyCreateConstructorMethod /.create(/
syntax match rubyPerformInMethod /.perform_in(/
syntax match rubyPerformAsyncMethod /.perform_async(/
syntax match rubyDestroyMethod /.destroy(/
syntax match rubyDeleteAllMethod /.delete_all(/
syntax match rubyUpdateMethod /.update(/
syntax match rubyUpdateAllMethod /.update_all(/

hi def link rubyBindingPry Function
hi def link rubyNewConstructorMethod Function
hi def link rubySaveConstructorMethod Function
hi def link rubyCreateConstructorMethod Function
hi def link rubyPerformInMethod Function
hi def link rubyPerformAsyncMethod Function
hi def link rubyDestroyMethod Function
hi def link rubyDeleteAllMethod Function
hi def link rubyUpdateMethod Function
hi def link rubyUpdateAllMethod Function

" hi! link rubySymbol Special
hi! link rubyStringDelimiter Special

let s:bcs = b:current_syntax
unlet b:current_syntax
syntax include @SQL syntax/sql.vim

" this unlet instruction is needed
" " before we load each new syntax
unlet b:current_syntax
syntax include @SHELL syntax/sh.vim

let b:current_syntax = s:bcs

"syntax region hereDocText matchgroup=Statement
"start=+<<[-~.]*\z([A-Z]\+\)+ end=+^\s*\z1+ contains=NONE

syntax region hereDocDashSQL matchgroup=Statement start=+<<[-~.]*\z(SQL\)+  end=+^\s*\z1+ contains=@SQL
syntax region hereDocDashShell matchgroup=Statement start=+<<[-~.]*\z(SHELL\)+  end=+^\s*\z1+ contains=@SHELL

" Extensions from one-dark
hi! link rubyBlock                     Statement
hi! link rubyBlockParameter            Statement
hi! link rubyBlockParameterList        Special
" hi! link rubyCapitalizedMethod         Statement
" hi! link rubyConstant                  Type
" hi! link rubyClass                     Statement
" hi link rubyControl                   Statement
" hi link rubyDefine                    Statement
" hi link rubyEscape                    Special
" hi link rubyFunction                  Function
" hi link rubyGlobalVariable            Special
" hi link rubyInclude                   Function
" hi link rubyIncluderubyGlobalVariable Special
" hi link rubyInstanceVariable          Special
" hi link rubyInterpolation             Include
" hi link rubyInterpolationDelimiter    Special
" hi link rubyKeyword                   Function
" hi link rubyModule                    Statement
" hi link rubyPseudoVariable            Special
" hi link rubyRegexp                    Include
" hi link rubyRegexpDelimiter           Include
hi! link rubyStringDelimiter           Include
" hi! link rubySymbol                    Include
