# Changelog

## Unreleased

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
