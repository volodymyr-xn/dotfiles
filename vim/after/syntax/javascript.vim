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

" Instantiate class
syntax match jsInstantiateClass /\(new\)\@<=\s[A-Z]\w\+\(\(\)\)\@=/

" Overide jsVariableDef default pattern from /\<\K\k*/ to /\k*/
syntax match   jsVariableDef  contained /\k*/ skipwhite skipempty nextgroup=jsFlowDefinition

"*****************************************************************
"********** CLUSTERS AND REGIONS *********************************
"*****************************************************************
"*****************************************************************

syntax cluster jsExpression
      \ contains=jsBracket,jsParen,jsObject,jsTernaryIf,jsTaggedTemplate,jsTemplateString,jsString,jsRegexpString,jsNumber,jsFloat,jsOperator,jsOperatorKeyword,jsBooleanTrue,jsBooleanFalse,jsNull,jsFunction,jsArrowFunction,jsGlobalObjects,jsExceptions,jsFutureKeys,jsDomErrNo,jsDomNodeConsts,jsHtmlEvents,jsInstantiateClass,jsFuncCall,jsUndefined,jsNan,jsPrototype,jsBuiltins,jsNoise,jsClassDefinition,jsArrowFunction,jsArrowFuncArgs,jsParensError,jsComment,jsArguments,jsThis,jsSuper,jsDo,jsForAwait,jsAsyncKeyword,jsStatement,jsDot

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
      \ contains=jsClassFuncName,jsClassMethodType,jsArrowFunction,jsArrowFuncArgs,jsComment,jsGenerator,jsDecorator,jsClassProperty,jsClassPropertyComputed,jsClassStringKey,jsAsyncKeyword,jsNoise,jsCapitalizedVariable extend fold
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

syntax cluster jsExpression  contains=jsBracket,jsParen,jsObject,jsTernaryIf,jsTaggedTemplate,jsTemplateString,jsString,jsRegexpString,jsNumber,jsFloat,jsOperator,jsOperatorKeyword,jsBooleanTrue,jsBooleanFalse,jsNull,jsFunction,jsArrowFunction,jsGlobalObjects,jsExceptions,jsFutureKeys,jsDomErrNo,jsDomNodeConsts,jsHtmlEvents,jsFuncCall,jsUndefined,jsNan,jsPrototype,jsBuiltins,jsNoise,jsClassDefinition,jsArrowFunction,jsArrowFuncArgs,jsParensError,jsComment,jsArguments,jsThis,jsSuper,jsDo,jsForAwait,jsAsyncKeyword,jsStatement,jsDot,jsCapitalizedVariable


"*****************************************************************
"****************** HIGHLIGHTING *********************************
"*****************************************************************
"*****************************************************************

let s:regular_red = '#e06c75'
let s:secondary_red = '#be5046'
let s:regual_gray_text = 'gray'
let s:purple = '#c678dd'
let s:yellow = '#e5c07b'

hi def link jsCapitalizedVariable Type
hi def link jsObjectKeyComputed Type
hi def link jsInstantiateClass Type

call Highlight('jsNoise', s:regual_gray_text)
call Highlight('Noises', s:regual_gray_text)
call Highlight('jsFuncParens', s:regual_gray_text)
call Highlight('jsFuncBraces', s:regual_gray_text)
call Highlight('jsClassBraces', s:regual_gray_text)
call Highlight('jsDot', s:regual_gray_text)

call Highlight('jsModuleAs', s:purple)

call Highlight('Normal', s:regular_red)

call Highlight('jsClassMethodType', s:purple)

call Highlight('jsImport', s:purple)
call Highlight('jsFrom',s:purple)
call Highlight('jsExport', s:purple)
call Highlight('jsExportDefault', s:purple)
" hi def link jsExportDefaultGroup   Statement TODO

call Highlight('jsClassDefinition', s:yellow)
call Highlight('jsClassKeyword', s:purple)
call Highlight('jsClassKeyword', s:purple)
call Highlight('jsConstant', s:yellow)

call Highlight('jsObjectKeyComputed', s:purple)
call Highlight('jsExtendsKeyword', s:purple)
