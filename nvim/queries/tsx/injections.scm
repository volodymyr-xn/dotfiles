; Inject HTML into template strings
((template_string) @injection.content
 (#set! injection.language "html")
 (#set! injection.include-children))

; Also support tagged template literals with html tag
((call_expression
  function: (identifier) @_name
  arguments: (template_string) @injection.content)
 (#eq? @_name "html")
 (#set! injection.language "html")
 (#set! injection.include-children))
