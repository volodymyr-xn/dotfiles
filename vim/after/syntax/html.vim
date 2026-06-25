" Highlight custom elements / web components — tag names containing a hyphen.
" Per the HTML spec a valid custom-element name always contains a '-'
" (e.g. <dropdown-select-menu>).
"
" Vim's bundled html.vim wraps every tag name in an uncolored container group
" `htmlTagN`, then colors only KNOWN tags via `htmlTagName` keywords contained
" inside it. A custom element matches no keyword, so it falls through to bare
" `htmlTagN` (which has no highlight link) and renders as plain text. This adds
" a match inside `htmlTagN` so hyphenated names get their own distinct color.
"
" Sourced for `html` AND any syntax that does `runtime! syntax/html.vim`
" (eruby/.erb, php, etc.), so it works globally without per-filetype setup.

syntax match htmlCustomElement contained containedin=htmlTagN
      \ "\<[a-zA-Z][-.0-9a-zA-Z]*-[-.0-9a-zA-Z]*\>"

" Distinct from native tags so custom elements stand out. To color them the
" same as standard tags instead, link to htmlTagName.
highlight default link htmlCustomElement Special
