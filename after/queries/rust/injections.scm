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

; Inject SQL when string literal is arg of a function/method whose name contains "sql"
; e.g. query.push_sql(r#"..."#), sqlx::query("..."), execute_sql("...")
(
  (call_expression
    function: [
      (identifier) @_fn
      (scoped_identifier name: (identifier) @_fn)
      (field_expression field: (field_identifier) @_fn)
      (generic_function function: (identifier) @_fn)
      (generic_function function: (scoped_identifier name: (identifier) @_fn))
      (generic_function function: (field_expression field: (field_identifier) @_fn))
    ]
    arguments: (arguments
      [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content)
      ]))
  (#match? @_fn "[sS][qQ][lL]")
  (#set! injection.language "sql")
  (#set! injection.include-children)
)

; Inject SQL when string literal assigned to a `let` binding whose name contains "sql"
; e.g. let sql = r#"..."#;  let my_sql_str = "...";
(
  (let_declaration
    pattern: (identifier) @_var
    value: [
      (raw_string_literal (string_content) @injection.content)
      (string_literal (string_content) @injection.content)
    ])
  (#match? @_var "[sS][qQ][lL]")
  (#set! injection.language "sql")
  (#set! injection.include-children)
)

; Inject SQL for const/static SQL = "..."
(
  [
    (const_item
      name: (identifier) @_var
      value: [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content)
      ])
    (static_item
      name: (identifier) @_var
      value: [
        (raw_string_literal (string_content) @injection.content)
        (string_literal (string_content) @injection.content)
      ])
  ]
  (#match? @_var "[sS][qQ][lL]")
  (#set! injection.language "sql")
  (#set! injection.include-children)
)
