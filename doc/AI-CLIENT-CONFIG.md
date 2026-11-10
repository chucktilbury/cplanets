# AI client config reference

Own settings file for `cplanets-ai` (not the human settings file;
RULES §2). Sample: [`config/ai-default.cfg`](../config/ai-default.cfg).
Aggression bands: `config/ai-{soft,mid,hard}.cfg`.

Syntax: `key = value`. Unknown keys **fail loud**. `--config PATH`
is mandatory (no in-file key). CLI flags present on argv override
file values **silently**.

TCP seats are **server-assigned** on `PUT /handshake`. Do not rely
on `player_id` for live multi-AI seating (legacy key; `-1` =
unassigned until handshake).

See also: [CPLANETS.md](CPLANETS.md), [SERVER-CONFIG.md](SERVER-CONFIG.md).

---

## Difficulty axes (soft → hard)

Axes are continuous floats clamped to **\[0.0, 1.0\]** after load.

| Key | Type | Code default | Sample (`ai-default`) | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `aggression` | fp | `0.5` | `0.55` | `0`–`1` | How readily the AI picks fights / presses. |
| `role_stickiness` | fp | `0.7` | `0.70` | `0`–`1` | Resistance to role changes (pirate/trader/…). |
| `expansion` | fp | `0.5` | `0.50` | `0`–`1` | Colony / claim appetite. |
| `escort` | fp | `0.5` | `0.55` | `0`–`1` | Escort freighters / war escorts. |
| `agreement_appetite` | fp | `0.4` | `0.40` | `0`–`1` | Willingness to open trade agreements. |
| `tech_vs_hulls` | fp | `0.5` | `0.45` | `0`–`1` | Bias tech research vs hull production (`0` = hulls, `1` = tech). |

Band presets (approx.): soft ≈ low aggression / high stickiness;
hard ≈ high aggression / lower stickiness. Magnitudes are placeholders.

---

## Reaction lag / surprise

Distinct from `loop_period_ms` (serve-loop frame budget). Binding
shape (ticks vs wall) is still open in RULES.

| Key | Type | Code default | Sample | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `reaction_lag_ticks` | int | `1` | `1` | `≥ 1` (clamped) | Delay decisions by this many ticks. |
| `reaction_lag_seconds` | fp | `2.0` | `5.0` | `≥ 0` | Wall-clock lag shape (seconds). |
| `surprise_rate` | fp | `0.05` | `0.05` | `0`–`1` | Chance of a surprise / off-policy action. |

---

## Dial / connection

| Key | Type | Code default | Sample | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `seed` | uint | `1` | `42` | `≥ 1` (`0` remaps to `1`) | Pins surprise / role rolls for reproducible runs. |
| `player_id` | int | `-1` | (omit / `-1`) | `-1` or `≥ 0` | Legacy seat pin. Live TCP: leave `-1`; server assigns. Offline `--once` may pin via `ensureOfflineSeat`. |
| `host` | string | `127.0.0.1` | `127.0.0.1` | hostname / IP | Server dial address. CLI `--host`. |
| `port` | int | `0` | `7700` | `≥ 0` | Server dial port (`0` = offline / no TCP). CLI `--port`. |
| `display_name` | string | `""` | (omit) | proper name | Seat label sent via `PUT /name` after handshake. Empty → pick once from the proper-name pool (Alex, Bethany, …) using `seed`. Server `spawn_ai_*` overlays a unique name per child config. |

`reconnectToken` is **not** a file key (opaque bytes from handshake
ack, process-local).

---

## Process / CLI mirrors

| Key | Type | Code default | Sample | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `verbosity` | int | `0` | `10` | `0`–`10` (clamped) | Stdout decision logging. CLI `--verbosity`. Provisional: `0` errors; `3+` seat/policy/cycle; `10` full. |
| `cycles` | int | `0` | `0` | `≥ 0` | `0` = serve until eliminated / ended / stop; `N>0` caps attempts. CLI `--cycles`. |
| `once` | bool | `false` | `false` | bool | One-shot policy shape / offline path. CLI `--once`. |
| `serve_loop` | bool | `false` | `true` | bool | Continuous TCP serve-loop. CLI `--serve-loop`. |
| `loop_period_ms` | int | `100` | `100` | `≥ 0` | Target frame period (ms): measure work, sleep leftover. `0` = no leftover sleep. CLI `--loop-period-ms`. Not reaction lag. |

---

## Notes

- Edit axes → restart `cplanets-ai` (no mid-run retune).
- Multi-AI sessions: identical configs are fine; seats come from
  handshake, not distinct `player_id` values.
- Server tick period may auto-config from scenario AI lag fields
  (`tick_auto_config_from_ai_lag` in [SERVER-CONFIG.md](SERVER-CONFIG.md));
  client `reaction_lag_*` is the AI's own decision gate.
