# Knob coverage inventory

**Purpose:** track which game variables that touch planets, ships,
fleets/designs, players, combat, travel, production, identify, and
clock are **externalized** (text file at minimum) vs still hardcoded
in sim. Magnitudes stay placeholders — this doc does **not** invent
balance values.

**Authorities:** [RULES.md](RULES.md) §14 (knobs outside code),
[TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) (phase order), this file
(inventory). Operator paths: unified `config/server-*.cfg` (process
+ §14), `config/ai-*.cfg`, `config/human-default.cfg`. Key catalogs:
[SERVER-CONFIG.md](SERVER-CONFIG.md),
[AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md),
[HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md).
`scenarios/*.setup` are reference fragments only. Prefer
`./scripts/setup` for builds.

**Context twin:** Project store `docs/knob-coverage.md`.

**Tag legend**

| Tag | Meaning |
| --- | --- |
| **textfile already** | Named in setup/AI cfg, parsed, and used by sim (or AI) |
| **needs textfile** | Hardcoded magnitude / template / server constant that should become a setup (or AI) key |
| **GUI candidate** | Human-facing dial worth a client control later (Entry/Scale); still must have textfile first |
| **server-textfile-only** | Operator/server setting — stay in scenario/server text; not a play-session GUI |

**Status note:** [#34](https://github.com/cwhip-lang/cplanets/pull/34)
(solo one-shot TCP / empty GUI) was **open** when this inventory was
written — include it when merged; not required for this docs PR.

---

## Next-phase order (no magnitudes)

1. **First-move ship create / design / yard chrome** — **done**
   (Ships tab list stand-ins; see [DIALOGS.md](DIALOGS.md) §6 /
   [CPLANETS.md](CPLANETS.md)). Remaining chrome gaps are map /
   Scale / richer design fields.
2. **Externalize remaining knobs to text** — **done** for the
   playable-first gap set below (production/build/design costs,
   galaxy spawn fractions, design templates, attack_bump /
   AFK wire-up, handshake miss / accept poll). Fail loud on
   unknown keys (already). Large GUI chrome is a separate task.
3. **Selective GUI setters** — human client for policy / planet
   budget / design-build chrome; **most server settings stay
   textfile** (RULES §14 deferred setup GUI).
4. **Then balance tuning** — edit files, restart, compare harness
   loops. “Tuning” here means balancing for interesting play, **not**
   plumbing A–C.

---

## 1. Clock / session (server)

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `scenario_mode` | `scenarios/*.setup` | textfile already · server-textfile-only |
| `tick_period_seconds` (clamp 1–30) | setup + `Scenario.clampTickPeriod` | textfile already · server-textfile-only · GUI candidate (future admin) |
| `tick_auto_config_from_ai_lag` | setup | textfile already · server-textfile-only |
| `ai_reaction_lag_ticks` / `_seconds` (scenario side) | setup | textfile already · server-textfile-only |
| `afk_timeout_seconds` / `afk_shrink_factor` | setup → `GameDriver.applyAfkProductionScales` (connected idle seats scale production) | textfile already · server-textfile-only |
| `handshake_miss_ms` | `config/server-*.cfg` → `GameDriver` / `PresenceBook` | textfile already · server-textfile-only |
| `accept_poll_ms` | `config/server-*.cfg` → `ServerListen` | textfile already · server-textfile-only |
| `verbosity` (0–10 clamped; provisional: 0 errors / 3 settings / 6 combat / 10 full) | `config/server-*.cfg` + CLI `--verbosity` overlay | textfile already · server-textfile-only |
| `setup` / `host` (`address` alias) / `serve` / `port` / `players` / `seed` / `cycles` / `injectable` | `config/server-*.cfg` + CLI overlay (path `--config` excluded) | textfile already · server-textfile-only |

---

## 2. Galaxy / planets

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `world_count`, `useful_mix`, `scout_range`, `galaxy_radius` | setup | textfile already · server-textfile-only |
| Livability display map (`livability_*`) | setup | textfile already · server-textfile-only |
| `home_spawn_min_radius_fraction` / `_max_` / `_min_radius_floor` | setup → `galaxy.cw` | textfile already · server-textfile-only |
| `useful_livability_fraction` / `poor_livability_fraction` / `poor_resources_fraction` | setup → `galaxy.cw` | textfile already · server-textfile-only |
| `home_fallback_livability` / `home_fallback_resources` | setup → sandbox home claim | textfile already · server-textfile-only |
| `contact_reach` | setup → sandbox neighborhood stamp | textfile already · server-textfile-only |
| Per-planet budget / allocation set | open (RULES); policy % only | needs textfile (when locked) · GUI candidate |

---

## 3. Players / start pools

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `start_wealth` / `start_resources` / `start_tech` / `start_power` / `start_experience` | setup | textfile already · server-textfile-only |
| Standing policy % (expansion, escort, tech bias, `S`) | human client Entries → wire | GUI candidate (Scale later) · textfile N/A (runtime) |
| Human dial (`player_id`, host, port) + modes (`once` / `pull` / `gui` / `test`) + `refresh_ms` (GUI state/digest poll; default 1000; `0`=off; distinct from presence keep-alive) | `config/human-default.cfg` + CLI overlay (path `--config` excluded; `--refresh-ms`) | textfile already · GUI candidate (connect dialog later) |

---

## 4. Ships / fleets / designs

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `design_develop_ticks`, `yard_build_ticks` | setup | textfile already · GUI candidate (show durations) |
| `design_speed_cost_coeff`, `design_range_cost_coeff` | setup (used in develop cost) | textfile already · server-textfile-only |
| `yard_build_cost_per_size` | setup → yard build / reclaim basis | textfile already · server-textfile-only |
| `design_develop_cost_per_size` | setup → design develop wealth cost | textfile already · server-textfile-only |
| `design_scout_*` / `design_colony_*` / `design_freighter_*` / `design_escort_*` / `design_frigate_*` / `design_destroyer_*` | setup → `seedDefaultDesigns` / `make*` args | textfile already · GUI candidate (design editor) |
| `colony_hop_fraction` | setup → colony hop = scoutRange × fraction | textfile already · server-textfile-only |
| `dispatch_weight_scout` / `_colony`, `voyage_cost`, `reclaim_percent` | setup | textfile already · server-textfile-only |
| Ship create / design editor / yard queue chrome | **Exists** Ships tab Entries → `/design` `/build` `/reclaim-hulls` | GUI candidate (Scale / weapons later) |

---

## 5. Travel / combat / identify / production

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| Tech range / teleport threshold + enable | setup | textfile already · server-textfile-only |
| ETA = distance/speed (floor 1; speed≤0 → 1.0) | `travel.cw` shape | textfile already (via design + tech) · needs textfile only if shape coeffs appear |
| Pirate attrition / leftover / idle; stranded N; productive defense | setup | textfile already · server-textfile-only |
| Battle duration / short-circuit gap | setup | textfile already · server-textfile-only |
| Identify attacker/defender base + per-attr | setup | textfile already · server-textfile-only |
| `trade_bump` | setup + `tradeArrive.cw` | textfile already · server-textfile-only |
| `attack_bump` | setup → defender-win wealth/resources credit (`take.cw`) | textfile already · server-textfile-only |
| `capture_use_chance`, `cover_factor` | setup (`cover_factor` used in production) | textfile already · server-textfile-only |
| `production_tick_rate` | setup → productive wealth/resource gains | textfile already · server-textfile-only |

---

## 6. AI client (`config/ai-*.cfg`)

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| Axes: aggression, role_stickiness, expansion, escort, agreement_appetite, tech_vs_hulls | AI cfg | textfile already · server-textfile-only (AI process) |
| `reaction_lag_ticks` / `_seconds`, `surprise_rate` | AI cfg | textfile already · server-textfile-only |
| `loop_period_ms` (serve-loop frame budget; default 100; distinct from reaction lag) | AI cfg + CLI `--loop-period-ms` overlay | textfile already · server-textfile-only (AI process) |
| `seed`, `player_id`, host, port | AI cfg | textfile already · server-textfile-only |
| `verbosity` (0–10 clamped; provisional: 0 errors / 3+ decisions / 10 full) | AI cfg + CLI `--verbosity` overlay | textfile already · server-textfile-only (AI process) |
| `cycles` / `once` / `serve_loop` | AI cfg + CLI overlay (path `--config` excluded) | textfile already · server-textfile-only (AI process) |
| Soft/mid/hard presets | `config/ai-{soft,mid,hard}.cfg` | textfile already |

Human difficulty GUI is **not** required; AI stays file-driven.

---

## 7. Top gaps (summary)

1. **Playable chrome:** ship create / design / yard — **shipped** (Ships tab); Scale / weapons / richer map chrome later (e.g. CPL-63).
2. **Named-but-unwired / hardcoded sim rates** — **shipped** (`attack_bump`, AFK timeout/shrink, production rate, build/design cost bases, galaxy spawn fractions, design `make*` templates, colony hop fraction, handshake miss / accept poll).
3. **Per-planet budget / allocation** — still open until RULES lock.
4. **Balance passes:** after playable + textfile coverage; harness A–C is plumbing for those passes, not balance-complete.

---

## Cross-links

| Doc | Role |
| --- | --- |
| [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) | Phase order; A–C = plumbing |
| [CPLANETS.md](CPLANETS.md) | Operator run / restart contract |
| [RULES.md](RULES.md) §14 | Knobs outside code |
| [DIALOGS.md](DIALOGS.md) | Missing playable chrome |
| [SERVER-CONFIG.md](SERVER-CONFIG.md) | Unified server + §14 key catalog |
| [AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md) | AI key catalog |
| [HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md) | Human key catalog |
| `config/server-default.cfg` | Unified server + §14 sample |
| `config/ai-default.cfg` | AI axes surface |
| `scenarios/*.setup` | Reference §14 fragments only |
