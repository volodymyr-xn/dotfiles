; extends

(heredoc_body
  (heredoc_content) @injection.content
  (heredoc_end) @_end
  (#any-of? @_end "SH" "SHELL" "BASH" "ZSH" "sh" "shell" "bash" "zsh")
  (#set! injection.language "bash"))
