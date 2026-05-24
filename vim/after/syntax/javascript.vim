"*****************************************************************
"********* KEYWORDS AND MATCHES **********************************
"*****************************************************************
"*****************************************************************

syntax match jsCapitalizedVariable  /\<[A-Z]\k*/
" syntax match jsCapitalizedVariable  /\s?[A-Z]\k*/
" syntax match jsCapitalizedVariable  /\.[A-Z]\k*/
" syntax match jsCapitalizedVariable    contained  /\%(\%(^\|[^.]\)\.\s*\)\@<!\<\u\%(\w\|[^\x00-\x7F]\)*\>\%(\s*(\)\@!/

" Overide jsFrom
syntax keyword jsFrom from

syntax keyword jsThis this

" Instantiate class
syntax match jsInstantiateClass /\(new\)\@<=\s[A-Z]\w\+\(\(\)\)\@=/

" Overide jsVariableDef default pattern from /\<\K\k*/ to /\k*/
syntax match   jsVariableDef  contained /\k*/ skipwhite skipempty nextgroup=jsFlowDefinition

" TODO
exe 'syntax match jsArrowFunctionDeclaration /\w\+\(\s=\s(.*)\ze\s*=>\)\@=/  skipwhite skipempty nextgroup=jsArrowFuncArgs '.(exists('g:javascript_conceal_arrow_function') ? 'conceal cchar='.g:javascript_conceal_arrow_function : '')

"*****************************************************************
"********** CLUSTERS AND REGIONS *********************************
"*****************************************************************
"*****************************************************************

syntax cluster jsExpression
      \ contains=jsBracket,jsParen,jsObject,jsTernaryIf,jsTaggedTemplate,jsTemplateString,jsString,jsRegexpString,jsNumber,jsFloat,jsOperator,jsOperatorKeyword,jsBooleanTrue,jsBooleanFalse,jsNull,jsFunction,jsArrowFunction,jsArrowFunctionDeclaration,jsGlobalObjects,jsExceptions,jsFutureKeys,jsDomErrNo,jsDomNodeConsts,jsHtmlEvents,jsInstantiateClass,jsFuncCall,jsUndefined,jsNan,jsPrototype,jsBuiltins,jsNoise,jsClassDefinition,jsArrowFunction,jsArrowFunctionDeclaration,jsArrowFuncArgs,jsParensError,jsComment,jsArguments,jsThis,jsSuper,jsDo,jsForAwait,jsAsyncKeyword,jsStatement,jsDot

syntax keyword jsImport
      \ import skipwhite skipempty nextgroup=jsCapitalizedVariable,jsModuleAsterisk,jsModuleKeyword,jsModuleGroup,jsFlowImportType


syntax region  jsModuleGroup
      \ contained matchgroup=jsModuleBraces  start=/{/ end=/}/
      \ contains=jsModuleKeyword,jsModuleComma,jsModuleAs,jsComment,jsFlowTypeKeyword,jsCapitalizedVariable skipwhite skipempty nextgroup=jsFrom fold

syntax cluster jsAll
      \ contains=@jsExpression,jsInstantiateClass,jsStorageClass,jsConditional,jsRepeat,jsReturn,jsException,jsTry,jsNoise,jsBlockLabel,jsCapitalizedVariable,jsCont,jsFrom

syntax region jsClassValue
      \ contained start=/=/ end=/\_[;}]\@=/ contains=@jsExpression,jsCapitalizedVariable

syntax region jsObject
      \ contained matchgroup=jsObjectBraces
      \ start=/{/  end=/}/
      \ contains=jsObjectKey,jsObjectKeyString,jsObjectKeyComputed,jsObjectSeparator,jsObjectFuncName,jsObjectMethodType,jsGenerator,jsComment,jsObjectStringKey,jsSpreadExpression,jsDecorator,jsAsyncKeyword,jsCapitalizedVariable extend fold

syntax region jsClassBlock
      \ contained matchgroup=jsClassBraces
      \ start=/{/  end=/}/
      \ contains=jsClassFuncName,jsClassMethodType,jsArrowFunction,jsArrowFunctionDeclaration,jsArrowFuncArgs,jsComment,jsGenerator,jsDecorator,jsClassProperty,jsClassPropertyComputed,jsClassStringKey,jsAsyncKeyword,jsNoise,jsCapitalizedVariable extend fold
" syntax region jsFuncArgExpression    contained matchgroup=jsFuncArgOperator start=/=/ end=/[,)]\@=/ contains=@jsExpression,jsCapitalizedVariable extend

" Add ability to match jsCapitalidedVariable inside function call
syntax region jsParenIfElse
      \ contained matchgroup=jsParensIfElse
      \ start=/(/  end=/)/
      \ contains=@jsAll,jsCapitalizedVariable skipwhite skipempty nextgroup=jsCommentIfElse,jsIfElseBlock

syntax region jsFuncArgs
      \ contained matchgroup=jsFuncParens
      \ start=/(/  end=/)/
      \ contains=jsFuncArgCommas,jsComment,jsFuncArgExpression,jsDestructuringBlock,jsDestructuringArray,jsRestExpression,jsFlowArgumentDef,jsCapitalizedVariable skipwhite skipempty nextgroup=jsCommentFunction,jsFuncBlock,jsFlowReturn,jsCapitalizedVariable extend fold

syntax cluster jsExpression  contains=jsBracket,jsParen,jsObject,jsTernaryIf,jsTaggedTemplate,jsTemplateString,jsString,jsRegexpString,jsNumber,jsFloat,jsOperator,jsOperatorKeyword,jsBooleanTrue,jsBooleanFalse,jsNull,jsFunction,jsArrowFunction,jsArrowFunctionDeclaration,jsGlobalObjects,jsExceptions,jsFutureKeys,jsDomErrNo,jsDomNodeConsts,jsHtmlEvents,jsFuncCall,jsUndefined,jsNan,jsPrototype,jsBuiltins,jsNoise,jsClassDefinition,jsArrowFunction,jsArrowFunctionDeclaration,jsArrowFuncArgs,jsParensError,jsComment,jsArguments,jsThis,jsSuper,jsDo,jsForAwait,jsAsyncKeyword,jsStatement,jsDot,jsCapitalizedVariable


"*****************************************************************
"****************** HIGHLIGHTING *********************************
"*****************************************************************
"*****************************************************************

hi def link jsCapitalizedVariable Type
hi def link jsObjectKeyComputed Type
hi def link jsInstantiateClass Type

" call Highlight('Normal', g:custom_color_regular)

" call Highlight('jsNoise', g:custom_color_noise)
hi! link jsNoise NonText

" call Highlight('Noises', g:custom_color_noise)
hi! link Noises NonText

" call Highlight('jsFuncParens', g:custom_color_noise)
hi! link jsFuncParens NonText

" call Highlight('jsFuncBraces', g:custom_color_noise)
hi! link jsFuncBraces NonText

" call Highlight('jsClassBraces', g:custom_color_noise)
hi! link jsClassBraces NonText

" call Highlight('jsDot', g:custom_color_noise)
hi! link jsDot NonText

" call Highlight('jsModuleAs', g:custom_color_statement)
hi! link jsModuleAs Statement

" call Highlight('jsClassMethodType', g:custom_color_statement)
hi! link jsClassMethodType Statement

" call Highlight('jsImport', g:custom_color_statement)
hi! link jsImport Statement

" call Highlight('jsFrom',g:custom_color_statement)
hi! link jsFrom Statement

" call Highlight('jsExport', g:custom_color_statement)
hi! link jsExport Statement
hi! link jsExportDefault Statement
hi! link jsExportDefaultGroup Statement

" call Highlight('jsClassDefinition', g:custom_color_type)
hi! link jsClassDefinition Type

" call Highlight('jsClassKeyword', g:custom_color_statement)
hi! link jsClassKeyword Statement

" call Highlight('jsClassKeyword', g:custom_color_statement)
hi! link jsClassKeyword Statement

" call Highlight('jsConstant', g:custom_color_type)
hi! link jsConstant Type

" call Highlight('jsObjectKeyComputed', g:custom_color_statement)
hi! link jsObjectKeyComputed Statement

" call Highlight('jsExtendsKeyword', g:custom_color_statement)
hi! link jsExtendsKeyword Statement

" call Highlight('jsArrowFunctionDeclaration', g:custom_color_special)
hi! link jsArrowFunctionDeclaration Special

hi jsThis gui=italic cterm=italic guifg=#e5c07b
" call ItalicHighlight('jsThis', g:custom_color_character)

augroup html_in_js
  autocmd!
  autocmd FileType javascript syn region jsTemplateString matchgroup=jsStringDelimiter start=+`\ze[^\n]*`+ end=+`\ze[^\n]*`+ contains=htmlTag,htmlString
  autocmd FileType javascript syn region htmlTag contained matchgroup=htmlDelimiter start=+<+ end=+>+
  autocmd FileType javascript syn region htmlString contained matchgroup=htmlStringDelimiter start=+"+ end=+"+ contains=htmlTag
augroup END
