; extends

; Inject HTML into raw string literals preceded by a `// html` comment
(
  (line_comment) @_comment
  .
  (raw_string_literal
    (string_content) @injection.content)
  (#match? @_comment "//\\s*html")
  (#set! injection.language "html")
  (#set! injection.include-children)
)

; Inject SQL into raw string literals preceded by a `// sql` comment
(
  (line_comment) @_comment
  .
  (raw_string_literal
    (string_content) @injection.content)
  (#match? @_comment "//\\s*sql")
  (#set! injection.language "sql")
  (#set! injection.include-children)
)
