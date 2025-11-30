; highlights.scm - Syntax highlighting queries for TOON
; Maps grammar nodes to standard Neovim highlight capture groups

; Keywords/Constants
(null) @constant.builtin
(true) @boolean
(false) @boolean

; Numbers
(number) @number
(integer) @number

; Strings
(quoted_string) @string
(escape_sequence) @string.escape
(unquoted_string) @string

; Keys and identifiers
(key (identifier) @property)
(key (dotted_key (identifier) @property))
(key (quoted_string) @property)
(field_name) @property

; Punctuation
":" @punctuation.delimiter
"," @punctuation.delimiter
"|" @punctuation.delimiter
"." @punctuation.delimiter

; Brackets
"[" @punctuation.bracket
"]" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket
"\"" @punctuation.special

; List marker
(list_marker) @punctuation.special

; Array header length
(array_header
  (integer) @number)

; Delimiter marker in array header
(delimiter_marker) @punctuation.delimiter
