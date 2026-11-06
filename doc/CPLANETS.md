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
| `cplanets` | Human client — GTK **list debugger** (planets / fleets / digest / policy). Never ticks. |
| `cplanets-ai` | Stand-alone AI client on the same protocol. Own config file. Never ticks. |
| `cplanets-tick` | Headless identity / future N-tick host stub (no TCP, no GTK). |

Bare invocation (no flags) of each production binary prints the
program name and the shared lib identity string — useful as a smoke
check after build.

**Map canvas (Phase I) is not available yet.** The human UI is a list /
notebook debugger only — no planet grid DrawingArea, pan/zoom, or
hot-spot map.

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
bin/cplanets-server --serve [--port N] [--players N] [--injectable] [--cycles N]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--serve` | (required for play) | Bind TCP and run accept + cadence loop |
| `--port N` | `0` (ephemeral) | Listen port; `0` picks a free port |
| `--players N` | `2` | Seat count for the closed start galaxy |
| `--injectable` | off | Test clock (admin advance); CI / harnesses |
| `--cycles N` | `0` (run until stop) | Cap accept/serve loop iterations |

On start it prints `PORT=<n>` (and `INJECTABLE=0|1`). Use that port for
clients. Live `--serve` currently seeds a closed galaxy in-process
(world count / seat count from the driver); it does not yet take a
scenario file path on the CLI.

### `cplanets` (human)

```text
bin/cplanets --config config/human-default.cfg [flags…]
```

| Flag | Meaning |
| --- | --- |
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

### `cplanets-ai`

```text
bin/cplanets-ai --config config/ai-default.cfg [flags…]
```

| Flag | Meaning |
| --- | --- |
| `--config PATH` | AI config (not human settings) |
| `--host HOST` / `--port N` | Dial overrides |
| `--once` | Print one local policy shape (no TCP) |
| `--serve-loop` | Dial and PUT policy for `--cycles N` (needs `port > 0`) |
| `--cycles N` | Loop attempts (default `1`, min `1`) |

### `cplanets-tick`

```text
bin/cplanets-tick
```

Prints name + lib identity. No advance-N CLI yet; lib tick coverage
lives in `tests/unit/` and `tests/fn/`.

---

## Typical stand-alone flow

Three terminals (or background jobs): server, human, AI.

```sh
# 1) Server — note the printed PORT=
bin/cplanets-server --serve --port 7700 --players 2

# 2) Human list debugger (seat 0)
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --player 0 --gui

# 3) AI client (adjust player_id in the AI config for seat 1)
bin/cplanets-ai --config config/ai-default.cfg \
  --host 127.0.0.1 --port 7700 --serve-loop --cycles 20
```

Without a display, use `--pull` / `--once` on the human binary and
`--once` or `--serve-loop` on the AI. For automated harnesses, add
`--injectable` on the server so tests can advance ticks without
waiting on wall time.

---

## Config and fixtures

| Path | What |
| --- | --- |
| `config/human-default.cfg` | Human dial defaults (`player_id`, `host`, `port`) |
| `config/ai-default.cfg` | AI axes (aggression, lag, surprise, …) plus dial |
| `scenarios/closed-default.setup` | Closed-scenario magnitude fixture (tick period, galaxy, combat/tech knobs, …) |

Config and scenario files use simple `key = value` application text.
Pass client configs with `--config`. The closed setup file is the
checked-in scenario fixture (parser / machine defaults / tests); the
live server CLI does not yet load it by path.

Tests that exercise binaries live under `tests/unit/`, `tests/fn/`,
and `tests/functional/` (Python spawns `cplanets-server` and talks
the wire protocol).

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
