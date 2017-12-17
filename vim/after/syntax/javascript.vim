" syntax match jsCapitalizedVariable    contained  /\%(\%(^\|[^.]\)\.\s*\)\@<!\<\u\%(\w\|[^\x00-\x7F]\)*\>\%(\s*(\)\@!/
syntax match jsCapitalizedVariable      /\<[A-Z]\k*/
syntax match jsCapitalizedVariable      /\.[A-Z]\k*/

syntax keyword jsImport      import skipwhite skipempty nextgroup=jsCapitalizedVariable,jsModuleAsterisk,jsModuleKeyword,jsModuleGroup,jsFlowImportType
syntax cluster jsAll         contains=@jsExpression,jsStorageClass,jsConditional,jsRepeat,jsReturn,jsException,jsTry,jsNoise,jsBlockLabel
syntax match   jsCont        contained /\.container/
syntax keyword jsFrom        from
syntax cluster jsAll         contains=@jsExpression,jsStorageClass,jsConditional,jsRepeat,jsReturn,jsException,jsTry,jsNoise,jsBlockLabel,jsCapitalizedVariable,jsCont,jsFrom
syntax region  jsClassValue  contained start=/=/ end=/\_[;}]\@=/ contains=@jsExpression,jsCapitalizedVariable

syntax region  jsObject      contained matchgroup=jsObjectBraces start=/{/  end=/}/  contains=jsObjectKey,jsObjectKeyString,jsObjectKeyComputed,jsObjectSeparator,jsObjectFuncName,jsObjectMethodType,jsGenerator,jsComment,jsObjectStringKey,jsSpreadExpression,jsDecorator,jsAsyncKeyword,jsCapitalizedVariable extend fold
syntax region  jsClassBlock  contained matchgroup=jsClassBraces  start=/{/  end=/}/  contains=jsClassFuncName,jsClassMethodType,jsArrowFunction,jsArrowFuncArgs,jsComment,jsGenerator,jsDecorator,jsClassProperty,jsClassPropertyComputed,jsClassStringKey,jsAsyncKeyword,jsNoise,jsCapitalizedVariable extend fold

" highlight def link  jsImport   Type
highlight def link jsCapitalizedVariable  Type
" highlight def link jsFrom  Include

" call one#highlight('Normal', 'e06c75', '', 'none')
"  def link jsExport               Statement
" hi def link jsFrom                 Statement
" hi def link jsExportDefault        Statement
" hi def link jsExportDefaultGroup   Statement
call one#highlight('jsClassMethodType', 'c678dd', '', 'none')

call one#highlight('jsImport', 'c678dd', '', 'none')
call one#highlight('jsFrom', 'c678dd', '', 'none')
call one#highlight('jsExport', 'c678dd', '', 'none')
call one#highlight('jsExportDefault', 'c678dd', '', 'none')

call one#highlight('jsClassDefinition', 'e5c07b', '', 'none')
call one#highlight('jsClassKeyword', 'c678dd', '', 'none')
