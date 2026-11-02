# Current Cwhip syntax

`src/lib/machine.cw` is included by every executable. `Machine.identity`
returns a managed `String` with `return(expression)`. The unit program
`src/unit_libIdentity.cw` captures that method in a `String<>` callable
and prints whether it equals `cplanets-lib`.

Callable types spell the result first, followed by parameter types:
`R<P1,P2>`, or `R<>` for no parameters. Capturing `machine.identity` does not
invoke the method; `identity()` invokes the captured method and retains its
receiver. Recursive callable types are supported. The former
`callback<R(P...)>` spelling is no longer a type; `callback` is an ordinary
identifier.

Cwhip stages each program from the directory of its `SOURCE` file, so unit
programs that include `lib/` live under `src/` (see `src/unit_libIdentity.cw`).
CTest wrappers live in `tests/unit/`.

## Migration checklist

- Use `#`, `//`, or `/* ... */` for comments. Semicolons are not Cwhip comments
  or statement separators; leave semicolons in native/inline C unchanged.
- Dictionaries use `[key: value]`, including multiline entries and trailing
  commas. `[:]` is an empty dictionary; `[]` is an empty list. Lists also
  support multiline entries and trailing commas.
- Return a value with `return(expression)`. Bare `return` and `return()` are
  void returns. Use `raise(expression)` or `raise()` to rethrow, and put
  keyword parameters in parentheses, such as `if (condition)` and
  `for (item in items)`.
- Conditional chains use `if (condition) { ... } else (condition) { ... }`
  followed by an optional final `else { ... }`, not `else if`.
- Bitwise operators bind more tightly than comparisons, in the order shifts,
  `&`, `^`, `|`, then comparisons. Write `(flags & mask) == expected` for an
  explicit bitmask test. Audit mixed expressions and use parentheses to
  preserve the intended grouping.
- Prefer explicit-width numeric types when widths matter. `int`, `uint`, and
  `float` are aliases for `int32`, `uint32`, and `fp32`, not their old 64-bit
  meanings. `unsigned` is reserved. See [Building](BUILDING.md#numeric-v2-migration)
  for numeric and native-package migration.
- Class fields may have compile-time constant initializers. Keywords are
  case-insensitive; the skeleton uses lowercase keywords consistently.
  `and`/`&&`, `or`/`||`, and `not`/`!` are equivalent spellings.
