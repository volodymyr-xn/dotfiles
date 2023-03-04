"" CUSTOM
" OLD WAVIANT syn match jsxComponentTagName /[A-Z]\w\+/ display contained contains=xmlNamespace,xmlAttribPunct,@xmlTagHook
syn match jsxComponentTagName /[A-Z]\w\+/ display contained
syn match jsxComponentTagName /\/[A-Z]\w\+/ display contained

" Add support of jsxComponentTagName to xmlEndTag
syn match xmlEndTag
      \ +</[^ /!?<>"']\+>+
      \ contained
      \ contains=xmlTagName,jsxComponentTagName,xmlNamespace,xmlAttribPunct,@xmlTagHook


"" OVERIDER xmlTag region
"" Represents "Start tag"
"" added jsxComponentTagName to contains
syn region  xmlTag
	\ matchgroup=xmlTag start=+<[^ /!?<>"']\@=+
	\ matchgroup=xmlTag end=+>+
	\ contained
	\ contains=xmlError,xmlTagName,jsxComponentTagName,xmlAttrib,xmlEqual,xmlString,@xmlStartTagHook

" TODO
" syn region jsxRegion
"   \
"   contains=@Spell,@XMLSyntax,jsxRegion,jsxChild,jsBlock,javascriptBlock,jsxComponentTagName
"   \ start=+\%(<\|\w\)\@<!<\z([a-zA-Z_][a-zA-Z0-9:\-.]*\>[:,]\@!\)\([^>]*>(\)\@!+
"   \ skip=+<!--\_.\{-}-->+
"   \ end=+</\z1\_\s\{-}>+
"   \ end=+/>+
"   \ keepend
"   \ extend

" JSX EXPERIMENT: better React component name highlight
hi def link jsxComponentTagName Type

" JSX EXPERIMENT: better React component attribute highlight
hi xmlAttrib term=italic cterm=italic gui=italic guifg=#d19a66
