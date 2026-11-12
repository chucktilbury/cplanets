# Server config reference

Unified operator file for `cplanets-server`: process/network knobs
**and** former scenario (§14) magnitudes live in one `--config`
document. Sample: [`config/server-default.cfg`](../config/server-default.cfg).
Tuning packs: `config/server-tuning-{small,combat,trade}.cfg`.

Syntax: `key = value` lines. Blank lines and `#` comments are
skipped. **Unknown keys fail loud** (process exits 1).

`--config PATH` is optional. When omitted, the server ensures and
loads `~/.config/cplanets/server.cfg` (creating the XDG pack —
`server.cfg`, `human.cfg`, `ai-{soft,mid,hard}.cfg` — when missing).
The generated `server.cfg` lists **every** process/network and §14
key the server understands, with closed defaults (same magnitudes as
[`config/server-default.cfg`](../config/server-default.cfg), plus three
sample `ai-client` lines). An incomplete *generated* stub (XDG header
present, CPL-116 keys missing — typical after an older first-run
write) is **rewritten** on the next omit-config start; remove the
`Created under ~/.config/cplanets/` header line to keep a hand-edited
file. Human/AI level files are never overwritten. An **explicit**
`--config` path that cannot open is still a **hard error** (exit 1).
`--config` itself has no in-file key. There is **no GUI server-config
dialog** yet — edit the file.

Listen bind uses `FD_CLOEXEC` so server-spawned AI children do not
inherit the listen socket (otherwise orphans can hold `host:port`
after the parent exits and the next start fails with
`cplanets-server: bind failed host:port`).

CLI flags present on argv override file values **silently**.
§14 galaxy keys have no argv overlays (edit the file and restart).

## Migration (old `setup=` / `--setup`)

| Old | New |
| --- | --- |
| `setup = scenarios/….setup` in server cfg | **Rejected.** Copy §14 keys into the server config (or start from `config/server-*.cfg`). |
| CLI `--setup PATH` | **Removed.** Use one unified `--config`. |
| Empty `setup=` → `SETUP=builtin` / `Scenario()` | Hand-edited files may still omit §14 keys (ctor defaults fill in); the **auto-generated** XDG `server.cfg` and `config/server-default.cfg` list the full key set. |
| Banner `SETUP=path\|builtin` | Banner `CONFIG=<path>` + `SCENARIO_MODE=<mode>`. |

`scenarios/*.setup` files remain as **reference fragments** for
copy/paste and in-process `SetupParse` / unit tests. They are not
loaded by path for live serve.

See also: [CPLANETS.md](CPLANETS.md), [KNOB-COVERAGE.md](KNOB-COVERAGE.md),
[RULES.md](RULES.md) §14.

---

## Process / network keys

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `host` (alias `address`) | string | `127.0.0.1` | loopback or `0.0.0.0` | TCP listen bind. Empty clamps to `127.0.0.1`. |
| `port` | int | `0` (ctor) / `7700` (sample) | `0`…`65535` | Listen port; `0` = ephemeral OS port (CI). CLI `--port`. |
| `players` | int | `0` | `0`…`seat_hard_cap` | Soft max seats (`0` = unlimited within hard cap). Grow on connect; go does not wait. CLI `--players`. |
| `seed` | int | `7` | `≥ 0` | PRNG seed for galaxy layout. CLI `--seed`. |
| `serve` | bool | `false` (ctor) / `true` (sample) | `true`/`false`/`1`/`0` | Bind TCP + cadence when true; else smoke identity. CLI `--serve`. |
| `cycles` | int | `0` | `≥ 0` | Cap accept/serve iterations; `0` = until stop. CLI `--cycles`. |
| `injectable` | bool | `false` | bool | Test clock / admin advance. CLI `--injectable`. |
| `verbosity` | int | `0` (ctor) / `10` (sample) | `0`–`10` (clamped) | Stdout log ladder. Copied onto live `Scenario.verbosity`. CLI `--verbosity`. |
| `handshake_miss_ms` | int | `5000` | `≥ 1` (practical: 1000–60000) | Drop seat after this many ms without handshake keep-alive. CLI `--handshake-miss-ms`. |
| `accept_poll_ms` | int | `50` | `≥ 1` (practical: 10–200) | Accept/recv timeout = cadence poll grain. CLI `--accept-poll-ms`. |
| `recv_buffer_bytes` | int | `65536` | `≥ 1024` (practical: 8KiB–1MiB) | Max bytes per accepted client recv. |
| `seat_hard_cap` | int | `256` | `≥ 1` (practical: 8–1024) | Absolute seat bound when soft max is `0`. |
| `verbose_capture_lines` | int | `64` | `≥ 1` (practical: 16–1024) | `ServerVerboseLog` ring size. |
| `ai-client` | string pair | *(none)* | repeatable | Explicit AI seat: `ai-client = "FriendlyName", level`. Friendly name is the in-game `display_name` (contact/chrome). Level is optional (default **soft**) and selects `ai-<level>.cfg` beside the server config, then under `~/.config/cplanets/`, then `config/`. Example: `ai-client = "Alex", soft`. Omit all lines to spawn none. |
| `spawn_ai_dir` | string | `""` | writable directory | Where generated per-AI configs are written. Empty → system temp (`…/cplanets-ai-spawn`). |
| `spawn_ai_bin` | string | `""` | path to `cplanets-ai` | AI executable. Empty → sibling of `cplanets-server` argv[0]. |

Spawned children dial the live listen `host`/`port` (loopback when bind is `0.0.0.0`). Banner lines: `SPAWN_AI=… name=… level=…`, `SPAWN_AI_COUNT=N`. Children are cancelled when the server listen loop ends.

**Rejected legacy keys:**
- `setup` → `setup path removed; fold §14 keys into this server config…`
- `spawn_ai_count` / `spawn_ai_template` → use `ai-client = "name", level` instead.

---

## §14 scenario keys (folded in)

Omitted keys keep `Scenario()` closed defaults. Magnitudes are
placeholders until RULES locks them. Tick period clamps to **1–30**.

### Clock / AFK

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `scenario_mode` | string | `closed` | `closed` (v1) | Win model; closed = eliminate all others. |
| `tick_period_seconds` | int | `5` | `1`–`30` (clamped) | Wall tick period (seconds). |
| `tick_auto_config_from_ai_lag` | bool | `true` | bool | When true, rewrite tick period from AI lag. |
| `ai_reaction_lag_ticks` | int | `1` | `≥ 1` | Scenario-side AI lag (ticks). |
| `ai_reaction_lag_seconds` | fp | `5.0` | `≥ 0` | Scenario-side AI lag (wall seconds). |
| `afk_timeout_seconds` | fp | `120.0` | `≥ 0` (practical: 30–600) | Idle before AFK production shrink. |
| `afk_shrink_factor` | fp | `1.0` | `0`–`1` | Production scale while AFK. |

### Galaxy layout

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `world_count` | int | `24` | `≥ 2` (practical: 8–64) | Planet count. |
| `useful_mix` | fp | `0.35` | `0`–`1` | Fraction of useful rocks. |
| `scout_range` | fp | `3.0` | `> 0` | Default scout hop / template reach. |
| `galaxy_radius` | fp | `20.0` | `> 0` | Galaxy disk radius. |

### Identify

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `identify_attacker_base` | fp | `0.35` | `0`–`1` | Base attacker-ID chance. |
| `identify_attacker_per_attr` | fp | `0.05` | `≥ 0` | Attacker-ID per attribute. |
| `identify_defender_base` | fp | `0.20` | `0`–`1` | Base defender-ID chance. |
| `identify_defender_per_attr` | fp | `0.04` | `≥ 0` | Defender-ID per attribute. |

### Tech / teleport

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `tech_range_base` | fp | `3.0` | `≥ 0` | Detection range at tech 0. |
| `tech_range_per_tech` | fp | `0.5` | `≥ 0` | Detection range per tech. |
| `tech_teleport_threshold` | fp | `10.0` | `≥ 0` | Tech for ETA-zero teleport. |
| `tech_teleport_enabled` | bool | `true` | bool | Master teleport switch. |

### Design / yard timing & cost coeffs

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `design_develop_ticks` | int | `5` | `≥ 1` | Ticks to finish a design. |
| `yard_build_ticks` | int | `3` | `≥ 1` | Ticks to finish a yard build. |
| `design_speed_cost_coeff` | fp | `1.0` | `≥ 0` | Wealth cost scale vs speed. |
| `design_range_cost_coeff` | fp | `1.0` | `≥ 0` | Wealth cost scale vs range. |

### Combat / travel / economy

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `reclaim_percent` | fp | `0.50` | `0`–`1` | Resources returned on reclaim. |
| `capture_use_chance` | fp | `0.25` | `0`–`1` | Chance captured hull is usable. |
| `cover_factor` | fp | `1.0` | `≥ 0` | Production cover multiplier. |
| `voyage_cost` | fp | `0.0` | `≥ 0` | Optional voyage wealth burn. |
| `pirate_idle_ticks` | int | `10` | `≥ 0` | Pirate idle before next act. |
| `stranded_ticks_n` | int | `5` | `≥ 0` | Stranded cooldown ticks. |
| `trade_bump` | fp | `1.20` | `≥ 1` | Trade profit multiplier. |
| `attack_bump` | fp | `1.0` | `≥ 0` | Attack strength scale. |
| `dispatch_weight_scout` | fp | `0.1` | `≥ 0` | Dispatch cost weight (scout). |
| `dispatch_weight_colony` | fp | `5.0` | `≥ 0` | Dispatch cost weight (colony). |
| `pirate_attrition` | fp | `0.30` | `0`–`1` | Pirate strength loss after robbery. |
| `pirate_leftover` | fp | `0.05` | `0`–`1` | Pirate leftover after fight. |
| `battle_strength_duration_coeff` | fp | `1.0` | `≥ 0` | Battle duration vs strength. |
| `battle_short_circuit_gap` | fp | `3.0` | `≥ 0` | Instant-resolve strength gap. |
| `productive_inherent_defense` | fp | `1.0` | `≥ 0` | Inherent defense on productive rocks. |

### Production / costs

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `production_tick_rate` | fp | `0.01` | `> 0` (practical: 0.001–0.1) | Base production rate per tick. |
| `yard_build_cost_per_size` | fp | `10.0` | `≥ 0` | Resources per hull size to build. |
| `yard_build_extra_hull_time_frac` | fp | `0.10` | `≥ 0` | Extra fraction of `yard_build_ticks` charged per hull beyond the first in one `PUT /build` qty (CPL-111). qty 2 → 110% of one-hull ticks (rounded up). |
| `design_develop_cost_per_size` | fp | `50.0` | `≥ 0` | Wealth per size to develop. |
| `colony_hop_fraction` | fp | `0.5` | `0`–`1` | Colony hop reach vs scout. |

### Spawn / livability mix

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `home_spawn_min_radius_fraction` | fp | `0.25` | `0`–`1` | Min home radius / galaxy. |
| `home_spawn_max_radius_fraction` | fp | `0.95` | `0`–`1` | Max home radius / galaxy. |
| `home_spawn_min_radius_floor` | fp | `0.5` | `≥ 0` | Absolute min home radius. |
| `useful_livability_fraction` | fp | `0.6` | `0`–`1` | Useful-rock livability mix. |
| `poor_livability_fraction` | fp | `0.2` | `0`–`1` | Poor-rock livability mix. |
| `poor_resources_fraction` | fp | `0.5` | `0`–`1` | Poor-rock resources mix. |
| `home_fallback_livability` | fp | `50.0` | in internal min..max | Home livability fallback. |
| `home_fallback_resources` | fp | `50.0` | `≥ 0` | Home resources fallback. |
| `contact_reach` | fp | `4.0` | `≥ 0` | Sandbox neighborhood stamp reach. |

### Planetary resources / accessibility (CPL-112)

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `rare_mineral_weight` | fp | `2.0` | `≥ 0` | Industry composite = common + rare × weight. |
| `access_min` / `access_max` | fp | `0.35` / `1.0` | `0`–`1`, min ≤ max | Spawn accessibility band per resource. |
| `access_floor` | fp | `0.20` | `> 0`–`1` | Floor for `1/access` difficulty (yard, habit, production). |
| `habit_base_ticks` | int | `1` | `≥ 0` | Scale for colony time-to-productive ticks (`0` → instant). |
| `habit_base_wealth_cost` | fp | `25.0` | `≥ 0` | Base wealth charged on populate × air/water difficulty. |
| `productive_rate` | fp | `1.0` | `> 0` (practical: 0.25–4) | CPL-114 global fairness knob: time-to-productive ≈ `habit_base_ticks × effort(qty×access) / productive_rate`. Higher → faster for every rock. |
| `wealth_upkeep_tick_rate` | fp | `0.003` | `≥ 0` (practical: 0–`production_tick_rate`) | CPL-113 farming upkeep; × livability × air/water difficulty. `0` = no wealth upkeep. |
| `resources_upkeep_tick_rate` | fp | `0.003` | `≥ 0` (practical: 0–`production_tick_rate`) | CPL-113 industry upkeep; × mineral composite × mineral difficulty. `0` = no resources upkeep. |

Net income (per owned populated habit-complete rock, per tick):  
`credit = quantity × access × cover × production_tick_rate × afk × allocation`  
`upkeep = quantity × difficulty × <axis>_upkeep_tick_rate × cover × afk × allocation`  
`net = credit − upkeep` (may be negative; empire pools clamp at 0).  
**Productive** iff structural combined net (alloc=1, afk=1) is **> 0** (CPL-114).

### Default hull templates

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `design_scout_speed` / `_size` | fp | `2.0` / `0.5` | `> 0` | Scout template. |
| `design_colony_speed` / `_size` / `_hold` | fp | `1.0` / `5.0` / `10.0` | `> 0` | Colony template. |
| `design_freighter_speed` / `_size` / `_hold` | fp | `1.0` / `2.0` / `10.0` | `> 0` | Freighter template (seed path may be partial). |
| `design_escort_speed` / `_size` | fp | `1.5` / `3.0` | `> 0` | Escort template. |
| `design_frigate_speed` / `_size` | fp | `1.5` / `2.0` | `> 0` | Frigate template. |
| `design_destroyer_speed` / `_size` | fp | `1.0` / `8.0` | `> 0` | Destroyer template. |

### Livability display map

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `livability_internal_min` / `_max` | fp | `0.0` / `100.0` | min ≤ max | Internal livability span. |
| `livability_display_min` / `_max` | int | `1` / `10` | display band (usually 1–10) | Human 1–10 map. |

### Start pools

| Key | Type | Default | Reasonable range | Purpose |
| --- | --- | --- | --- | --- |
| `start_wealth` | fp | `1000.0` | `≥ 0` | Seat starting wealth. |
| `start_resources` | fp | `500.0` | `≥ 0` | Seat starting resources. |
| `start_tech` | fp | `1.0` | `≥ 0` | Seat starting tech. |
| `start_power` | fp | `1.0` | `≥ 0` | Seat starting power. |
| `start_experience` | fp | `0.0` | `≥ 0` | Seat starting experience. |

---

## Banner keys (stdout)

On `--serve` start the server prints (among others):

`HOST=`, `PORT=`, `CONFIG=`, `SCENARIO_MODE=`, `SEED=`, `PLAYERS=`,
`CYCLES=`, `VERBOSITY=`, `INJECTABLE=`, `MENU_KEY=m`, `GO_KEY=g`,
`PHASE=lobby|running`.
