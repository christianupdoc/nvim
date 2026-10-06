; extends

; Colour the "key" side of key/value pairs, which the base query leaves as
; @variable (== Normal fg, i.e. grey). Remap to @property for a distinct colour.

; datasource / generator config keys (provider, url, ...)
(variable) @property

; model / view / type field names (id, email, ...)
(column_declaration
  (identifier) @property)
