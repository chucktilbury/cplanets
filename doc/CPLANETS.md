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

### `cplanets-server`

```text
bin/cplanets-server --serve [--port N] [--players N] [--seed N] \
  [--setup PATH] [--injectable] [--cycles N]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `-h`, `--help` | — | Print stdlib `cli` usage and exit 0 |
| `--serve` | (required for play) | Bind TCP and run accept + cadence loop |
| `--port N` | `0` (ephemeral) | Listen port; `0` picks a free port |
| `--players N` | `2` | Seat count for the closed start galaxy |
| `--seed N` | `7` | PRNG seed for the start galaxy |
| `--setup PATH` | (builtin closed defaults) | Load §14 knobs from a scenario file |
| `--injectable` | off | Test clock (admin advance); CI / harnesses |
| `--cycles N` | `0` (run until stop) | Cap accept/serve loop iterations |

On start it prints `PORT=<n>`, `SETUP=<path|builtin>`, `SEED=<n>`,
and `INJECTABLE=0|1`. Use that port for clients. Pass
`scenarios/closed-default.setup` (or a copy you edited) via
`--setup` so combat / economy / travel / identify magnitudes come
from the file. Unknown keys fail loud and the process exits before
listen. **Knob edits take effect on process restart** — there is no
mid-game retune in v1 (RULES §14 lock-in-progress).

### `cplanets` (human)

```text
bin/cplanets --config config/human-default.cfg [flags…]
```

| Flag | Meaning |
| --- | --- |
| `-h`, `--help` | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | Human settings file (not the AI config) |
| `--host HOST` | Override dial host |
| `--port N` | Override dial port (`> 0` for TCP) |
| `--player N` | Seat id |
| `--once` | In-process closed galaxy; print list summary (no TCP, no GTK) |
| `--pull` | TCP GET state + digest summary (needs `--port`) |
| `--gui` | GTK notebook debugger |
| `--test` | GTK path that auto-quits after a short schedule |

With `--gui` / `--test` and `port > 0`, the client pulls from the
server; otherwise it prefills an offline closed galaxy.

**Tuning-loop chrome (workstream B, no map):** Pause CheckButton
(sensitive only with exactly one human; `PUT /pause`). Fleets tab
Entries + Dispatch / Recall (`PUT /order`, `PUT /recall`) for
explore / take / trade / move / ambush / recall — in-flight fleets
show `LOCKED` and Dispatch is disabled until Recall. Policy tab
Entries + Apply unchanged. Explored-planet dialog auto-presents when
quality becomes known or productive/populated flips; Planets tab
still has “Show first explored”. Design/build progress is a
non-modal label fed from the published chrome trailer (setup
durations + active jobs).

### `cplanets-ai`

```text
bin/cplanets-ai --config config/ai-default.cfg [flags…]
```

| Flag | Meaning |
| --- | --- |
| `-h`, `--help` | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | AI config (not human settings) |
| `--host HOST` / `--port N` | Dial overrides |
| `--once` | Print one local policy shape (no TCP) |
| `--serve-loop` | Dial and PUT policy for `--cycles N` (needs `port > 0`) |
| `--cycles N` | Loop attempts (default `1`, min `1`) |

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

Without a display, use `--pull` / `--once` on the human binary and
`--once` or `--serve-loop` on the AI. For automated harnesses, add
`--injectable` on the server so tests can advance ticks without
waiting on wall time.

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
| Next: tuning-ready playable | [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) |
| Cwhip coding conventions | [CODING.md](CODING.md) |
| SDK / CMake / project shell | [BUILDING.md](BUILDING.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
