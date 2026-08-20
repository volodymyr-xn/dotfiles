" SDLang (Simple Declarative Language) — the format used by dub.sdl.
" Not to be confused with the builtin `sdl` filetype, which is ITU-T SDL;
" `*.sdl` maps there by default, so lua/general_settings.lua remaps the dub
" filenames to `sdlang` instead.

if exists("b:current_syntax")
  finish
endif

syntax case match

syn keyword sdlangBoolean true false on off
syn keyword sdlangNull null

" Tag names open a statement: at the start of a line, or after `;` / `{` / `}`.
" The optional `ns:` prefix is picked out by sdlangNamespace.
syn match sdlangTag /^\s*\zs[A-Za-z_$][A-Za-z0-9_.$-]*\%(:[A-Za-z_$][A-Za-z0-9_.$-]*\)\?/
      \ contains=sdlangNamespace
syn match sdlangTag /[;{}]\s*\zs[A-Za-z_$][A-Za-z0-9_.$-]*\%(:[A-Za-z_$][A-Za-z0-9_.$-]*\)\?/
      \ contains=sdlangNamespace
syn match sdlangNamespace /[A-Za-z_$][A-Za-z0-9_.$-]*:/ contained

" Attribute keys — `key=value`, `ns:key=value`.
syn match sdlangAttribute /[A-Za-z_$][A-Za-z0-9_.$-]*\%(:[A-Za-z_$][A-Za-z0-9_.$-]*\)\?\ze\s*=/
      \ contains=sdlangNamespace
syn match sdlangOperator /=/

" Numbers with the optional SDLang width suffix (L/l long, f/F float,
" d/D double, BD/bd decimal).
syn match sdlangNumber /\%(\<\|-\)\d\+\%(\.\d\+\)\?\%([eE][+-]\?\d\+\)\?\%(BD\|bd\|[LlFfDd]\)\?\>/

" Date, time and datetime literals, incl. the `-UTC` / `-GMT+2` zone suffix
" and `d:hh:mm:ss.fff` durations.
syn match sdlangDate /\<\d\{4}\/\d\{1,2}\/\d\{1,2}\%(\s\+\d\{1,2}:\d\{2}\%(:\d\{2}\%(\.\d\+\)\?\)\?\%(-[A-Za-z/]\+\%([+-]\d\+\)\?\)\?\)\?/
syn match sdlangDate /\<\%(\d\+d:\)\?\d\{1,2}:\d\{2}:\d\{2}\%(\.\d\+\)\?/

syn match sdlangEscape /\\\%(["\\nrt]\|$\)/ contained
syn region sdlangString start=/"/ skip=/\\./ end=/"/ contains=sdlangEscape
syn region sdlangString start=/`/ end=/`/
syn region sdlangBinary start=/\[/ end=/\]/ contains=NONE

syn match sdlangBrace /[{}]/
syn match sdlangContinuation /\\$/

syn keyword sdlangTodo TODO FIXME NOTE XXX contained
syn match sdlangComment /\%(#\|--\|\/\/\).*$/ contains=sdlangTodo,@Spell
syn region sdlangComment start=/\/\*/ end=/\*\// contains=sdlangTodo,@Spell

hi def link sdlangTag Statement
hi def link sdlangNamespace Type
hi def link sdlangAttribute Identifier
hi def link sdlangOperator Operator
hi def link sdlangString String
hi def link sdlangEscape SpecialChar
hi def link sdlangBinary String
hi def link sdlangNumber Number
hi def link sdlangBoolean Boolean
hi def link sdlangNull Constant
hi def link sdlangDate Constant
hi def link sdlangBrace Delimiter
hi def link sdlangContinuation Special
hi def link sdlangComment Comment
hi def link sdlangTodo Todo

let b:current_syntax = "sdlang"
