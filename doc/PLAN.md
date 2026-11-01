# End-to-end implementation plan

Working plan for building CPlanets against [RULES.md](RULES.md).
Rules win if this file disagrees on game behavior. This file wins on
**order of work, file shape, and tests**.

Estimates are **Cwhip source lines** (not comments-only, not CMake, not
Python harness). Ranges assume files stay **short and readable**: about
**80–180 lines per `.cw` file**, split when a file mixes two jobs.
Tests are **separate programs**, not assertions stuffed into production
files.

Cwhip `// test:` comments are good for **tiny** stdlib-style examples.
This app needs **named test programs** with a fixed seed and a printed
pass/fail line, plus a few **process** tests that start real
executables.

## 1. Shape

```text
src/lib/          shared machine + messages (no main, no GTK)
src/server/       TCP + SQLite + turn collect
src/client/       human GTK debugger
src/ai/           stand-alone AI client
src/tools/        optional CLI “tick N” host for tests
tests/unit/       one concern per program, no TCP
tests/fn/         one rule cluster per program, in-process messages
tests/functional/ Python: spawn server + clients
```

Three shipped binaries: `cplanets-server`, `cplanets`, `cplanets-ai`.
A fourth `cplanets-tick` (headless, no TCP) is worth it so unit tests
do not link GTK or SQLite.

**Done** for a slice: production files exist, each public function has
at least one unit program, the rule cluster has a fn program, CTest
runs them.

## 2. File rules

- One **tick phase** or **message verb** per file when practical
  (`tradeArrive.cw`, not `economy.cw`).
- Names match the spec (`recall`, `sender`, `S`) so a reader can grep
  RULES.md.
- Scenario numbers live in the setup snapshot, not magic literals
  (except in tests that name the fixture).
- No HTTP or JSON in v1. Frames: version, verb, path, length, body.

## 3. Testing layers

| Layer | What | How |
| --- | --- | --- |
| **Unit** | One function or transition | `tests/unit/*.cw` links `lib`, prints a bool. Fixed seed. No sleep, no sockets. |
| **Function** | One rule cluster from RULES.md | `tests/fn/*.cw`: build a tiny galaxy, `tick` N times, check events and stocks. |
| **Functional** | Executables and the wire | Python + CTest: start server, connect a dummy client, `PUT` policy, `POST` turn, `GET` events. Later: GTK only where we must. |

Function tests are the **spec suite** (unowned take, cargo 10×10,
pirate loot on return, two pirates war, same-tick cancel, …). Unit
tests pin the helpers those rely on (ETA from speed/distance, hold
count for `S`, dispatch weight, envelope encode/decode).

Seeded PRNG lives in `lib` (not `SecureRandom`). Same seed ⇒ same
fn test.

## 4. Phases and estimates

Likely = “readable files, first complete behavior, not golfed.”
High includes extra split files and test doubles. GTK **map canvas**
is a later phase and assumes Cwhip grows `DrawingArea`.

### A. Skeleton

CMake three (then four) programs, drop `hello`, shared `lib` stub,
one unit test that links.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 8 | 200 | 80 |
| High | 12 | 350 | 150 |

### B. Scenario + state + RNG

Load setup (application text, not a stdlib format). Galaxy at start:
home yard, scout-range rocks, unknown quality, world count/mix.
Empire pools. Seeded rng.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 12 | 900 | 500 |
| High | 18 | 1 400 | 800 |

### C. Tick core (no net)

Dispatcher + production + dispatch/loading + recall/cancel + sit/move
+ range/ETA + stranded-N.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 14 | 1 200 | 900 |
| High | 20 | 1 800 | 1 400 |

### D. Trade, pirate, take

Trade cycle, escorts, self-trade, agreements, confiscation, midpoint
ambush, two-pirate war, loot on return, identify chance, unowned take,
defenses, colony, mixed-fleet combat, designs/reclaim, capture-use,
contact/partitions, last-player end.

This is the **bulk of the game**. Split by RULES section.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 28 | 2 800 | 2 400 |
| High | 40 | 4 200 | 3 600 |

### E. Messages (library)

Envelope, compress/decompress body, verbs. Round-trip unit tests on
bytes. No listen socket yet.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 6 | 500 | 400 |
| High | 10 | 800 | 650 |

### F. Server

TCP accept, one writer, SQLite snapshot, collect policies, tick,
“turn ready”, AFK last-policy, setup lock, join sandbox.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 10 | 900 | 350 fn + 400 Python |
| High | 16 | 1 500 | 600 + 700 |

### G. Human client (list debugger)

Windows, planet list, fleet list, newspaper, policy editors, no map
canvas. No dumb-order warnings. Talks TCP only.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 18 | 1 800 | 200 unit + 400 GTK/functional |
| High | 28 | 2 800 | 400 + 800 |

### H. AI client

Same protocol. Own config file (aggression, role bias). Later dialogs.
Fn tests with a fake server or the real server from F.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 8 | 600 | 350 |
| High | 14 | 1 000 | 600 |

### I. Map canvas (after GTK `DrawingArea`)

Hot spots, dotted ETA, pan/zoom. Depends on **cwhip gtk** work, not
only this repo.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 8 | 800 | 200 |
| High | 14 | 1 500 | 400 |

### J. HTTP REST façade (optional)

Same commands, HTTP framing. Skip until something non-Cwhip must talk.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 6 | 400 | 250 |
| High | 10 | 800 | 500 |

## 5. Totals

**v1 playable** = A–H (library, tests, server, list client, AI). No
canvas, no HTTP.

| Scope | Prod LOC | Test LOC | Total |
| --- | ---: | ---: | ---: |
| v1 likely | ~8 900 | ~7 300 | **~16 000** |
| v1 high | ~13 900 | ~11 300 | **~25 000** |
| + canvas likely | +800 | +200 | **~17 000** |
| + HTTP likely | +400 | +250 | **~16 700** |

About **90–150 `.cw` files** at v1 if we keep them short, plus ~10–20
Python functional tests.

If files are allowed to grow to 400–600 lines, file count drops by
roughly a third and LOC does **not**; bugs get harder to bisect. Prefer
more files.

## 6. Function-test checklist (spec suite)

Each item is **one** `tests/fn/` program unless noted.

- Home is productive with a yard; rocks in scout range; quality unknown
- Unowned take: no fight
- Owned, empty, no defenses: undefended
- Satellites defend after warships leave
- Colony required to populate; dead colony does not
- Screened heavies lose fewer hulls than heavies alone
- Trade full both ways; escorts cycle; sender-only loading
- Self-trade is cost-only
- `S=100`, hold 10 ⇒ 10 cargo hulls
- Same-tick recall cancels (no dispatch)
- Recall always to sender; reclaim only at a yard, setup percent
- Pirate loot credits on pirate return
- Identify chance attributed vs not
- Two pirates at midpoint: they war, passer lives
- Stranded moves after N ticks
- Capture-use vs destroy
- Closed game: last player
- Contact couples partitions
- Empire pool only
- Setup locked in progress
- Envelope round-trip (unit + one fn)

Server functional (Python):

- Two clients, simultaneous turn, AFK holds last policy
- AI client + human client on one server
- Join sandbox; no DB in the client process

## 7. Suggested build order

1. A–B, tick CLI, unit RNG/setup  
2. C, then D one RULES section at a time (trade before pirate before take)  
3. E bytes, F server, Python smoke  
4. H AI (easier than GTK, proves the wire)  
5. G list client  
6. I canvas when gtk can draw  
7. J only if needed  

Do not start GTK until **D+F** pass the spec suite. The GUI cannot
save a wrong `tick`.

## 8. What these numbers are not

- Not calendar time (Cwhip GTK bindings and DrawingArea are extra
  cwhip work).
- Not a promise that combat formulas stay small; setup-file math can
  add a few hundred lines in D.
- Not counting generated C, SQLite SQL strings beyond a thin wrapper,
  or template CMake already in the tree.
