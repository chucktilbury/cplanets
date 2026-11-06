# End-to-end implementation plan

Working plan for building CPlanets against [RULES.md](RULES.md).
Rules win if this file disagrees on game behavior. This file wins on
**order of work, file shape, and tests**.

Estimates are **Cwhip source lines** (not comments-only, not CMake, not
Python harness). Ranges assume files stay **short and readable**: usual
target about **~200 lines** per `.cw` file, soft ceiling **~400**
(prefer short; split when a file mixes two jobs). Over **1000** lines
must become submodules — see [CODING.md](CODING.md). CODING owns
**headers, full method comments, indent, and line wrapping**; those
count toward the soft **physical-line** ceiling, so expect **earlier
splits** and a **higher file count** than LOC alone suggests — prefer
more short files over packing helpers.
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
including tick period (**seconds**; provisional clamp **1–30**; **may
auto-config from AI reaction lag**, still setup-tunable), AI reaction
lag, AFK timeout/shrink (real time and/or tick period; field names may
stay thin until RULES names them), stranded N, **identify
attacker-side** and **defender-side** mappings (separate),
tech→detection/range mapping, **tech→teleport / ETA→0** mapping,
design/build duration knobs, reclaim percent, capture-use chance,
world count/mix, livability→**1–10** display mapping, battle-duration
/ comparative-strength coefficients, productive inherent-defense
coefficient. Prefer **many** named knobs for post-complete tuning —
combat, production, and other tunables live **outside code**. Where
older notes say **curve**, read **setup-tunable mapping /
coefficients** (not fancy math). Win condition = **eliminate all
others**; all-humans-quit also ends the live game. Scenario mode
default = closed. **Future (plan accordingly, not v1):** server
**setup GUI dialog hierarchy** for these knobs (RULES §14).

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 14 | 1 000 | 550 |
| High | 20 | 1 500 | 900 |

### C. Tick core (no net)

Dispatcher + production + dispatch/loading + recall/cancel + sit/move
+ range/ETA (incl. high-tech **ETA→0 teleport** via setup mapping) +
stranded-N. Pure `tick` per RULES §7; no scheduler.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 15 | 1 300 | 1 000 |
| High | 22 | 2 000 | 1 500 |

### D. Trade, pirate, take (milestones)

This is the **bulk of the game**. Ship one milestone at a time; each
milestone ends with its fn programs green before the next starts.
Agreements are **player–player** from the first trade milestone.

| Milestone | Scope |
| --- | --- |
| **D1 Take / colony / defenses** | Unowned take (no fight); undefended owned **non-productive**; productive owned always has inherent defense (take never free); satellites/parked defend; colony required to populate; dead colony does not; war fleets stay; sit/move on possession. |
| **D2 Trade / agreements** | Player–player agreement + `S`; cargo full both ways; escorts cycle; sender-only loading; self-trade cost-only; `S=100` needs 10×10 holds; closed agreement / role-off-trader breaks. |
| **D3 Pirate / identify** | Midpoint ambush; loot on pirate return; two-pirate war (passers live); forced recall; idle timeout; identify asymmetry (attacker advantage + defender fair chance; separate setup knobs; scales with attributes; victim-only default audience). |
| **D4 Combat / designs / reclaim** | Shared combat (multi-tick; duration from comparative strength; recall into/out of fight still under battle rules); mid-dispatch: other policy OK, that in-flight fleet locked until recall; designs + yard produce/reclaim take time (not instant); screened heavies; capture-use vs destroy; attributed attack ends agreement + confiscation. |
| **D5 Contact / end** | Contact couples partitions; known competitors; closed eliminate-all end; all-humans-quit ends game; zombies fall to normal play (no consistent zombie-win path); empire pool only; setup lock in progress. |

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 30 | 3 100 | 2 600 |
| High | 44 | 4 600 | 3 900 |

(Estimates are for D1–D5 together; do not start D3 until D2’s trade
fn suite passes.)

### E. Messages (library)

Envelope, compress/decompress body, verbs. Round-trip unit tests on
bytes. No listen socket yet. Verbs: `GET` state, `PUT` policy, `GET`
events/digest. **No** all-players-ready / `POST turn` barrier verb.
**Wire name (v1):** envelope version `1` + RLE body codec with store
fallback; reject unknown version.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 6 | 500 | 400 |
| High | 10 | 800 | 650 |

### F. Server

TCP accept, one writer, SQLite snapshot. **Driver** (RULES §2):

1. Configurable **real-time** cadence (tick period from setup,
   **seconds**; provisional allowed range **1–30**; **may auto-config
   from AI reaction lag**, still setup-tunable — RULES §2).
2. At each fire: snapshot every player’s **current policy** →
   `tick` from the **previous published** state → persist →
   **publish** state + **digest** (events / newspaper).
3. Between ticks the server may prep the next step (engineering only).
4. **No** all-ready barrier (not simultaneous-turn collect). Policy
   `PUT` anytime. **AFK = last policy** held. **Handshake**
   distinguishes AFK (present, idle) from **drop** (lost contact);
   presence ≠ policy PUT (RULES §2). **Pause** only when exactly
   **one human** is in the game; with **two or more humans**, pause
   is **not** offered (wall clock keeps running).
5. **Injectable clock** / admin “advance N ticks” for tests (no sleep
   in CI).
6. Setup lock once in progress; join sandbox partitions. Setup knobs
   (combat/production/identify/…) live in the scenario file; **future**
   server **setup GUI dialog hierarchy** — plan accordingly, not v1
   (RULES §14).
7. **Session (v1):** each game is **stand-alone** — **no** durable
   status save, **no** rejoin API. Drop during a live game → last
   policy for that live remainder only (RULES §2). If **all human
   players quit**, register **end of game** (do not leave an AI-only
   zombie match running). **Plan accordingly:** keep state
   **SQLite-shaped** so a **future** durable save / rejoin path stays
   clean; do not implement save / rejoin now.

Stand-alone and online share this driver.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 11 | 1 000 | 400 fn + 450 Python |
| High | 18 | 1 600 | 650 + 800 |

### G. Human client (list debugger)

Windows, planet list, fleet list, newspaper/digest, policy editors, no
map canvas. No dumb-order warnings. Talks TCP only — never ticks,
never opens the DB. Capability-scaled visibility is a **view of flags
the driver already set**, not a second fog engine. **Explored planet
dialog** for humans: livability/quality on a **1–10** scale; dialog
**may change** as the rock is populated/productive (RULES §13 / §16).

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 20 | 1 900 | 250 unit + 450 GTK/functional |
| High | 30 | 2 900 | 450 + 850 |

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
exact binding shape — expose both until locked). **Direction locked:**
AI lag **may** drive tick-period **auto-config**; tick period stays
**setup-tunable** (RULES §2 / §14). Surprise must be **legal-only**,
same visibility as humans, **reproducible** under seeded RNG. Fn
tests: given seed + config, known policy shape; over N updates,
surprise fires within a rate band.

| | Files | Prod LOC | Test LOC |
| --- | ---: | ---: | ---: |
| Likely | 9 | 700 | 400 |
| High | 16 | 1 100 | 700 |

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
canvas, no HTTP. No new phase is required for locks already on
`origin/main` (pause, zombies, identify asymmetry, livability dialog,
AI-lag tick auto-config, multi-tick combat, tech teleport) — they
fold into B–H above.

| Scope | Prod LOC | Test LOC | Total |
| --- | ---: | ---: | ---: |
| v1 likely | ~9 700 | ~6 600 | **~16 300** |
| v1 high | ~14 900 | ~10 600 | **~25 500** |
| + canvas likely | +800 | +200 | **~17 100** |
| + HTTP likely | +400 | +250 | **~16 700** |

About **100–170 `.cw` files** at v1 if we keep them short (CODING full
method comments push toward the high end of the file count), plus
~10–25 Python functional tests.

If files regularly push past the soft **~400** ceiling, file count
drops and LOC does **not**; bugs get harder to bisect. Prefer more
files — see [CODING.md](CODING.md).

## 6. Function-test checklist (spec suite)

Each item is **one** `tests/fn/` program unless noted.

**Setup / visibility / pools**

- Home is productive with a yard; rocks in scout range; quality unknown
- Tech raises detection/range; explore fills view inside range (does not
  extend range)
- High tech may reduce travel **ETA to zero** (teleport) via setup
  mapping; magnitudes open
- Empire pool only
- Setup locked in progress
- Closed-scenario fixture names every §14 knob (incl. tick period
  seconds 1–30 provisional, may auto-config from AI lag, separate
  identify attacker/defender mappings, tech-range + tech→teleport
  mappings, design/build durations, battle-duration /
  comparative-strength + productive inherent-defense coefficients,
  livability→1–10 display)

**Take / colony / defenses (D1)**

- Unowned take: no fight
- Owned, empty, no defenses, **not productive**: undefended
- Productive owned (zero fleet): still fights inherent defense — take never free
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
- Identify: attacker advantage + defender fair chance; separate
  setup knobs; attributed vs not (scales with attributes)
- Two pirates at midpoint: they war, passer lives

**Combat / designs (D4)**

- Engagement may span ticks; duration from comparative strength (setup)
- Recall into/out of fight still under battle rules (can reverse or share defeat)
- Mid-dispatch: in-flight fleet order locked until recall; **other**
  policy edits still OK (game keeps running)
- Design development and yard builds take time (setup/ticks; not instant)
- Screened heavies lose fewer hulls than heavies alone
- Recall always to sender; reclaim only at a yard, setup percent
- Capture-use vs destroy
- Attributed attack ends agreement + confiscation at victim worlds

**Contact / end (D5)**

- Contact couples partitions
- Closed game: one player eliminated all others
- All humans quit → server ends the game
- Zombies fall to normal play (no consistent zombie-win path)
- Stranded moves after N ticks

**Wire**

- Envelope round-trip (unit + one fn)

Server functional (Python):

- Injectable clock / advance-N-ticks (no wall sleep in CI)
- Two clients, policies apply on **next tick** (no ready / simultaneous
  barrier); AFK holds last policy; handshake distinguishes drop
- **Pause** offered with exactly one human; **not** offered with two
  or more humans (clock keeps running)
- Drop mid-game: last policy continues for that **live** game; **no**
  rejoin / no status-save API in v1 (RULES §2)
- All humans quit → server ends the game (no AI-only zombie live match)
- Digest published with each tick; clients `GET` state + events
- AI client + human client on one server; AI lag may suggest tick
  auto-config (still setup-tunable)
- Join sandbox; no DB in the client process
- Clients never call `tick`
- Human explored-planet dialog (1–10 livability/quality; may change
  when populated/productive) — UI view of known quality, not a
  second rules engine

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
- Not a promise that combat formulas stay small; setup-file math and
  multi-tick combat can add a few hundred lines in D — totals above
  already bias toward that.
- Not counting generated C, SQLite SQL strings beyond a thin wrapper,
  or template CMake already in the tree.
- Not a second clock model: simultaneous-turn / all-ready barrier
  language is **closed**; do not reintroduce it in phases or tests.

## 9. Still thin (do not invent in PLAN)

Follow RULES §17 / store design docs — leave open until the user locks.
Do **not** invent magnitudes, formulas, or bindings here.

**Locked on `origin/main` (do not reopen in PLAN):** server real-time
tick + digest driver; policy anytime / AFK = last policy; pause =
one-human only; tick period seconds provisional 1–30 (may auto-config
from AI lag, still setup-tunable); no save / rejoin v1; all-humans-quit
ends game; zombies → normal play; mid-dispatch fleet lock;
design/build take time; knobs outside code; identify asymmetry
direction; livability **display** 1–10 + explored human dialog;
multi-tick combat + productive inherent defense; tech may ETA→0;
ambush only after half-hop in position; CODING file-size / full
method comments.

Still open:

- Exact default tick period **inside** provisional 1–30s band
  (auto-config-from-AI-lag **mapping** open)
- AI reaction lag **binding shape** (K ticks vs wall vs digest-gated)
  and lag magnitudes
- Exact AFK setup field names / floor
- Presence / drop details: heartbeat interval, peer `dropped` digest
  notify (RULES §2)
- Identify **magnitudes** for separate attacker/defender knobs;
  identify **audience** after success (victim-only is current default)
- Exact combat/production formulas (multi-tick / strength→duration
  magnitudes; productive inherent-defense coefficient values)
- Tech→teleport mapping shape / magnitudes; ETA-0 ambush edge
- Livability / power / experience as **tick drivers** (display locked)
- Setup file syntax
- **Deferred:** durable save / rejoin (keep SQLite-shaped; no API in
  v1); server setup GUI dialog hierarchy (plan accordingly; not v1)
