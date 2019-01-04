syntax match rubyBindingPry /binding\.pry/
syntax match rubyNewConstructorMethod /.new(/
syntax match rubySaveConstructorMethod /.save(/
syntax match rubyCreateConstructorMethod /.create(/
syntax match rubyPerformInMethod /.perform_in(/
syntax match rubyPerformAsyncMethod /.perform_async(/

highlight def link rubyBindingPry Function
highlight def link rubyNewConstructorMethod Function
highlight def link rubySaveConstructorMethod Function
highlight def link rubyCreateConstructorMethod Function
highlight def link rubyPerformInMethod Function
highlight def link rubyPerformAsyncMethod Function

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

