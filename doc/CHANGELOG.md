# Changelog

## Unreleased

- **CPL-118 lobby waits; human Pause starts; deferred AI spawn:**
  server stays in lobby (published paused, no ticks / play verbs)
  until start. **Normal start** is the human Pause CheckButton —
  unchecking Pause (`PUT /pause` 0) calls shared `go()`. Console
  `g` / status-menu Go / `PUT /admin/go` remain as fallback.
  Configured `ai-client` children spawn **after the first live
  human connects** (or on go for AI-only), not at listen/start.
  Docs: [RULES.md](RULES.md), [CPLANETS.md](CPLANETS.md),
  [SERVER-CONFIG.md](SERVER-CONFIG.md). Tests: `unit_lobbyHumanPause`,
  `functional_lobby_hold`, `functional_ai_spawn_defer`.
- **CPL-117 server bind + incomplete XDG heal:** mark the TCP listen
  socket `FD_CLOEXEC` so spawned `cplanets-ai` children no longer
  inherit it (orphans were holding `127.0.0.1:7700` → opaque
  `bind failed` on the next start). Bind failures now print
  `host:port` (and `System.lastError` when set). Incomplete
  *generated* `~/.config/cplanets/server.cfg` stubs (XDG header,
  missing CPL-116 keys) are rewritten on the next omit-config
  start; hand-edited files without that header are left alone.
  Docs: [SERVER-CONFIG.md](SERVER-CONFIG.md). Tests:
  `unit_xdgDefaults`, `functional_cli_config_defaults`.
- **CPL-116 full XDG server.cfg key set:** auto-generated
  `~/.config/cplanets/server.cfg` (and `config/server-default.cfg`)
  list every process/network and §14 key the server understands,
  with closed defaults — not a partial pack. Still keeps
  `--config`, explicit `ai-client = "name", level`, and the three
  AI + human XDG files from CPL-115. No GUI server-config dialog.
  Docs: [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [CPLANETS.md](CPLANETS.md). Tests: `unit_xdgDefaults`,
  `functional_cli_config_defaults`.
- **CPL-115 XDG defaults + explicit AI clients:** when `--config` is
  omitted, `cplanets-server` / `cplanets` / `cplanets-ai` ensure and
  load defaults under `~/.config/cplanets/` (`server.cfg`,
  `human.cfg`, `ai-{soft,mid,hard}.cfg`). Keep `--config` as an
  override; tick still requires it. No GUI server-config dialog.
  Replace `spawn_ai_count` / `spawn_ai_template` with repeatable
  `ai-client = "FriendlyName", level` (level optional → soft;
  template `ai-<level>.cfg`). Friendly name is the in-game
  `display_name`. Docs: [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md),
  [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md),
  [CPLANETS.md](CPLANETS.md). Tests: `unit_serverConfig`,
  `unit_xdgDefaults`, `functional_cli_config_defaults`.
- **CPL-114 productive = positive net income:** a planet is
  **productive** iff structural combined net (farming + industry at
  full intensity) is **> 0**. Owned populated habit-complete rocks
  still apply per-tick net (may debit); the flag gates inherent
  defense / yard produce. Time-to-productive uses planet
  quantity×accessibility gated by global fairness knob
  `productive_rate` (default `1.0`; higher → faster). Low-habit
  rocks may need industry before they qualify. Docs:
  [RULES.md](RULES.md) §2 / §7 / §11, [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md).
- **CPL-113 per-planet net income:** productive rocks apply
  `net = production credit − upkeep` into empire wealth/resources.
  Credit still scales with accessibility; upkeep scales with
  `accessDifficulty` (`1/access`). Net may be negative (ongoing
  debit). Empire pools clamp at 0 when debit exceeds stock
  (galaxy index order). Knobs: `wealth_upkeep_tick_rate`,
  `resources_upkeep_tick_rate` (default `0.003`; `0` = credit-only).
  Docs: [RULES.md](RULES.md) §2 / §7, [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md), [DIALOGS.md](DIALOGS.md).
- **CPL-112 planetary resources / accessibility:** each rock carries
  air, water, common minerals, rare minerals with per-resource
  accessibility. Farming (air+water) credits empire wealth; industry
  (minerals) credits empire resources — stocks stay empire-wide.
  Low mineral access raises yard cost/time; low air/water access
  raises colony habit wealth cost and terraforming ticks. Wire +
  explored dialog publish 1–10 quantities and access. Setup knobs:
  `rare_mineral_weight`, `access_min` / `access_max` / `access_floor`,
  `habit_base_ticks`, `habit_base_wealth_cost`. Docs:
  [RULES.md](RULES.md) §2–§3 / §13, [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md).
- **CPL-111 Ships/Fleets/Empire UI:** DropDown selection sticks across
  refresh; Develop defaults kind to **scout**; Build adds qty (extra
  hulls add `yard_build_extra_hull_time_frac`, default 10%) and lists
  only seat-developed ready types (no phantom scout/colony);
  home grant stages unassigned scout stock (no phantom fleet named
  `starter`); Fleets→Assign removed — Assign/Un-assign live in
  Fleets→Inventory with planet scope + multi-select stock;
  `PUT /unassign`; Empire top-level Apply+Close inventory dialog.
  Docs: [DIALOGS.md](DIALOGS.md), [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [CPLANETS.md](CPLANETS.md), [RULES.md](RULES.md) §2 / §16.
- **CPL-110 Ships/Fleets submenu dialogs:** replace monolithic Ships
  and Fleets panel dialogs with MenuBar submenus of smaller
  non-modal Apply+Close dialogs — Ships → Develop / Build / Reclaim /
  Inventory; Fleets → Create / Assign / Deploy / Inventory.
  Develop/build/reclaim ProgressBars live in the matching Ships
  dialogs; Deploy keeps travel ProgressBar. Inventory dialogs select
  a type/fleet and Apply examines. Map dispatch raises Deploy.
  Docs: [DIALOGS.md](DIALOGS.md), [CPLANETS.md](CPLANETS.md),
  [RULES.md](RULES.md) §16.
- **CTest: functional harness state parse:** `functional_setup_path`
  and `functional_session_harness` skipped the CPL-106 seat
  `displayName` string on published player rows, mis-read
  `policy_count` as huge, and burned CPU until the CMake TIMEOUT
  (~45s / ~90s) with empty output. Parsers now skip the wire
  string and bound counts so misalignment fails fast. Note:
  `spawn_ai_*` children are only reaped via `AiSpawnBook.closeAll`
  on a normal serve return — SIGTERM/SIGKILL of the server (common
  in harness teardown) can leave `cplanets-ai` orphans.
- **CPL-108 last-human exit:** lobby `go` retire no longer clears
  `human` on abandoned seats (that made `allHumansGone` treat the
  session as a pure-AI fixture and blocked exit). `go()` refreshes
  end-status immediately after leaving lobby so the last departed
  human ends with `all_humans_quit` even when AI remain (RULES §2).
  Live humans still keep the session up. Human allocate restores
  `human=true` when reusing a free former AI seat. Human File→Quit
  sends `PUT /quit`. Test: `unit_humanSeatGo`.
- **CPL-107 hide undiscovered foreign planets:** seat fog no longer
  treats global `Planet.qualityKnown` as visibility. Foreign-owned
  rocks stay hidden until in detection range of an owned world or
  discovered by that seat (explore/take/home → `exploredPlanetIds`).
  Published `qualityKnown` is seat-scoped; fog-hidden rows redact
  owner/coords/name on the wire. Digest events are filtered the same
  way. Human/AI map, lists, and digest already honor `visible`. Docs:
  [RULES.md](RULES.md) §13. Test: `unit_planetFog`.
- **CPL-106 player names + server AI spawn:** every seat has a
  `displayName` (human `display_name` from human config via
  `PUT /name`; AI uses config `display_name` or a random proper
  name from the Alex/Bethany/… pool). Published on `GET /state`
  and shown in chrome/digest/status. Server keys `spawn_ai_count`,
  `spawn_ai_template`, `spawn_ai_dir`, `spawn_ai_bin` launch N
  `cplanets-ai` children via Cwhip `process` (`AsyncProcess`), each
  with its own generated config + unique name. Docs:
  [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md),
  [AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md). Tests:
  `unit_playerNames`, `unit_displayName`, config units.
- **CTest: `unit_aiStatusMenu`:** fixture expects named planet-0
  `"Home"` (and a named fleet) after DropDown/name chrome; stale
  `planetDetail` assert looked for `"Planet"`.
- **CTest: ship inventory / design yard:** stop auto-closing
  never-built player designs each tick (`maybeFreeDesign` now runs
  only after a reclaim completes). Fixes `fn_combatDesigns` and
  `functional_design_yard` (develop never reached ready). Also fix
  `unit_shipInventory` compile (`players[0].wealth` any member
  access). Inventory model unchanged (unassigned stock + named
  fleets).
- **CPL-101 ship-build / fleet-dispatch model:** develop is a noop when
  the same parameters already exist for that seat (silent OK);
  type names unique per player and freed when all hulls of that name
  are reclaimed (count→0, design closed). Builds add to **unassigned**
  hull stock at the yard planet (owner + design + planet) — not into a
  fleet. Fleet create parks a named empty container at an owned
  planet; assign moves type+qty from unassigned stock at that same
  planet into the fleet (over-assign → error dialog). Dispatch leaves
  from the fleet’s sitting location (range-from-occupied-world intact);
  travel rate = slowest hull in the fleet. No abstract no-location
  hangar; empire pool only; no Inventory screen — Ships/Fleets show
  type inventory + fleets + unassigned line. Docs: [RULES.md](RULES.md)
  §2 / §5 / §5.3 / §16, [DIALOGS.md](DIALOGS.md).
- **Human GUI periodic refresh (`refresh_ms`):** live `--gui` polls
  `GET /state` + `GET /digest` on a settable period so develop/build
  ProgressBars and list chrome update without File→Refresh. Config
  key `refresh_ms` (default **1000**; `0` = off) and CLI
  `--refresh-ms` (argv overlays). Wire stays pull-only; presence
  keep-alive handshake (~2s) remains a separate timer. Timed-pull
  failures stay quiet; File→Refresh still alerts. Docs:
  [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md),
  [CPLANETS.md](CPLANETS.md). Test: `unit_clientConfig`.
- **Human seat + operator go:** lobby miss-dropped human seats
  (token cleared) are retired on `g` / `PUT /admin/go` so a ghost
  seat cannot end the session while another **live** human remains.
  Human GUI schedules a presence keep-alive handshake (~2s) so an
  idle window does not drop its seat before go; `--pull` fails
  loudly when handshake cannot allocate a seat. (CPL-108 restores
  last-human `all_humans_quit` when no live human remains, including
  with AI still connected — see Unreleased CPL-108.) Test:
  `unit_humanSeatGo`.
- **Panel menubar root clicks:** Planets / Fleets / Ships / Digest /
  Policy open their non-modal dialogs on the root label click (flat
  Buttons beside File). No nested **Open** submenu — GtkPopoverMenuBar
  cannot host leaf actions as top-level GMenu entries. File stays a
  real MenuBar submenu. Map ContextMenu dispatch/budget still raises
  Fleets / Planets. Docs: [DIALOGS.md](DIALOGS.md),
  [CPLANETS.md](CPLANETS.md).
- **Top-level panel menubar openers:** former Notebook tabs
  (Planets / Fleets / Ships / Digest / Policy) moved off View onto
  top-level menubar chrome. Hide-on-close `GuiPanelDialog`
  TransientWindows. Map canvas remains the main panel.
- **Inventory model locked in RULES (superseded by CPL-101 above for
  ship assign path):** empire inventory = seat stocks + designs
  (empire pool only); planet inventory = location-scoped presence
  (defenses, yard jobs, flags, allocation) — not a second bank. No
  Inventory screen. Ship assign/send is now unassigned stocks + named
  fleets (see CPL-101). Docs: [RULES.md](RULES.md) §2 / §5 / §16.
- **Unified server config:** process/network and former §14 scenario
  knobs live in one `--config` file (`config/server-*.cfg`). Legacy
  `setup = PATH` is rejected with a migration hint; CLI `--setup` is
  removed. Missing/unopenable `--config` is a hard error (no silent
  builtin). New process keys: `recv_buffer_bytes`, `seat_hard_cap`,
  `verbose_capture_lines`; CLI overlays for `handshake_miss_ms` /
  `accept_poll_ms`. Banner: `CONFIG=` + `SCENARIO_MODE=` (no
  `SETUP=`). Tuning packs: `config/server-tuning-{small,combat,trade}.cfg`.
  Docs: [SERVER-CONFIG.md](SERVER-CONFIG.md),
  [AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md),
  [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md).
  `scenarios/*.setup` remain reference fragments only.
- **AI serve-loop period (`loop_period_ms`):** continuous
  `--serve-loop` replaces the hard-coded 100 ms sleep with a
  settable frame budget. Config key `loop_period_ms` (default
  **100**) and CLI `--loop-period-ms` (argv overlays). Each cycle
  measures work then sleeps `max(0, period − elapsed)`; `0` means
  no leftover sleep. Finite `--cycles N` stays snappy (no period
  sleep). Banner prints `LOOP_PERIOD_MS=`. Distinct from
  `reaction_lag_ticks` / `reaction_lag_seconds`. Samples under
  `config/ai-*.cfg` and `tests/config/ai-*.cfg`. Tests:
  `unit_aiConfig`, `unit_aiStatusMenu`, `functional_ai_loop_period`.
- **CTest headless configs + stdin EOF:** smoke / functional harnesses
  use `tests/config/*` (gui=false, serve=false / port 0 as needed) so
  ctest does not open human GTK windows or dial operator port 7700.
  `cplanets_stdin_pending` no longer treats EOF POLLIN (`/dev/null`
  under ctest) as ready input, which had starved the TCP accept loop
  (truncated handshake envelopes). Design/yard harness calls operator
  go before play verbs. Lobby-until-go unchanged.
- **Lobby hold on live serve loop:** connect still leaves
  `PHASE=lobby` / `tick=0`, and play verbs (`/order`, `/build`,
  `/design`, `/recall`, `/reclaim-hulls`, `/budget`) are rejected
  until operator `g`. Published GET /state chrome reports
  `paused=true` while in lobby so AI/human clients do not treat
  connect as serve-start (AI skips explore/build while paused).
  Regression: `functional_lobby_hold` (real TCP serve loop, with
  and without scenario) plus tightened `unit_lobbyHoldGhosts`.
- **Lobby hold + no ghost seats:** lobby stays until operator `g`
  with or without a scenario; first/later client connects allocate
  seats but do not start the game clock. Lobby miss-drop / explicit
  drop clears reconnect tokens so abandoned seats are reused (no
  ghost grow when an AI/human restarts without the in-memory token);
  after go, drop still keeps tokens for reclaim. Human/AI clients
  keep the token on empty/network handshake failure and only clear
  it after an explicit reject ack. Unit: `unit_lobbyHoldGhosts`
  (also updates `unit_homeOnConnect`).
- **AI fleets explore + human examine (Section C):** every seated
  empire now receives the RULES §2 starter scout fleet (not only
  seat 0). The AI serve-loop issues `PUT /order` (explore / take)
  and `PUT /build` from the decoded GET snapshot via `AiOrderPlan`
  — opaque policy blobs alone never moved fleets. Human Fleets /
  Ships tabs gain **Examine fleet** / **Examine design**
  TransientWindows (same hide-on-close pattern as explored
  planets). Units: `unit_aiOrderPlan`, `unit_fleetExamine`,
  `unit_homeOnConnect`.
- **Status menu Go / stdin flush:** from lobby, status-menu **`g`**
  leaves lobby **and closes the menu** so the prior pause flag is
  restored and clients are not left held in a non-lobby menu.
  Top-level **`q`** still resumes without go. The serve stdin gate
  drains stray / blank console lines each cycle (blank Enter is not
  EOF) so a junk keystroke then `m` still opens the menu.
  `StdinPoll.pending()` also treats stdio-buffered bytes as ready
  (piped `x` then `m` after one `readLine`). Functional CTests use
  repo-root working directory so relative `setup=` resolves under
  `ctest --test-dir build`. Docs: [CPLANETS.md](CPLANETS.md).
  Tests: `functional_status_menu`.

- **Lobby AI connect abort:** lobby no longer runs end-status
  (all-humans-quit / eliminate-all) before operator go, so a
  connecting AI cannot tear down the server on handshake_miss.
  Wall/injectable ticks stay gated on go. AI allocate uses a
  1-byte handshake kind=`1` so the seat is marked non-human;
  AI serve-loop re-handshakes each cycle for presence keep-alive.
  Unit: `unit_lobbyAiConnect`.

- **Dynamic seats / soft max `players`:** live serve starts with
  **zero** seats and **grows** on empty-body handshake allocate.
  `players` / `--players` is an **optional soft max** (`0` =
  unlimited within a practical bound) and an expected-ceiling hint
  in the status banner (`seated=N softMax=…`). Soft max rejects
  allocate only when set and full. Operator `go` starts with
  whatever seats are already allocated. Closed eliminate-all counts
  only allocated seats. Default soft max is `0` (former hard
  `players=2` no longer aborts a third AI). Docs: [RULES.md](RULES.md),
  [CPLANETS.md](CPLANETS.md). Unit: `unit_dynamicSeats`.

- **Lobby until go + reconnect tokens:** server starts in **lobby**
  (TCP accept, seating, status menu; **no wall ticks** until go).
  Operator starts with console **`g`+Enter** (`GO_KEY=g`), status-menu
  **Go**, or harness `PUT /admin/go` (shared path; v1 = operator go
  only). Injectable `/admin/advance` is also blocked until go.
  Allocate handshake issues an opaque **16-byte** reconnect token in
  the ack (`accepted + tick + ended + playerId + token`). Reclaim by
  sending the token; empty handshake cannot steal a token-held
  dropped seat. Tokens remain valid until quit or game end. Human and
  AI clients store/send the token. Docs: [RULES.md](RULES.md),
  [CPLANETS.md](CPLANETS.md), [SYNTAX.md](SYNTAX.md). Tests:
  `unit_lobbyReconnect`, `unit_homeOnConnect`, `fn_server`.

- **Server allocates seats on connect:** `PUT /handshake` no longer
  takes a client seat claim as authority. Empty body assigns the
  first free never-seated seat; response includes assigned
  `playerId` (and now a reconnect token — see above). Config
  `player_id` / `--player` are offline-only. Docs:
  [RULES.md](RULES.md), [CPLANETS.md](CPLANETS.md).

- **AI continuous serve-loop:** `--serve-loop` with `cycles = 0`
  (default) keeps `cplanets-ai` deciding until the seat is
  eliminated, the game ends, or the process is stopped. CLI
  `--serve-loop` without `--cycles` forces `CYCLES=0` even when a
  sample/stale config still has `cycles = 1`. `--cycles N` (`N > 0`)
  remains the finite smoke/harness cap; `--once` stays the local
  one-shot. Config samples and `scripts/tuning-session` updated.
  Docs: [CPLANETS.md](CPLANETS.md). Unit: `unit_aiConfig`,
  `unit_aiExploreStop`. Functional: `functional_ai_serve_continuous`.

- **Suspended / AFK presence flag:** `PUT /suspended` (body:
  `playerId` u32 + `flag` u8). While `suspended=1`, the seat stays
  connected and **handshake_miss does not drop** it; normal AFK
  rules still apply (last policy held; production shrink after
  timeout). Clear with `flag=0` to resume miss drop. AI status menu
  sets suspended on open and clears on close; human GUI has an
  **AFK** CheckButton. Server status player detail shows
  `connected` / `suspended`. Docs: [RULES.md](RULES.md). Tests:
  `unit_serverPresence`, `fn_server`.

- **Home yards on connect:** the server no longer pre-seeds player
  home planets at scenario start. `PUT /handshake` (human or AI)
  grants that seat's home yard + the primary seat's starter scout
  fleet. Drop / AFK / quit leave a granted home in place. Unseated
  seats are not eliminated for zero planets; closed eliminate-all
  waits until every configured seat has been seated at least once.
  Docs: [RULES.md](RULES.md), [PLAN.md](PLAN.md),
  [CPLANETS.md](CPLANETS.md). Unit: `unit_homeOnConnect`.

- AI client **status menu** while `--serve-loop`: type `m` then Enter
  on the AI console (`MENU_KEY=m`). Read-only explore of this client's
  knowledge — connection/config, seat/role, last decoded GET snapshot,
  client-visible planets/fleets/designs, decisions/errors. Decision
  cycles pause while open; `q` resumes. Reuses server `StdinPoll`.
  No `--menu` flag. CTest: `unit_aiStatusMenu`,
  `functional_ai_status_menu`. Docs: [CPLANETS.md](CPLANETS.md).

- Operator **status menu** while serving: type `m` then Enter on the
  server console (`MENU_KEY=m`). Read-only in-process console over
  the live State — status summary, players → inventory drill-down,
  planets, fleets, designs/jobs, config dump (no write/save). Ticks
  pause while open; prior pause restored on `q`. No `--menu` / config
  `menu` flag (removed). CTest: `unit_statusMenu`,
  `functional_status_menu`. Docs: [CPLANETS.md](CPLANETS.md).

- Develop / yard-build **ProgressBars**: Ships and Fleets pages show
  `Gtk.ProgressBar` footers (fraction from ticksLeft / setup total;
  pulse when duration unknown) refreshed on each snapshot pull.
  Detail Label keeps reclaim + multi-job text. Footer Box is
  dialog-ready for the near-term menubar / non-modal rearrange.
  Docs: [DIALOGS.md](DIALOGS.md), [GTK-FEATURE-GAPS.md](GTK-FEATURE-GAPS.md).

- Dispatch after yard build: Fleets **Fleet id** Entry defaults to
  `1` and re-pins to a sitting owned stack when empty/`0`/stale
  (fleets never use id `0` — that looked like “fleet does not exist
  yet” after builds). Yard completion still merges/spawns sit
  fleets as before. `PUT /order` reject ack carries a reason
  (`fleet N does not exist`, not sitting, …); GUI AlertDialog +
  server verbosity ≥3 show it. Unit: `unit_orderReject`.

- Split-dispatch sitting stacks: Fleets tab **Hulls to send**
  Entry (`0` = whole fleet) peels a subset from a multi-hull sit
  fleet (yard builds merge same-design hulls) before `PUT /order`.
  Trailing wire `hulls` u32 is optional for older bodies. Clear
  status / `AlertDialog` on reject. Unit: `unit_splitDispatch`.
  Docs: [DIALOGS.md](DIALOGS.md), [CPLANETS.md](CPLANETS.md).

- Ships **Start develop** / explored-dialog fix: explored
  `TransientWindow` hides on Close (cdbg pattern) instead of
  destroy-then-present; Yard planet Entry re-pins to first owned
  yard (home **0**) when stale; develop/build/reclaim status ack
  survives `refreshLists`; failures use AlertDialog; server
  verbosity ≥3 logs design/build/reclaim. CTest: existing
  `functional_design_yard` + GUI smoke on Elija.

- Sample play port **7700** (was `0` / ephemeral lookalike) in
  `config/server-default.cfg`, `config/human-default.cfg`, and
  `config/ai-*.cfg`. Server still accepts `port = 0` / `--port 0`
  for ephemeral CI binds. Human client no longer fails silently on
  TCP connect/pull: prints `cannot connect to HOST:PORT` (or
  `no state from …`); `--pull` exits **1**; `--gui` shows
  `AlertDialog` + status (`--test` skips the dialog). Docs:
  [CPLANETS.md](CPLANETS.md). CTest: `functional_client_connect_fail`.

- Map pick-to-dispatch: primary map pick fills Fleets dest Entry;
  ContextMenu “Dispatch fleet here” reuses `PUT /order`; owned-rock
  “Budget this planet” fills Planets allocation chrome. Docs:
  [DIALOGS.md](DIALOGS.md). Client-only.

- Phase I map canvas: `GuiMapPage` DrawingArea in a main-window
  `Paned` beside the list notebook; publish planet `x`/`y` milli and
  fleet `outboundEta`; status colors; dotted in-flight ETA paths;
  mouse pick/pan/zoom; Scrollbars; ContextMenu status + zoom-to-known.
  Docs: [PLAN.md](PLAN.md) §4.I, [CPLANETS.md](CPLANETS.md),
  [DIALOGS.md](DIALOGS.md). CTest: `unit_mapMath` (+ publish decode
  coord asserts).

- Mandatory `--config PATH` on all user-facing bins
  (`cplanets-server`, `cplanets`, `cplanets-ai`, `cplanets-tick`):
  missing or empty path prints the same help as `-h` and exits **2**;
  `-h` still exits **0**. Tick gains `--config` plus sample
  `config/tick-default.cfg` (placeholder; no keys yet). Mode-off
  configs still smoke (name + lib identity). Docs:
  [CPLANETS.md](CPLANETS.md), [CODING.md](CODING.md). CTest smoke +
  functional harnesses pass `--config`;
  `functional_cli_config_defaults` asserts missing-config → help/2.
  **Planned (not implemented):** auto-load a default config from the
  user's home directory when `--config` is omitted.

- Server runtime config file (preference): process/network knobs
  move out of scenario setup into `config/server-default.cfg`
  (`setup`, `host`/`address`, `port`, `players`, `seed`, `serve`,
  `cycles`, `injectable`, `verbosity`). CLI `--config PATH` is the
  only path without an in-file key; `--setup` overlays the config
  `setup` key. Default bind `127.0.0.1` (was hard-coded); banner
  adds `HOST=`. Scenario files keep §14 galaxy knobs only. Docs:
  [CPLANETS.md](CPLANETS.md), [CODING.md](CODING.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md). CTest: `unit_serverConfig`,
  `functional_cli_config_defaults`, `functional_server_verbose`.

- CLI vs config defaults (preference): every user-facing flag except
  the config **path** (`--config`) is settable in the file; argv
  present on the command line overrides **silently**. Server:
  process keys in server config (see above). AI: `cycles`, `once`,
  `serve_loop`. Human: `once`, `pull`, `gui`, `test`. Banner adds
  `PLAYERS=` / `CYCLES=`. Docs: [CPLANETS.md](CPLANETS.md),
  [CODING.md](CODING.md), [KNOB-COVERAGE.md](KNOB-COVERAGE.md).
  CTest: `functional_cli_config_defaults` (extends unit setup/AI
  config parses).

- Align server + AI verbosity to a shared **0–10** scale (preference):
  `0` errors only, `10` full dumps / statistics. Out-of-range values
  **clamp** into `0..10` (not rejected). Existing message categories
  stay; provisional thresholds: server settings≈3 / combat≈6 /
  full≈10; AI decisions≈3 / full≈10. Intermediate bands reserved for
  growth (no new log spam yet). Docs: [CPLANETS.md](CPLANETS.md),
  [CODING.md](CODING.md), [KNOB-COVERAGE.md](KNOB-COVERAGE.md).
  CTest: `unit_serverVerbose`, `unit_aiVerbose`,
  `functional_server_verbose`, `functional_ai_verbose`.

- AI client verbosity logging (headless stdout): AI config key
  `verbosity` and CLI `--verbosity N`. CLI overlays the config key
  when provided. Docs: [CPLANETS.md](CPLANETS.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md), [CODING.md](CODING.md).
  CTest: `unit_aiVerbose`, `functional_ai_verbose`
  (extends `unit_aiConfig`).

- Ship create / design / yard list chrome: human **Ships** notebook
  tab starts timed design development (`PUT /design`), yard builds
  (`PUT /build`), and yard reclaim (`PUT /reclaim-hulls`); chrome
  trailer publishes design catalog + seat wealth/resources milli.
  Wired to existing `queueDesignDevelop` / `queueYardBuild` /
  `queueReclaim`. Docs: [CPLANETS.md](CPLANETS.md),
  [DIALOGS.md](DIALOGS.md). CTest: `fn_listChrome` extended,
  `functional_design_yard`.

- Server verbosity logging (headless stdout): setup key `verbosity`
  and CLI `--verbosity N`. Hooks `PUT /policy` and combat tick
  events. Docs: [CPLANETS.md](CPLANETS.md),
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md). CTest: `unit_serverVerbose`,
  `functional_server_verbose`.

- Docs: reframe [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) — A–C harness
  is plumbing, not balance-complete; next priority is playable chrome
  + full textfile knobs, then balance. New inventory
  [KNOB-COVERAGE.md](KNOB-COVERAGE.md); pointers in
  [CPLANETS.md](CPLANETS.md), [PLAN.md](PLAN.md), [CODING.md](CODING.md).
  Note: PR #34 (solo one-shot TCP) still open at write time.
- Fix human/AI clients for the server’s one-shot TCP contract:
  `ServerListen` closes after each reply, so `HumanSession` /
  `AiClient` now open a fresh `Networking.Socket` per verb. Before
  this, handshake then GET on one socket left the GUI/`--pull` at
  `tick=0` with empty lists (solo session looked frozen). CTest:
  `functional_client_pull`. Docs: [CPLANETS.md](CPLANETS.md).

- User-facing binaries (`cplanets-server`, `cplanets`, `cplanets-ai`,
  `cplanets-tick`) parse argv with stdlib `cli` (`--help` / `-h`
  via `helpText()`). Flag semantics unchanged. Docs:
  [CPLANETS.md](CPLANETS.md), [CODING.md](CODING.md).

- TUNING-PLAYABLE workstream C (session harness):
  `scripts/tuning-session` starts server + AI on a closed fixture
  with a fixed `--seed` for comparable re-runs; fixture packs
  `scenarios/tuning-{small,combat,trade}.setup`; AI aggression
  presets `config/ai-{soft,mid,hard}.cfg` (seat 1). Headless CTest
  `functional_session_harness` (setup + seed + AI join + `--pull`,
  no GTK). Docs: [CPLANETS.md](CPLANETS.md),
  [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md).

- TUNING-PLAYABLE workstream B (list chrome): human Pause
  CheckButton → `PUT /pause` (one-human gate); Fleets tab
  Dispatch/Recall Entries → `PUT /order` / `PUT /recall` with
  in-flight lock UX; explored dialog auto-present; design/build
  progress label from publish chrome trailer. CTest:
  `fn_listChrome`, `functional_list_chrome`. Docs:
  [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md),
  [CPLANETS.md](CPLANETS.md), [DIALOGS.md](DIALOGS.md).

- TUNING-PLAYABLE workstream A (knob surface): server `--setup PATH`
  / `--seed` load editable scenario fixtures; unknown keys fail loud
  on setup + AI config; restart-only retune contract in
  [CPLANETS.md](CPLANETS.md) / [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md);
  grouped comments on `scenarios/closed-default.setup` and
  `config/ai-default.cfg`. CTest: `functional_setup_path`, stricter
  `unit_setupLoad` / `unit_aiConfig`.

- Docs: product dialog / chrome inventory in [DIALOGS.md](DIALOGS.md)
  (panels vs true dialogs; Phase G vs intended playable vs deferred).
  Companion to GTK infra gaps (`GTK-FEATURE-GAPS.md` / PR #27), not a
  widget-binding list. Linked from CPLANETS.md and README.

- CPL-35: move stand-alone `unit_*` / `fn_*` programs from `src/` to
  `tests/unit/` and `tests/fn/`. They build only with the CMake `test`
  target / `ctest` (`cplanets_add_test_program`, `EXCLUDE`-from-`all`,
  `cwhip -p src` for production includes), not with default `build`.

- Phase G (CPL-33): human GTK list debugger — `src/client/` windows
  for planet list, fleet list, newspaper/digest, policy editors;
  explored-planet dialog (livability/quality 1–10; may change when
  populated/productive); TCP only (never ticks / never opens DB);
  visibility is a view of server publish flags; no DrawingArea /
  map canvas. Settings: `config/human-default.cfg`. Modes:
  `--once`, `--pull`, `--gui`, `--test`. Unit: `unit_clientConfig`,
  `unit_clientLivability`, `unit_clientPolicy`,
  `unit_clientPublishDecode`. Function: `fn_client`. Python:
  `functional_client_once`.

- Phase H (CPL-32): AI client — own `config/ai-default.cfg` (not
  human settings); axes aggression / role stickiness / expansion /
  escort / agreement appetite / tech vs hulls / reaction lag
  (ticks + wall) / surprise rate; seeded legal-only surprise; same
  visibility view; tick period may auto-config from AI lag (still
  setup-tunable). Unit: `unit_aiConfig`, `unit_aiTickSuggest`,
  `unit_aiReaction`. Function: `fn_ai` (policy shape + surprise
  band). TCP same-protocol loop optional via `--serve-loop`.

- Phase F (CPL-31): server driver — real-time cadence (setup seconds
  1–30), snapshot policies → tick → persist → publish state+digest,
  no ready barrier, AFK=last policy, handshake AFK≠drop, pause only
  with one human, injectable clock / admin advance N, setup lock on
  first tick, stand-alone no save/rejoin, all-humans-quit ends game,
  SQLite-shaped live snapshot, TCP accept (one writer). Unit:
  `unit_serverClock`, `unit_serverPresence`, `unit_serverPolicy`.
  Function: `fn_server`. Python: `functional_server_smoke`. Gaps:
  no select/poll multiplex; one envelope per recv (localhost OK).

- Phase E (CPL-30): messages library — envelope v1 (version, verb,
  path, length, body), RLE body compress/decompress with store
  fallback, verbs GET `/state`, PUT `/policy`, GET `/events` and
  `/digest`. Reject unknown envelope version. No listen socket; no
  all-players-ready / POST turn barrier. Unit: `unit_compress`,
  `unit_envelope`, `unit_verbs`. Function: `fn_messages`.

- Phase D5 (CPL-29): contact couples partitions and fills known
  competitors; closed eliminate-all end; all-humans-quit ends the
  live game; zombies (dropped last-policy seats) fall to normal
  play; empire pool only; setup lock in progress; stranded moves
  after N covered in the fn suite. Unit: `unit_contact`,
  `unit_endgame`. Function: `fn_contactEnd`.

- Phase D4 (CPL-28): shared multi-tick combat (duration from
  comparative strength; recall into/out of fight under battle
  rules); mid-dispatch fleet lock; design develop + yard
  produce/reclaim take time; screened heavies; capture-use vs
  destroy; attributed attack ends agreement + confiscation.
  Unit: `unit_screen`. Function: `fn_combatDesigns`.

- Phase D3 (CPL-27): midpoint ambush only after half hop ETA; pirate
  loot credits on return to sender; two-pirate war (passers live);
  forced recall after robbery; pirate idle timeout; identify
  asymmetry (attacker advantage + defender fair chance; separate
  setup knobs; scales with attributes; victim-only default
  audience). Unit: `unit_identify`, `unit_ambushHalf`. Function:
  `fn_pirateIdentify`.

- Phase D2 (CPL-26): player–player trade agreements + `S`; cargo full
  both ways with escorts cycling; sender-only loading; self-trade
  cost-only; `S=100` needs 10×10 holds; closed agreement / role-off-
  trader breaks exchange; same-tick recall still cancels. Unit:
  `unit_agreement`, `unit_tradeHold`. Function: `fn_tradeAgreements`.

- Phase D1 (CPL-25): take / occupy / colony / defenses. Unowned and
  undefended owned non-productive takes are free; productive owned
  always fights inherent defense; satellites and parked hulls defend;
  colony required to populate (dead colony does not); war fleets stay;
  sit/move on possession. Shared `Combat` entry points with a minimal
  multi-tick engagement stub (full D4 screening later). Unit:
  `unit_combat`. Function: `fn_takeColony`.

- Phase C (CPL-24): pure tick dispatcher (RULES §7) with production,
  dispatch/loading, same-tick cancel + in-flight recall, sit/move
  arrivals, range/ETA including tech teleport (ETA→0), stranded-N,
  and non-instant yard builds. No scheduler, trade, pirate, or take
  combat. Unit programs: `unit_travel`, `unit_production`,
  `unit_dispatch`, `unit_recallCancel`, `unit_stranded`. Function
  program: `fn_tickCore`. Fixed seeds throughout.

- Phase B (CPL-23): scenario setup snapshot with every RULES §14 knob
  named (closed default fixture), seeded lib RNG, galaxy start
  (home yard, scout-range rocks, unknown quality, world count/mix),
  empire pools, and application-text setup loader
  (`scenarios/closed-default.setup`). Unit programs: `unit_rng`,
  `unit_scenarioFixture`, `unit_setupLoad`, `unit_galaxyStart`,
  `unit_empirePools`. No network and no tick rules yet.

- Phase A polish (CPL-21): drop leftover hello sources (`src/main.cw`,
  `tests/check-greeting.cmake`); give every `.cw` stub a CODING file
  header, changelog, and full method comments on `Machine.identity`.
  Four CMake programs + `unit_libIdentity` remain the scaffold. Fix
  `test_template_rename` so it accepts nested `tests/unit/*.cmake`
  paths from the Phase A layout.
- Revisit `doc/PLAN.md` for viability against locked RULES on main:
  fold pause / zombies / identify / livability / AI-lag tick /
  multi-tick combat / tech teleport into existing phases; close
  simultaneous-turn language; extend the fn/server checklist; sync
  estimates and CODING file-size notes. No game code.
- Replace the hello-world starter with four stub executables
  (`cplanets-server`, `cplanets`, `cplanets-ai`, `cplanets-tick`), a
  shared `src/lib` identity, and a CTest unit program that links it.
- Add `doc/PLAN.md`: end-to-end build order, short-file layout, unit /
  function / functional tests, and line-count estimates for v1
  (library, server, list client, AI) plus later canvas and HTTP.

- Add `doc/RULES.md`: working spec for the state machine, fleet orders,
  trade, pirates, taking planets, driver/client split, and
  implementation order. Point the README at it as the document that
  wins on disagreement.
- Extend `doc/RULES.md` with hull dispatch cost, trade wealth+resource
  cargo and wealth-only return profit, pirate 100% cargo loot and
  forced return after a win, colony-before-production, defender attack
  bump / productivity loss / tech bump, and a locked admin setup file.
- Combat is per class: colony hulls are weakly defended and populate
  a taken world only if they survive; frigates tend to die but screen
  destroyers.
- Dispatch wealth is by hull **weight** (scouts almost free, colonies
  dearer), not by hull count.
- Attributed attack on a trade partner ends the agreement and
  confiscates inbound ships and cargo; pirate ambush is unattributed
  and does not.
- Setup-file chance that a pirate victim learns who it was; any fleet
  may recall before arrival; custom designs with development (mostly
  wealth) vs production (mostly resources).
- Hull reclaim only at a shipyard planet; resource return percent is
  a setup item (development wealth is not refunded).
- Resolve spec conflicts: recall always to sender (same-tick =
  cancel); reclaim is a later shipyard trip; trade holds full both
  ways with escorts cycling; sender-only loading cost; war fleets
  stay, unowned takes are free, parked ships/defenses fight; range
  and speed drive ETA and cost; ambush at midpoint; pirate loot
  credited on return; capture-use chance (else destroyed); home
  yard and unknown rocks.
- Empire pool (no per-planet logistics); stranded fleets move after
  setup N ticks; two pirates at a midpoint war, passers unharmed;
  closed game ends at one player; ongoing map is fully created, own
  all worlds, sandbox until contact; newspaper + known-competitor
  messages; pirate role stuck while ambush fleets wait.
- Roles are empire-wide allocation coefficients (the Neutral /
  Conqueror / Pirate / Trader / Hermit matrix), not per-partner.
- Server and clients are separate executables; TCP REST-shaped
  frames (compressed binary on LAN), not an HTTP server; AI is a
  stand-alone client with its own config. HTTP REST is a later
  façade on the same commands.
- Add `scripts/setup --clean` in either argument order to remove generated
  directories before configuration. Move `build` and `rebuild` into
  `.project_env` as shell functions and retain the standalone `clean` script.
  Document the setup-based workflow and cover cleanup and build commands.
- Showcase current callable types, parenthesized returns, and multiline
  dictionary literals in the greeting starter while preserving its output.
  Document the current syntax and correct the native-width alias guidance.
- Add a CTest greeting smoke test and exercise it in the real-SDK integration
  suite alongside the built and installed executable checks.
- Require Cwhip SDK 0.0.2 and its `numeric-v2` ABI; reject missing or
  incompatible SDK markers before applying application defaults. Update mock
  SDKs, add version/ABI rejection coverage and an opt-in real-SDK private
  build/install check, and document source and native-package migration.
- Inherit application install-prefix and build-type defaults registered by the
  Cwhip SDK, while preserving explicit CMake settings and existing cache
  values. Setup's optional build-type argument is now an explicit override.
- Separate SDK selection into `cwhip/sdk.toml` so editor/debugger preference
  rewrites cannot erase it. Read legacy `settings.toml` only when the dedicated
  file is absent, consistently in CMake and setup. Keep environment overrides,
  strict validation, and explicit-prefix-only package discovery.
- Retain compatibility with the whole installed SDK prefix from the top-level `sdk_prefix`
  string in `$XDG_CONFIG_HOME/cwhip/settings.toml` (or
  `$HOME/.config/cwhip/settings.toml` when `XDG_CONFIG_HOME` is unset/empty)
  in both CMake and setup when `sdk.toml` is absent.
  Preserve precedence: non-empty `CWHIP_SDK` > SDK config (or legacy settings) > normal CMake
  discovery. Parse TOML with Python 3.11+ without evaluating or modifying
  user settings, and reject invalid selections without falling back.
- Export a settings-selected SDK to the setup shell and add regression
  coverage for discovery precedence, TOML paths, errors, and shell handoff.
- Add the standard MIT license.
- Add a CWhip hello-world starter with a project setup script and interactive
  development shell.
- Configure CMake to discover an installed CWhip 0.0.1 SDK, support explicit
  SDK selection, and place application/native outputs in configurable
  project directories.
- Document SDK selection, building, output customization, and project-shell
  commands.

The starter requires a CWhip SDK that provides configurable application
output directories and `cwhip_apply_application_defaults()`. SDKs without
these capabilities are rejected during configuration.
