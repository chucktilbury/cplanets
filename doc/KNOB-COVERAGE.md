# Knob coverage inventory

**Purpose:** track which game variables that touch planets, ships,
fleets/designs, players, combat, travel, production, identify, and
clock are **externalized** (text file at minimum) vs still hardcoded
in sim. Magnitudes stay placeholders — this doc does **not** invent
balance values.

**Authorities:** [RULES.md](RULES.md) §14 (knobs outside code),
[TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) (phase order), this file
(inventory). Operator paths: `scenarios/*.setup`, `config/ai-*.cfg`,
`config/human-default.cfg`. Prefer `./scripts/setup` for builds.

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

1. **Finish missing first-move playable chrome** — especially ship
   create / design / yard queue (list chrome still dispatch-only on
   seeded fleets; progress labels exist, editors do not). See
   [DIALOGS.md](DIALOGS.md) §6 / [CPLANETS.md](CPLANETS.md).
2. **Externalize remaining knobs to text** — every planet / ship /
   player / combat / travel / production / identify / clock
   coefficient that still lives as a magic number → scenario (or AI)
   key; wire named-but-unused keys; fail loud on unknown keys
   (already).
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
| `afk_timeout_seconds` / `afk_shrink_factor` | **named in setup**, not applied by server presence | needs textfile (wire) · server-textfile-only |
| Handshake miss window | **hardcoded** `5000u` ms in `cplanets-server` → `GameDriver` | needs textfile · server-textfile-only |
| Accept/poll timeout | **hardcoded** `50` ms listen loop | needs textfile (optional) · server-textfile-only |
| `verbosity` (0 quiet / 1 settings / 2+ combat stdout) | setup + CLI `--verbosity` overlay | textfile already · server-textfile-only |
| `--players` / `--seed` / `--port` | CLI | textfile already (seed also in AI cfg) · server-textfile-only |

---

## 2. Galaxy / planets

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `world_count`, `useful_mix`, `scout_range`, `galaxy_radius` | setup | textfile already · server-textfile-only |
| Livability display map (`livability_*`) | setup | textfile already · server-textfile-only |
| Home spawn min/max radius fractions (`0.25` / `0.95` / `0.5`) | `galaxy.cw` literals | needs textfile · server-textfile-only |
| Useful/poor livability fractions (`0.6` / `0.2` span) + poor `resources * 0.5` | `galaxy.cw` | needs textfile · server-textfile-only |
| Home fallback livability/resources `50.0` | `galaxy.cw` | needs textfile · server-textfile-only |
| Contact reach fallback `4.0` | `galaxy.cw` | needs textfile · server-textfile-only |
| Per-planet budget / allocation set | open (RULES); policy % only | needs textfile (when locked) · GUI candidate |

---

## 3. Players / start pools

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `start_wealth` / `start_resources` / `start_tech` / `start_power` / `start_experience` | setup | textfile already · server-textfile-only |
| Standing policy % (expansion, escort, tech bias, `S`) | human client Entries → wire | GUI candidate (Scale later) · textfile N/A (runtime) |
| Human dial (`player_id`, host, port) | `config/human-default.cfg` | textfile already · GUI candidate (connect dialog later) |

---

## 4. Ships / fleets / designs

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| `design_develop_ticks`, `yard_build_ticks` | setup | textfile already · GUI candidate (show durations) |
| `design_speed_cost_coeff`, `design_range_cost_coeff` | setup (used in develop cost) | textfile already · server-textfile-only |
| Yard build cost basis `design.size * 10.0` | `state.cw` literal | needs textfile · server-textfile-only |
| Design develop cost basis `design.size * 50.0` | `state.cw` literal | needs textfile · server-textfile-only |
| Default scout/colony/freighter/… template speeds, sizes, holds | `design.cw` `make*` | needs textfile (fixture templates) · GUI candidate (design editor) |
| Colony hop = `scoutRange * 0.5` | `state.cw` | needs textfile · server-textfile-only |
| `dispatch_weight_scout` / `_colony`, `voyage_cost`, `reclaim_percent` | setup | textfile already · server-textfile-only |
| Ship create / design editor / yard queue chrome | **missing** list UI (PR #34 notes) | GUI candidate (playable first) |

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
| `attack_bump` | **named in setup**, **unused** in combat code | needs textfile (wire) · server-textfile-only |
| `capture_use_chance`, `cover_factor` | setup (`cover_factor` used in production) | textfile already · server-textfile-only |
| Production tick rate `* 0.01` on livability/resources | `production.cw` literal | needs textfile · server-textfile-only |

---

## 6. AI client (`config/ai-*.cfg`)

| Knob / behavior | Where today | Tag |
| --- | --- | --- |
| Axes: aggression, role_stickiness, expansion, escort, agreement_appetite, tech_vs_hulls | AI cfg | textfile already · server-textfile-only (AI process) |
| `reaction_lag_ticks` / `_seconds`, `surprise_rate` | AI cfg | textfile already · server-textfile-only |
| `seed`, `player_id`, host, port | AI cfg | textfile already · server-textfile-only |
| Soft/mid/hard presets | `config/ai-{soft,mid,hard}.cfg` | textfile already |

Human difficulty GUI is **not** required; AI stays file-driven.

---

## 7. Top gaps (summary)

1. **Playable chrome:** ship create / design editor / yard queue (first-move).
2. **Named but unwired:** `attack_bump`, `afk_timeout_seconds`, `afk_shrink_factor`.
3. **Hardcoded sim rates/costs:** production `0.01`, build `*10`, design `*50`, galaxy spawn fractions, design `make*` templates, colony hop fraction.
4. **Server constants:** handshake miss `5000` ms (and optional accept poll) → scenario/server text.
5. **Balance passes:** only after (1)–(3) above; harness A–C is plumbing for those passes, not balance-complete.

---

## Cross-links

| Doc | Role |
| --- | --- |
| [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md) | Phase order; A–C = plumbing |
| [CPLANETS.md](CPLANETS.md) | Operator run / restart contract |
| [RULES.md](RULES.md) §14 | Knobs outside code |
| [DIALOGS.md](DIALOGS.md) | Missing playable chrome |
| `scenarios/closed-default.setup` | §14 key surface |
| `config/ai-default.cfg` | AI axes surface |
