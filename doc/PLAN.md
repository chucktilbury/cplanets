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
src/lib/          shared machine + messages (no main, no GTK, no schedule)
src/server/       TCP + SQLite + real-time tick scheduler (sole writer)
src/client/       human GTK debugger (never ticks)
src/ai/           stand-alone AI client (same protocol; own config)
src/tools/        optional CLI “tick N” host for tests (calls lib only)
tests/unit/       one concern per program, no TCP
tests/fn/         one rule cluster per program, in-process messages
tests/functional/ Python: spawn server + clients
```

Three shipped binaries: `cplanets-server`, `cplanets`, `cplanets-ai`.
A fourth `cplanets-tick` (headless, no TCP) is worth it so unit/fn tests
do not link GTK or SQLite.

**Sacred architecture** (RULES §1–§2 — non-negotiable acceptance):

- Pure step is `tick(state, policies, rng) → (state, events)` in `lib`.
- **Only the server** schedules and calls `tick` (real-time cadence).
- **GUI / clients never tick** and **never** open the universe DB.
- Human and AI share the **same** TCP protocol and message types.
- Stand-alone = start a server, attach clients (same clock as online).
- Seeded PRNG lives in `lib` (not `SecureRandom`).

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
- Scheduling, SQLite, and TCP stay out of `lib`. `lib` is
  tick-count based only.

## 3. Testing layers

| Layer | What | How |
| --- | --- | --- |
| **Unit** | One function or transition | `tests/unit/*.cw` links `lib`, prints a bool. Fixed seed. No sleep, no sockets. |
| **Function** | One rule cluster from RULES.md | `tests/fn/*.cw`: build a tiny galaxy, call `tick` N times, check events and stocks. |
| **Functional** | Executables and the wire | Python + CTest: start server, connect a dummy client, `PUT` policy, advance tick(s) via **injectable clock** / admin advance, `GET` state + digest/events. Later: GTK only where we must. |

Function tests are the **spec suite** (unowned take, cargo 10×10,
pirate loot on return, two pirates war, same-tick cancel, closed
eliminate-all, …). Unit tests pin the helpers those rely on (ETA from
speed/distance, hold count for `S`, dispatch weight, envelope
encode/decode).

Seeded PRNG lives in `lib`. Same seed ⇒ same fn test. Do **not** put
wall-clock in `lib` or in fn tests — only the server scheduler (and
its injectable clock) knows real time.

## 4. Phases and estimates

Likely = “readable files, first complete behavior, not golfed.”
High includes extra split files and test doubles. GTK **map canvas**
is a later phase and assumes Cwhip grows `DrawingArea`.

### A. Skeleton

CMake four programs, drop `hello`, shared `lib` stub, one unit program
that includes `lib/` (Cwhip stages the `SOURCE` directory, so that
program lives at `src/unit_libIdentity.cw`; CTest wrappers stay in
`tests/unit/`).

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 8 | 200 | 80 |
| High | 12 | 350 | 150 |

### B. Scenario + state + RNG

Load setup (application text, not a stdlib format). Galaxy at start:
home yard, scout-range rocks, unknown quality, world count/mix.
Empire pools. Seeded rng.

**Closed-scenario default fixture** (v1): every RULES §14 knob named —
including tick period, AFK timeout/shrink (real time and/or tick
period; field names may stay thin until RULES names them), stranded N,
identify-from-attributes curve, tech→detection/range curve, reclaim
percent, capture-use chance, world count/mix. Win condition =
**eliminate all others**. Scenario mode default = closed.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 12 | 900 | 500 |
| High | 18 | 1 400 | 800 |

### C. Tick core (no net)

Dispatcher + production + dispatch/loading + recall/cancel + sit/move
+ range/ETA + stranded-N. Pure `tick` per RULES §7; no scheduler.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 14 | 1 200 | 900 |
| High | 20 | 1 800 | 1 400 |

### D. Trade, pirate, take (milestones)

This is the **bulk of the game**. Ship one milestone at a time; each
milestone ends with its fn programs green before the next starts.
Agreements are **player–player** from the first trade milestone.

| Milestone | Scope |
| --- | --- |
| **D1 Take / colony / defenses** | Unowned take (no fight); undefended owned; satellites/parked defend; colony required to populate; dead colony does not; war fleets stay; sit/move on possession. |
| **D2 Trade / agreements** | Player–player agreement + `S`; cargo full both ways; escorts cycle; sender-only loading; self-trade cost-only; `S=100` needs 10×10 holds; closed agreement / role-off-trader breaks. |
| **D3 Pirate / identify** | Midpoint ambush (in position after half hop ETA); loot on pirate return; two-pirate war (passers live); forced recall; idle timeout; identify chance scales with attributes (victim-only default audience). |
| **D4 Combat / designs / reclaim** | Shared combat; screened heavies; designs + yard produce/reclaim; capture-use vs destroy; attributed attack ends agreement + confiscation. |
| **D5 Contact / end** | Contact couples partitions; known competitors; closed eliminate-all end; empire pool only; setup lock in progress. |

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 28 | 2 800 | 2 400 |
| High | 40 | 4 200 | 3 600 |

(Estimates are for D1–D5 together; do not start D3 until D2’s trade
fn suite passes.)

### E. Messages (library)

Envelope, compress/decompress body, verbs. Round-trip unit tests on
bytes. No listen socket yet. Verbs: `GET` state, `PUT` policy, `GET`
events/digest. **No** all-players-ready / `POST turn` barrier verb.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 6 | 500 | 400 |
| High | 10 | 800 | 650 |

### F. Server

TCP accept, one writer, SQLite snapshot. **Driver** (RULES §2):

1. Configurable **real-time** cadence (tick period from setup).
2. At each fire: snapshot every player’s **current policy** →
   `tick` from the **previous published** state → persist →
   **publish** state + **digest** (events / newspaper).
3. Between ticks the server may prep the next step (engineering only).
4. **No** all-ready barrier. Policy `PUT` anytime. **AFK = last
   policy** held.
5. **Injectable clock** / admin “advance N ticks” for tests (no sleep
   in CI).
6. Setup lock once in progress; join sandbox partitions.

Stand-alone and online share this driver.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 10 | 900 | 350 fn + 400 Python |
| High | 16 | 1 500 | 600 + 700 |

### G. Human client (list debugger)

Windows, planet list, fleet list, newspaper/digest, policy editors, no
map canvas. No dumb-order warnings. Talks TCP only — never ticks,
never opens the DB. Capability-scaled visibility is a **view of flags
the driver already set**, not a second fog engine.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 18 | 1 800 | 200 unit + 400 GTK/functional |
| High | 28 | 2 800 | 400 + 800 |

### H. AI client

Same protocol as the human client. **Own config file** (not the human
settings file). Later dialogs.

Config axes (wide latitude; names illustrative — match
gameplay-principles):

| Axis | Soft → hard |
| --- | --- |
| Aggression | Trade/hermit bias → conqueror / take pressure |
| Role stickiness | Rare flips → fluid (respect pirate+ambush lock) |
| Expansion hunger | Slow scout/colony → fast claim |
| Escort discipline | Light → heavy on trade/colony |
| Agreement appetite | Few/small `S` → many/larger `S` |
| Tech vs hulls | Skew development → skew production |
| Reaction lag | Every K ticks / wall interval → near-every tick |
| Surprise rate | Rare legal oddities → capped band |

Reaction lag is in **ticks or wall time** (RULES §17 still open on
binding preference — expose both until locked). Surprise must be
**legal-only**, same visibility as humans, **reproducible** under
seeded RNG. Fn tests: given seed + config, known policy shape; over N
updates, surprise fires within a rate band.

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
Do not grow a second rule engine.

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

**Setup / visibility / pools**

- Home is productive with a yard; rocks in scout range; quality unknown
- Tech raises detection/range; explore fills view inside range (does not
  extend range)
- Empire pool only
- Setup locked in progress
- Closed-scenario fixture names every §14 knob (incl. tick period,
  identify curve, tech-range curve)

**Take / colony / defenses (D1)**

- Unowned take: no fight
- Owned, empty, no defenses: undefended
- Satellites defend after warships leave
- Colony required to populate; dead colony does not

**Trade / agreements (D2)**

- Player–player agreement on `S`; both must accept
- Trade full both ways; escorts cycle; sender-only loading
- Self-trade is cost-only
- `S=100`, hold 10 ⇒ 10 cargo hulls
- Same-tick recall cancels (no dispatch)

**Pirate / identify (D3)**

- Ambush only after pirate in position (half hop ETA)
- Pirate loot credits on pirate return
- Identify chance attributed vs not (scales with attributes)
- Two pirates at midpoint: they war, passer lives

**Combat / designs (D4)**

- Screened heavies lose fewer hulls than heavies alone
- Recall always to sender; reclaim only at a yard, setup percent
- Capture-use vs destroy
- Attributed attack ends agreement + confiscation at victim worlds

**Contact / end (D5)**

- Contact couples partitions
- Closed game: one player eliminated all others
- Stranded moves after N ticks

**Wire**

- Envelope round-trip (unit + one fn)

Server functional (Python):

- Injectable clock / advance-N-ticks (no wall sleep in CI)
- Two clients, policies apply on **next tick** (no ready barrier);
  AFK holds last policy
- Digest published with each tick; clients `GET` state + events
- AI client + human client on one server
- Join sandbox; no DB in the client process
- Clients never call `tick`

## 7. Suggested build order

1. A–B (incl. closed-scenario fixture + RNG), tick CLI, unit RNG/setup  
2. C (pure tick core)  
3. D1 → D2 → D3 → D4 → D5 (one RULES cluster at a time; fn green
   before the next)  
4. E bytes, F server (scheduler + injectable clock), Python smoke  
5. H AI (easier than GTK, proves the wire + config axes)  
6. G list client  
7. I canvas when gtk can draw  
8. J only if needed  

Do not start GTK until **D+F** pass the spec suite. The GUI cannot
save a wrong `tick`.

Aligns with RULES §18 (AI before list GTK).

## 8. What these numbers are not

- Not calendar time (Cwhip GTK bindings and DrawingArea are extra
  cwhip work).
- Not a promise that combat formulas stay small; setup-file math can
  add a few hundred lines in D.
- Not counting generated C, SQLite SQL strings beyond a thin wrapper,
  or template CMake already in the tree.

## 9. Still thin (do not invent in PLAN)

Follow RULES §17 / store design docs — leave open until the user locks:

- Pause under real-time tick (stand-alone / host)
- Default tick-period magnitude for v1 feel
- AI reaction lag binding preference (K ticks vs wall vs digest-gated)
- Exact AFK setup field names / floor
- Identify audience after success (victim-only is current default)
- Exact combat/production formulas
- Livability / power / experience as tick drivers vs display
- Setup file syntax
