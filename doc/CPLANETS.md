# CPlanets — user / operator guide

This is the **main user document** for running CPlanets: what the
binaries are, how to build them, and how to start a stand-alone
session. Game rules and implementer notes live elsewhere (see
[Further reading](#further-reading)).

CPlanets is a multi-player territory game on a server-driven real-time
tick. Clients (human or AI) update policy anytime and read a published
digest — **they never tick** and never open the universe database.
Stand-alone and online share the same server clock: start a server,
then attach clients over TCP.

---

## Executables

Default `build` installs these into `bin/`:

| Binary | Role |
| --- | --- |
| `cplanets-server` | Owns the galaxy. Schedules ticks, accepts TCP clients, is the sole writer. |
| `cplanets` | Human client — GTK **list debugger** (planets / fleets / digest / policy; pause + fleet dispatch/recall chrome). Never ticks. |
| `cplanets-ai` | Stand-alone AI client on the same protocol. Own config file. Never ticks. |
| `cplanets-tick` | Headless identity / future N-tick host stub (no TCP, no GTK). |

Bare invocation (no flags) of each production binary prints the
program name and the shared lib identity string — useful as a smoke
check after build. All four user-facing binaries parse argv with the
Cwhip stdlib `cli` package (`import cli as Cli`); `--help` / `-h`
prints generated usage. Unknown flags fail loud (exit 2).

**Map canvas (Phase I) is not available yet.** The human UI is a list /
notebook debugger only — no planet grid DrawingArea, pan/zoom, or
hot-spot map. Cwhip GTK widgets still needed for that UI (and for
intended playable controls) are listed in
[GTK-FEATURE-GAPS.md](GTK-FEATURE-GAPS.md).

---

## Build

Requires an installed Cwhip SDK (`0.0.2`, ABI `numeric-v2`) with
application defaults. Recommended path: run `scripts/setup`, which
configures `build/`, discovers the SDK when needed, and opens the
project shell (where related env such as `CWHIP_SDK` and
`CWHIP_BUILD_TYPE` are set for that shell):

```sh
./scripts/setup [--clean] [debug|release|profile]
build
```

Inside that shell:

| Command | Effect |
| --- | --- |
| `build` | Production programs only → `bin/` |
| `build test` / `cmake --build . --target test` | Also builds unit/fn programs under `tests/` |
| `ctest` | Runs unit, fn, smoke, and Python functional checks |
| `rebuild` | Clean then build (keeps configure) |

SDK selection order (setup and CMake): non-empty `CWHIP_SDK` if already
set → `$XDG_CONFIG_HOME/cwhip/sdk.toml` (`sdk_prefix`; setup exports it
as `CWHIP_SDK` for the child shell) → legacy `settings.toml` if
`sdk.toml` is absent → normal CMake discovery. Details:
[BUILDING.md](BUILDING.md), [PROJECT-SHELL.md](PROJECT-SHELL.md).

Fallback — temporary override before setup (bypasses config-home
lookup):

```sh
export CWHIP_SDK="/absolute/path/to/cwhip-sdk"
./scripts/setup
```

Unit/fn programs are **not** part of the default `all` / `build`
target. Configure with `-DBUILD_TESTING=OFF` to omit CTest wiring.

---

## How to run

Paths below assume you are at the project root after a successful
`build`, with binaries in `bin/`.

### CLI vs config defaults

Every command-line parameter **except the config/setup file path
itself** (`--setup` / `--config`) may also be set as a default in
that file. Load the file first; any flag **present on argv**
overrides the corresponding file value **silently** (no warning).
`cplanets-tick` has no value flags yet (help only).

### `cplanets-server`

```text
bin/cplanets-server --serve [--port N] [--players N] [--seed N] \
  [--setup PATH] [--verbosity N] [--injectable] [--cycles N]
```

| Flag | Default | Setup key | Meaning |
| --- | --- | --- | --- |
| `-h`, `--help` | — | — | Print stdlib `cli` usage and exit 0 |
| `--serve` | off | `serve` | Bind TCP and run accept + cadence loop |
| `--port N` | `0` (ephemeral) | `port` | Listen port; `0` picks a free port |
| `--players N` | `2` | `players` | Seat count for the closed start galaxy |
| `--seed N` | `7` | `seed` | PRNG seed for the start galaxy |
| `--setup PATH` | (builtin closed defaults) | *(path only — not in file)* | Load §14 knobs + process defaults |
| `--verbosity N` | setup key or `0` | `verbosity` | Stdout log level 0–10 (clamped) |
| `--injectable` | off | `injectable` | Test clock (admin advance); CI / harnesses |
| `--cycles N` | `0` (run until stop) | `cycles` | Cap accept/serve loop iterations |

**Verbosity** (headless stdout, not a GUI): scale **0–10**
(default `0`). Out-of-range values **clamp** into `0..10` (they
are not rejected). Category thresholds are **provisional** and
will firm up over time:

| Level | Server categories (provisional) |
| --- | --- |
| `0` | Errors only (optional lines silent) |
| `1–2` | Reserved |
| `3+` | Player settings / `PUT /policy` detail |
| `6+` | Combat / battle events + fleet strength (`atk_milli` / `def_milli`) |
| `7–9` | Reserved (richer combat / partial dumps) |
| `10` | Full dumps / statistics (gate only; no extra spam yet) |

Same keys in the scenario file (plus process defaults `serve`,
`port`, `players`, `seed`, `cycles`, `injectable`). CLI flags
present on argv overlay the setup values silently.

On start it prints `PORT=<n>`, `SETUP=<path|builtin>`, `SEED=<n>`,
`PLAYERS=<n>`, `CYCLES=<n>`, `VERBOSITY=<n>`, and `INJECTABLE=0|1`.
Use that port for clients. Pass `scenarios/closed-default.setup`
(or a copy you edited) via `--setup` so combat / economy / travel /
identify magnitudes come from the file. Unknown keys fail loud and
the process exits before listen. **Knob edits take effect on process
restart** — there is no mid-game retune in v1 (RULES §14
lock-in-progress).

### `cplanets` (human)

```text
bin/cplanets --config config/human-default.cfg [flags…]
```

| Flag | Config key | Meaning |
| --- | --- | --- |
| `-h`, `--help` | — | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | *(path only)* | Human settings file (not the AI config) |
| `--host HOST` | `host` | Dial host |
| `--port N` | `port` | Dial port (`> 0` for TCP) |
| `--player N` | `player_id` | Seat id |
| `--once` | `once` | In-process closed galaxy; print list summary (no TCP, no GTK) |
| `--pull` | `pull` | TCP GET state + digest summary (needs `port > 0`) |
| `--gui` | `gui` | GTK notebook debugger |
| `--test` | `test` | GTK path that auto-quits after a short schedule |

With `--gui` / `--test` and `port > 0`, the client pulls from the
server; otherwise it prefills an offline closed galaxy.

**Tuning-loop chrome (workstream B + ship create, no map):** Pause
CheckButton (sensitive only with exactly one human; `PUT /pause`).
Fleets tab Entries + Dispatch / Recall (`PUT /order`, `PUT /recall`)
for explore / take / trade / move / ambush / recall — in-flight
fleets show `LOCKED` and Dispatch is disabled until Recall. **Ships
tab** (design / yard): inspect the published design catalog and
owned yards; **Start develop** (`PUT /design`) queues timed design
development (wealth; `design_develop_ticks`); **Queue build**
(`PUT /build`) queues a hull at a productive owned shipyard
(resources; `yard_build_ticks`); **Reclaim hulls**
(`PUT /reclaim-hulls`) starts yard reclaim for a sitting fleet.
Progress label shows active develop / build / reclaim jobs. Policy
tab Entries + Apply unchanged. Explored-planet dialog auto-presents
when quality becomes known or productive/populated flips; Planets
tab still has “Show first explored”.

### `cplanets-ai`

```text
bin/cplanets-ai --config config/ai-default.cfg [flags…]
```

| Flag | Config key | Meaning |
| --- | --- | --- |
| `-h`, `--help` | — | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | *(path only)* | AI config (not human settings) |
| `--host HOST` / `--port N` | `host` / `port` | Dial |
| `--verbosity N` | `verbosity` | stdout log level 0–10 (clamped) |
| `--once` | `once` | Print one local policy shape (no TCP) |
| `--serve-loop` | `serve_loop` | Dial and PUT policy for `cycles` (needs `port > 0`) |
| `--cycles N` | `cycles` | Loop attempts (default `1`, min `1`) |

**Verbosity** (headless stdout, not a GUI): scale **0–10**
(default `0`). Out-of-range values **clamp** into `0..10`.
Category thresholds are **provisional**:

| Level | AI categories (provisional) |
| --- | --- |
| `0` | Errors only (optional lines silent) |
| `1–2` | Reserved |
| `3+` | Useful decisions — seat / handshake, policy PUT shape (role / axes / surprise), cycle `put` / `skip` / `fail` |
| `4–9` | Reserved (finer decision detail) |
| `10` | Full decision dumps / statistics (gate only; no extra spam yet) |

Same keys in the AI config file (`verbosity`, `cycles`, `once`,
`serve_loop`, dial / seat). CLI flags present on argv overlay
silently. `--once` / `--serve-loop` print `VERBOSITY=<n>` with the
summary.

### `cplanets-tick`

```text
bin/cplanets-tick
bin/cplanets-tick --help
```

Prints name + lib identity. `-h` / `--help` prints stdlib `cli`
usage. No advance-N CLI yet; lib tick coverage lives in
`tests/unit/` and `tests/fn/`.

---

## Typical stand-alone flow

Three terminals (or background jobs): server, human, AI.

**`--serve` (or setup `serve = true`)** is required for play.
Without serve from argv or the setup file, `cplanets-server`
prints smoke identity and exits — no TCP, no ticks.

The server uses **one request per TCP connection** (closes after each
reply). Clients redial per verb; wall-clock cadence advances even with
zero clients attached (no seat barrier). `--injectable` freezes wall
ticks until `PUT /admin/advance` (CI only).

```sh
# 0) Build (project shell; SDK via scripts/setup)
./scripts/setup
build

# 1) Server — note PORT=; knobs from the setup file
bin/cplanets-server --serve --port 7700 --players 2 --seed 7 \
  --setup scenarios/closed-default.setup

# 2) Human list debugger (seat 0)
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --player 0 --gui

# 3) AI client (seat 1 presets: config/ai-mid.cfg etc.)
bin/cplanets-ai --config config/ai-mid.cfg \
  --host 127.0.0.1 --port 7700 --serve-loop --cycles 20
```

**Solo human (no AI):** use `--players 1` so pause is offered, or keep
`--players 2` and leave seat 1 idle (last policy / empty). Wall ticks
still run. Prefer `scripts/tuning-session` (server + AI) for the
documented tuning loop.

Without a display, use `--pull` / `--once` on the human binary and
`--once` or `--serve-loop` on the AI. For automated harnesses, add
`--injectable` on the server so tests can advance ticks without
waiting on wall time.

**Ship create / design / yard (Ships tab):**

1. Open **Ships**. Confirm home yard (planet 0) and ready designs
   (seeded scout/colony are ready immediately).
2. **Start develop** — set name / speed / hop / size / cargo / kind
   (`scout` / `colony` / `defense` / `war`). Cost ≈ `size * 50 *
   design_speed_cost_coeff * design_range_cost_coeff` wealth. The
   design appears in the list as developing until
   `design_develop_ticks` elapse (wall ticks or `--injectable`
   advance).
3. **Queue build** — enter a productive owned yard planet id and a
   **ready** design id. Cost ≈ `size * 10` resources. When
   `yard_build_ticks` complete, a sitting hull appears at the yard
   (then use Fleets → Dispatch).
4. **Reclaim hulls** — sitting fleet at a yard; reclaim returns a
   setup percent of production resources after the same yard
   duration (development wealth is never refunded).

### Tuning session harness (workstream C)

Preferred one-command start after `build` (server + AI; human
attaches separately):

```sh
./scripts/tuning-session \
  --setup scenarios/tuning-small.setup \
  --seed 77 \
  --ai-config config/ai-mid.cfg \
  --port 7700
```

Then in another terminal:

```sh
# GTK list debugger
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --player 0 --gui

# or headless smoke (no display)
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --player 0 --pull
```

**Seed reproducibility:** keep `--seed` fixed (banner prints
`SEED=<n>`). The same seed + same `--setup` file yields a comparable
start galaxy after knob edits. Change seed only when you want a new
layout. AI aggression bands (`ai-soft` / `ai-mid` / `ai-hard`) are
independent of the galaxy seed.

**Fixture packs** (same schema, different magnitudes — placeholders):

| Path | Role |
| --- | --- |
| `scenarios/tuning-small.setup` | Fast loops (12 worlds); default for the harness |
| `scenarios/tuning-combat.setup` | Combat-leaning A/B |
| `scenarios/tuning-trade.setup` | Trade-leaning A/B |
| `scenarios/closed-default.setup` | Full closed baseline (24 worlds) |

**AI presets** (seat `player_id = 1` for human+AI):

| Path | Band |
| --- | --- |
| `config/ai-soft.cfg` | Soft aggression / slower lag |
| `config/ai-mid.cfg` | Mid (default harness) |
| `config/ai-hard.cfg` | Hard aggression / snappier lag |
| `config/ai-default.cfg` | Legacy dial defaults (`player_id = 0`) |

CI / headless proof (no GTK): CTest `functional_session_harness`
spawns injectable server + AI `--serve-loop` + human `--pull`,
advances ticks, and asserts digest growth. Manual injectable:

```sh
./scripts/tuning-session --setup scenarios/tuning-small.setup \
  --seed 77 --ai-config config/ai-mid.cfg --injectable --ai-cycles 4
```

### Tuning loop (restart contract)

1. Edit knobs in a scenario under `scenarios/` and/or an AI preset
   under `config/`.
2. Stop `cplanets-server` / `cplanets-ai` (Ctrl-C on
   `scripts/tuning-session`).
3. Restart with the **same** `--setup` / `--ai-config` / `--seed`.
4. Observe digest / lists / stock — no rebuild required for magnitude
   tweaks.

Reload-on-restart is the v1 contract. Mid-game admin retune and the
server setup GUI are deferred (RULES §14 / [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md)).
**Balance tuning comes after playable completeness + full textfile
knobs** — A–C harness is plumbing, not balance-done; inventory in
[KNOB-COVERAGE.md](KNOB-COVERAGE.md). Most **server** settings stay
textfile; selective human GUI setters come later.

---

## Config and fixtures

| Path | What |
| --- | --- |
| `config/human-default.cfg` | Human dial defaults (`player_id`, `host`, `port`) |
| `config/ai-default.cfg` | AI axes (aggression, lag, surprise, …) plus dial |
| `config/ai-{soft,mid,hard}.cfg` | Aggression-band presets (seat 1) |
| `scenarios/closed-default.setup` | Closed-scenario §14 tuning surface |
| `scenarios/tuning-{small,combat,trade}.setup` | Harness / A/B fixture packs |

Config and scenario files use simple `key = value` application text.
Unknown keys fail loud on scenario setup and AI config load. Pass
client configs with `--config`; pass the scenario with server
`--setup`. Group comments in those files name the tuning surface.

Tests that exercise binaries live under `tests/unit/`, `tests/fn/`,
and `tests/functional/` (Python spawns `cplanets-server` and talks
the wire protocol; `functional_setup_path` covers `--setup`;
`functional_session_harness` covers setup + seed + AI join).

---

## Further reading

This file is for **users and operators**.

| Audience | Doc |
| --- | --- |
| Game rules / machine spec | [RULES.md](RULES.md) |
| Implementation order & phases | [PLAN.md](PLAN.md) |
| Next: playable + knobs (then balance) | [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) |
| Knob inventory (textfile / GUI tags) | [KNOB-COVERAGE.md](KNOB-COVERAGE.md) |
| Cwhip coding conventions | [CODING.md](CODING.md) |
| SDK / CMake / project shell | [BUILDING.md](BUILDING.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
