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

`--config PATH` is **mandatory** on every production binary. Missing
or empty path prints the same help as `-h` / `--help` and exits **2**.
With a config whose mode flags are off (`serve` / `once` / … false),
each binary prints its program name + shared lib identity — useful as
a smoke check after build (`--config config/…-default.cfg`). All four
user-facing binaries parse argv with the Cwhip stdlib `cli` package
(`import cli as Cli`); `--help` / `-h` prints generated usage and
exits **0**. Unknown flags fail loud (exit 2).

**Planned follow-on (not implemented):** when `--config` is omitted,
auto-load a default config from the user's home directory. Until that
lands, always pass an explicit `--config PATH`.

**Map canvas (Phase I) ships** as the main DrawingArea panel; former
list notebook tabs open from the **View** menu as non-modal dialogs.
Hot spots, status colors, dotted in-flight ETA paths when published,
mouse pick/pan/zoom, Scrollbars, and a right-click ContextMenu
(planet status + zoom-to-known). Remaining GTK polish (dash/text
paint, config-driven setup UI) is listed in
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

`--config PATH` is **required**. Every other command-line parameter
may also be set as a default in that file. Load the file first; any
flag **present on argv** overrides the corresponding file value
**silently** (no warning). The server uses one unified `--config`
(process/network **and** §14 scenario knobs). Legacy `setup=` /
`--setup` are removed — see [SERVER-CONFIG.md](SERVER-CONFIG.md).
`--config` is the only path without an in-file default.
`cplanets-tick` has a placeholder config (`config/tick-default.cfg`)
and no advance-N value flags yet.

**Planned:** home-directory default config when `--config` is
omitted — not implemented; keep passing `--config` explicitly.

### `cplanets-server`

```text
bin/cplanets-server --config config/server-default.cfg [flags…]
```

| Flag | Default | Config key | Meaning |
| --- | --- | --- | --- |
| `-h`, `--help` | — | — | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | *(required)* | *(path only)* | Unified server + §14 config ([SERVER-CONFIG.md](SERVER-CONFIG.md)) |
| `--serve` | off | `serve` | Bind TCP and run accept + cadence loop |
| `--host ADDR` | `127.0.0.1` | `host` (alias `address`) | Listen bind address |
| `--port N` | `7700` (sample) | `port` | Listen port; `0` still picks an ephemeral free port (CI / harnesses) |
| `--players N` | `0` | `players` | Soft max allocated seats (`0` = unlimited; grow on connect). Also expected-ceiling hint in status; does not delay go. |
| `--seed N` | `7` | `seed` | PRNG seed for the start galaxy layout |
| `--verbosity N` | `0` | `verbosity` | Stdout log level 0–10 (clamped) |
| `--handshake-miss-ms N` | `5000` | `handshake_miss_ms` | Presence drop window (ms) |
| `--accept-poll-ms N` | `50` | `accept_poll_ms` | Accept/recv poll grain (ms) |
| `--injectable` | off | `injectable` | Test clock (admin advance); CI / harnesses |
| `--cycles N` | `0` (run until stop) | `cycles` | Cap accept/serve loop iterations |

**Lobby / go (while serving):** the server starts in **lobby**
(`PHASE=lobby`) after loading the unified config.
TCP accept, seat allocate (grow-on-connect), reconnect tokens, and
the status menu work, but **wall ticks do not advance** (and the
game clock stays at tick 0) until the operator starts the game —
the first client connect does **not** leave lobby, does **not**
accept explore/build/design play verbs, and publishes chrome
`paused=true` so clients see the hold. End-of-game checks
(all-humans-quit / eliminate-all) also wait until go — connecting
an AI in lobby must not end the server. Later clients may still
connect and get seats while in lobby. Lobby miss-drop clears
the reconnect token so a restarted client reuses the seat (no ghost
seats); after go, drop keeps the token for reclaim. Type **`g` then
Enter** on the server console (banner prints `GO_KEY=g`) — or choose
**Go** in the status menu — to leave lobby (`PHASE=running`). Go
starts with **whatever seats are already allocated**; it does not
wait for `--players` / soft max. Harnesses may `PUT /admin/go`
(same path). Later “all humans ready” can share that path; v1 is
operator go only. Injectable `/admin/advance` is also blocked until
go. AI clients allocate with handshake kind=`1` (marked non-human).

**Seats / `players`:** live serve starts with **zero** seats and
**grows** a seat on empty-body handshake when needed. `players` /
`--players` is an **optional soft max** (`0` = unlimited within a
practical bound). Soft max rejects allocate only when set and full.
Status summary shows `seated=N softMax=M` (or `softMax=unlimited`).
Closed eliminate-all counts only **allocated** seats (never-connected
soft-max slots do not exist in the list).

**Status menu (while serving):** type `m` then Enter on the server
console (banner prints `MENU_KEY=m`). Opens a read-only in-process
console over the live State — phase / tick / pause / seated vs soft
max summary, players (wealth, owned planets/fleets/ships), planet and
fleet detail, designs / yard jobs, and a dump of loaded server +
scenario knobs. In lobby the menu also offers **Go**. Config
create/save is out of scope. **Ticks pause while the menu is open**
and the prior pause flag is restored on `q` (clients can wait). From
lobby, menu **`g` leaves lobby, closes the menu, and restores pause**
so wall ticks may advance — it must not stay in a non-lobby menu with
clients still held. The serve loop polls stdin non-blocking between
accepts and **drains stray / blank console lines** each cycle so a
junk keystroke (or bare Enter) then `m` still opens the menu
(`StdinPoll.pending` also sees bytes already buffered by stdio after
a prior read). TCP accept is not blocked forever waiting for menu
input.

**Bind address:** default `127.0.0.1` (loopback), matching the
prior hard-coded TCP listen. Set `host = 0.0.0.0` (or CLI
`--host 0.0.0.0`) to listen on all interfaces. Empty `host` in a
config file clamps back to `127.0.0.1`.

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

Process/network **and** §14 galaxy knobs live in one
`config/server-*.cfg` ([SERVER-CONFIG.md](SERVER-CONFIG.md)).
`scenarios/*.setup` are reference fragments only (not loaded by
path). CLI flags present on argv overlay process keys silently.
Missing/unopenable `--config` is a hard error (no silent builtin).

On start it prints `HOST=<addr>`, `PORT=<n>`, `CONFIG=<path>`,
`SCENARIO_MODE=<mode>`, `SEED=<n>`, `PLAYERS=<n>`, `CYCLES=<n>`,
`VERBOSITY=<n>`, and `INJECTABLE=0|1`. Use that port for clients.
Unknown keys fail loud and the process exits before listen.
**Knob edits take effect on process restart** — there is no
mid-game retune in v1 (RULES §14 lock-in-progress).

### `cplanets` (human)

```text
bin/cplanets --config config/human-default.cfg [flags…]
```

| Flag | Config key | Meaning |
| --- | --- | --- |
| `-h`, `--help` | — | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | *(required; path only)* | Human settings file (not the AI config) |
| `--host HOST` | `host` | Dial host |
| `--port N` | `port` | Dial port (`> 0` for TCP) |
| `--player N` | `player_id` | Offline seat id only (`--once` / `port 0`); TCP seats are server-assigned on handshake |
| `--once` | `once` | In-process closed galaxy; print list summary (no TCP, no GTK) |
| `--pull` | `pull` | TCP GET state + digest summary (needs `port > 0`) |
| `--gui` | `gui` | GTK map + top-level menubar panel dialogs |
| `--test` | `test` | GTK path that auto-quits after a short schedule |

With `--gui` / `--test` and `port > 0`, the client pulls from the
server; otherwise (`port = 0`) it prefills an offline closed galaxy.
Sample configs use **port 7700** so a normal play session matches the
server without extra flags. A failed TCP connect / pull prints
`cplanets: cannot connect to HOST:PORT` (or `no state from …`);
`--pull` exits **1**. `--gui` / `--test` also show an `AlertDialog`
with the same host:port detail (status line updated; `--test` skips
the dialog so auto-quit stays quiet).

**Tuning-loop chrome (workstream B + ship create + map):** Pause
CheckButton (sensitive only with exactly one human; `PUT /pause`).
Open former Notebook surfaces from **top-level menubar** root
clicks (non-modal dialogs; no nested Open). **Fleets** Entries +
Dispatch / Recall (`PUT /order`, `PUT /recall`) for explore / take /
trade / move / ambush / recall — in-flight fleets show `LOCKED` and
Dispatch is disabled until Recall. **Fleet id** defaults to the
lowest sitting owned stack (never `0`; yard builds merge into /
spawn that sit fleet — Refresh if the list looks stale). **Hulls to
send** (`0` = whole sitting stack) peels a subset when yard builds
have merged same-design hulls into one sit fleet, so you can send 2
of 4 to planet 1 and the rest elsewhere. Rejected dispatch shows a
clear reason (missing fleet, not sitting, …). **Ships** (design /
yard): inspect the published design catalog and owned yards; **Start
develop** (`PUT /design`) queues timed design development (wealth;
`design_develop_ticks`); **Queue build** (`PUT /build`) queues a
hull at a productive owned shipyard (resources; `yard_build_ticks`);
**Reclaim hulls** (`PUT /reclaim-hulls`) starts yard reclaim for a
sitting fleet. Develop/build **ProgressBars** live in the Fleets
and Ships dialogs. **Policy** Scales + Apply. **Planets**
allocation **Scale** → `PUT /budget` stores `allocationPct`; each
production tick credits empire wealth/resources from that productive
rock × `allocationPct/100` (no yard logistics). Explored-planet
dialog auto-presents when quality becomes known or
productive/populated flips; Planets dialog still has “Show first
explored”.

### `cplanets-ai`

```text
bin/cplanets-ai --config config/ai-default.cfg [flags…]
```

| Flag | Config key | Meaning |
| --- | --- | --- |
| `-h`, `--help` | — | Print stdlib `cli` usage and exit 0 |
| `--config PATH` | *(required; path only)* | AI config (not human settings) |
| `--host HOST` / `--port N` | `host` / `port` | Dial |
| `--verbosity N` | `verbosity` | stdout log level 0–10 (clamped) |
| `--once` | `once` | Print one local policy shape (no TCP; one-shot) |
| `--serve-loop` | `serve_loop` | Dial and PUT policy until eliminated / ended (needs `port > 0`). CLI form without `--cycles` forces continuous (`CYCLES=0`) even if the config still has `cycles = 1`. |
| `--cycles N` | `cycles` | Loop attempts (`0` = until eliminated/ended/stop; `N>0` caps for smoke). Required on argv to override the continuous CLI `--serve-loop` default. |
| `--loop-period-ms N` | `loop_period_ms` | Continuous serve-loop target period in milliseconds (default **100**). Each cycle measures work, then sleeps `max(0, period − elapsed)` so cadence is roughly deterministic. `0` skips leftover sleep. Distinct from `reaction_lag_ticks` / `reaction_lag_seconds` (PUT gates). Banner prints `LOOP_PERIOD_MS=`. |

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
`serve_loop`, `loop_period_ms`, dial). TCP `player_id` is not seating
authority — the server assigns on handshake. CLI flags present on
argv overlay silently. `--once` / `--serve-loop` print
`VERBOSITY=<n>` with the summary; serve-loop also prints
`LOOP_PERIOD_MS=<n>`.

**Status menu (while `--serve-loop`):** type `m` then Enter on the
AI console (banner prints `MENU_KEY=m`). Opens a read-only
in-process console over **this client's knowledge** — connection /
config dump, seat/role, last decoded GET snapshot, client-visible
planets / fleets / designs, and recent decisions / errors. Does not
invent server-only authority. **AI decision cycles pause while the
menu is open**; `q` resumes. No `--menu` flag.

### `cplanets-tick`

```text
bin/cplanets-tick --config config/tick-default.cfg
bin/cplanets-tick --help
```

`--config PATH` is required (sample: `config/tick-default.cfg`;
no keys yet). With a readable config, prints name + lib identity.
`-h` / `--help` prints stdlib `cli` usage (exit 0). Missing
`--config` prints that same help and exits 2. No advance-N CLI yet;
lib tick coverage lives in `tests/unit/` and `tests/fn/`.

---

## Typical stand-alone flow

Three terminals (or background jobs): server, human, AI.

**`--config`** is always required. **`--serve` (or server-config
`serve = true`)** is required for play. Without serve,
`cplanets-server` prints smoke identity and exits — no TCP, no
ticks. While serving, open the status menu anytime with stdin `m`.

The server uses **one request per TCP connection** (closes after each
reply). Clients redial per verb; wall-clock cadence advances even with
zero clients attached (no seat barrier). `--injectable` freezes wall
ticks until `PUT /admin/advance` (CI only).

```sh
# 0) Build (project shell; SDK via scripts/setup)
./scripts/setup
build

# 1) Server — note HOST=/PORT=/CONFIG=; process + §14 knobs in one file
bin/cplanets-server --config config/server-default.cfg --serve

# 2) Human list debugger — sample dials 127.0.0.1:7700
#    Server assigns the first free seat on handshake (usually 0).
bin/cplanets --config config/human-default.cfg --gui

# 3) AI client (aggression presets: config/ai-mid.cfg etc.)
#    Server assigns the next free seat (usually 1 after a human).
#    Continuous until eliminated / game ended / Ctrl-C.
#    While looping: type m then Enter for the AI status menu.
#    Finite smoke: add --cycles N (N > 0).
bin/cplanets-ai --config config/ai-mid.cfg --serve-loop
```

**Continuous AI play:** `--serve-loop` with `cycles = 0` (config /
CLI default) keeps the client connected and deciding until the seat
is eliminated (no owned planets after a home was seen), the published
game ends, or the process is stopped. Pass `--cycles N` (`N > 0`) for
a short smoke/harness run. Continuous cycles target
`loop_period_ms` / `--loop-period-ms` (default 100): work first, then
sleep leftover. `--once` remains the local one-shot (no TCP).

**Solo human (no AI):** leave `--players 0` (unlimited) and connect one
human — pause is offered when exactly one live human seat exists. Soft
max `--players 1` also works (rejects a second allocate). Wall ticks
still run from go with whatever is seated. Prefer
`scripts/tuning-session` (server + AI) for the documented tuning loop.

Without a display, use `--pull` / `--once` on the human binary and
`--once` or `--serve-loop` on the AI. While the AI serve-loop runs,
open its status menu anytime with stdin `m` (decisions pause until
`q`). For automated harnesses, add `--injectable` on the server so
tests can advance ticks without waiting on wall time.

**Ship create / design / yard (Ships root click):**

1. Open **Ships** (menubar root click). After handshake, confirm home
   yard (planet 0 for seat 0) and ready designs (seeded scout/colony
   are ready immediately). Homes are created when the client
   connects, not when the server starts.
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
  --config config/server-tuning-small.cfg \
  --seed 77 \
  --ai-config config/ai-mid.cfg \
  --port 7700
```

Then in another terminal:

```sh
# GTK list debugger (seat assigned on handshake)
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --gui

# or headless smoke (no display)
bin/cplanets --config config/human-default.cfg \
  --host 127.0.0.1 --port 7700 --pull
```

**Seed reproducibility:** keep `--seed` fixed (banner prints
`SEED=<n>`). The same seed + same unified `--config` yields a
comparable start galaxy after knob edits. Change seed only when you
want a new layout. AI aggression bands (`ai-soft` / `ai-mid` /
`ai-hard`) are independent of the galaxy seed.

**Unified server packs** (process + §14 — placeholders):

| Path | Role |
| --- | --- |
| `config/server-tuning-small.cfg` | Fast loops (12 worlds); default for the harness |
| `config/server-tuning-combat.cfg` | Combat-leaning A/B |
| `config/server-tuning-trade.cfg` | Trade-leaning A/B |
| `config/server-default.cfg` | Full closed baseline (24 worlds) + process defaults |

`scenarios/*.setup` remain reference fragments only (see
[SERVER-CONFIG.md](SERVER-CONFIG.md) migration).

**AI presets** (server assigns seats; no `player_id` in samples):

| Path | Band |
| --- | --- |
| `config/ai-soft.cfg` | Soft aggression / slower lag |
| `config/ai-mid.cfg` | Mid (default harness) |
| `config/ai-hard.cfg` | Hard aggression / snappier lag |
| `config/ai-default.cfg` | Legacy dial defaults |

CI / headless proof (no GTK): CTest `functional_session_harness`
spawns injectable server + AI `--serve-loop` + human `--pull`,
advances ticks, and asserts digest growth. Manual injectable:

```sh
./scripts/tuning-session --config config/server-tuning-small.cfg \
  --seed 77 --ai-config config/ai-mid.cfg --injectable --ai-cycles 4
```

### Tuning loop (restart contract)

1. Edit knobs in a unified `config/server-*.cfg` and/or an AI preset
   under `config/`.
2. Stop `cplanets-server` / `cplanets-ai` (Ctrl-C on
   `scripts/tuning-session`).
3. Restart with the **same** `--config` / `--ai-config` / `--seed`.
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
| `config/server-default.cfg` | Unified server process + §14 ([SERVER-CONFIG.md](SERVER-CONFIG.md)) |
| `config/server-tuning-*.cfg` | Tuning packs (small / combat / trade) |
| `config/human-default.cfg` | Human dial defaults ([HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md)) |
| `config/ai-default.cfg` | AI axes + dial ([AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md)) |
| `config/ai-{soft,mid,hard}.cfg` | Aggression-band presets |
| `scenarios/*.setup` | Reference §14 fragments only (not loaded by path) |

Config files use simple `key = value` application text. Unknown
keys fail loud on server/AI load (human ignores unknowns today).
Pass every binary a `--config`. Key catalogs:
[SERVER-CONFIG.md](SERVER-CONFIG.md),
[AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md),
[HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md).

Tests that exercise binaries live under `tests/unit/`, `tests/fn/`,
and `tests/functional/` (Python spawns `cplanets-server` and talks
the wire protocol; `functional_setup_path` covers unified §14 keys;
`functional_session_harness` covers config + seed + AI join).

---

## Further reading

This file is for **users and operators**.

| Audience | Doc |
| --- | --- |
| Server config keys + ranges | [SERVER-CONFIG.md](SERVER-CONFIG.md) |
| AI client config keys + ranges | [AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md) |
| Human client config keys + ranges | [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md) |
| Game rules / machine spec | [RULES.md](RULES.md) |
| Implementation order & phases | [PLAN.md](PLAN.md) |
| Next: playable + knobs (then balance) | [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) |
| Knob inventory (textfile / GUI tags) | [KNOB-COVERAGE.md](KNOB-COVERAGE.md) |
| Cwhip coding conventions | [CODING.md](CODING.md) |
| SDK / CMake / project shell | [BUILDING.md](BUILDING.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
