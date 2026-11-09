# Human client config reference

Own settings file for `cplanets` (GTK / headless human client) —
**not** the AI config (RULES §2). Sample:
[`config/human-default.cfg`](../config/human-default.cfg).
Headless CTest samples: `tests/config/human-*.cfg`.

Syntax: `key = value`. Blank lines and `#` comments are skipped.
**Unknown keys are ignored** today (unlike server/AI fail-loud) —
prefer only documented keys so future fail-loud stays easy.

`--config PATH` is mandatory (no in-file key). CLI flags present on
argv override file values **silently**.

Clients **never tick** and **never open** the universe DB. TCP seats
are **server-assigned** on handshake; do not set `player_id` for
normal live play.

See also: [CPLANETS.md](CPLANETS.md), [DIALOGS.md](DIALOGS.md),
[SERVER-CONFIG.md](SERVER-CONFIG.md).

---

## Dial / connection

| Key | Type | Code default | Sample (`human-default`) | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `host` | string | `127.0.0.1` | `127.0.0.1` | hostname / IP | Server dial address. CLI `--host`. |
| `port` | int | `0` | `7700` | `≥ 0` | Server dial port. `0` = offline in-process galaxy (`--gui` / `--test` / `--once`). CLI `--port`. Match server sample `7700` for live play. |
| `player_id` | int | `-1` | (omit) | `-1` or `≥ 0` | Legacy / offline seat pin. Live TCP: leave `-1`; server assigns. Offline `--once` / port `0` may call `ensureOfflineSeat` → `0`. CLI `--player`. |

`reconnectToken` is **not** a file key (opaque `TOKEN_BYTES` from
handshake ack, process-local, for reclaim).

---

## Mode flags (CLI mirrors)

| Key | Type | Code default | Sample | Reasonable range | Purpose |
| --- | --- | --- | --- | --- | --- |
| `once` | bool | `false` | `false` | `true`/`false`/`1`/`0` | One-shot headless summary / smoke. CLI `--once`. |
| `pull` | bool | `false` | `false` | bool | Headless TCP pull (state + digest). CLI `--pull`. |
| `gui` | bool | `false` (ctor) / `true` (sample) | `true` | bool | Open GTK UI. CLI `--gui`. CTest uses `gui = false`. |
| `test` | bool | `false` | `false` | bool | Offline test / in-process path. CLI `--test`. |

Typical combinations:

| Intent | Keys |
| --- | --- |
| Live GTK play | `gui = true`, `port = 7700` (or CLI `--port`) |
| Headless pull smoke | `pull = true`, `gui = false`, matching server port |
| Offline once | `once = true`, `port = 0` |
| CTest smoke identity | `gui = false`, no once/pull (prints name) |

---

## Notes

- Mode FLAGs: file `true`/`false`; argv presence of `--gui` / `--pull`
  / `--once` / `--test` forces the switch **on**.
- UI prefs (sliders, dialog layout) are not textfile keys yet —
  near-term chrome direction is in project preferences / DIALOGS.
- For operator play, keep human `host`/`port` aligned with
  [SERVER-CONFIG.md](SERVER-CONFIG.md) listen bind.
