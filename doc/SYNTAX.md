# Current Cwhip syntax

`src/lib/machine.cw` is included by every executable. `Machine.identity`
returns a managed `String` with `return(expression)`. The unit program
`src/unit_libIdentity.cw` captures that method in a `String<>` callable
and prints whether it equals `cplanets-lib`.

Phase B adds scenario/state helpers beside that identity stub:
`rng.cw`, `scenario.cw`, `setupParse.cw`, `planet.cw`, `player.cw`,
`galaxy.cw`, and `state.cw`. Setup text is application `key = value`
lines (not a stdlib format); see `scenarios/closed-default.setup`.
Unit programs `unit_rng`, `unit_scenarioFixture`, `unit_setupLoad`,
`unit_galaxyStart`, and `unit_empirePools` print a bool line like
`unit_libIdentity`.

Phase C adds tick-core modules: `design.cw`, `fleet.cw`, `event.cw`,
`travel.cw`, `production.cw`, `dispatch.cw`, `recall.cw`, `motion.cw`,
and `tick.cw` (plus `state.cw` tick entry). Unit programs
`unit_travel`, `unit_production`, `unit_dispatch`,
`unit_recallCancel`, `unit_stranded`, and function program
`fn_tickCore` also print a bool line. CTest wrappers for fn programs
live under `tests/fn/`.

Phase D1 adds take/combat modules: `engagement.cw`, `combat.cw`,
`take.cw` (plus planet `satelliteDefense` and fleet
`pendingArrivalOrder`). Unit program `unit_combat` and function
program `fn_takeColony` print a bool line.

Phase D2 adds trade modules: `agreement.cw`, `tradeArrive.cw` (plus
freighter/escort designs, fleet trade fields, state propose/accept/
issueTrade). Unit programs `unit_agreement`, `unit_tradeHold` and
function program `fn_tradeAgreements` print a bool line.

Phase D3 adds pirate/identify modules: `identify.cw`, `midpoint.cw`
(plus fleet ambush/loot fields, `issueAmbush`, motion loot credit).
Unit programs `unit_identify`, `unit_ambushHalf` and function
program `fn_pirateIdentify` print a bool line.

Phase D4 adds combat/design reclaim modules: `screen.cw`,
`confiscate.cw` (plus ReclaimJob, engagement participants,
`queueDesignDevelop` / `queueReclaim`). Unit program `unit_screen`
and function program `fn_combatDesigns` print a bool line.

Phase D5 adds contact/end modules: `contact.cw`, `endgame.cw`
(plus player partition / knownCompetitors / quit-drop flags,
planet `partitionId`, sandbox homes). Unit programs
`unit_contact`, `unit_endgame` and function program
`fn_contactEnd` print a bool line.

Callable types spell the result first, followed by parameter types:
`R<P1,P2>`, or `R<>` for no parameters. Capturing `machine.identity` does not
invoke the method; `identity()` invokes the captured method and retains its
receiver. Recursive callable types are supported. The former
`callback<R(P...)>` spelling is no longer a type; `callback` is an ordinary
identifier.

Cwhip stages each program from the directory of its `SOURCE` file, so unit
programs that include `lib/` live under `src/` (see `src/unit_libIdentity.cw`).
CTest wrappers live in `tests/unit/`.

Multi-line method parameter lists must keep `) {` on the same line; a
bare `)` line followed by `{` on the next line fails to parse. `range`
is a reserved type constructor — do not use it as a parameter or local
name. Unsuffixed float literals are `fp32`; compare `fp64` fields with
`0.4f64`-style literals.

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
