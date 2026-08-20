; extends

; The return type of a function declaration, so it reads apart from the same
; type name used anywhere else. It is the `type` node sitting immediately
; before the function's name; parameter types are nested inside `(parameters)`
; and a variable's type inside `(variable_declaration)`, so neither matches.
;
; Captured as the whole `type` node rather than its inner identifier, which is
; what carries `[]`, `!(...)` template arguments and `const(...)` along with
; the base name.
(function_declaration
  (type) @type.return
  .
  (identifier))
