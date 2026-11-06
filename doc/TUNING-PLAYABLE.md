# Tuning-ready playable — next-phase plan

**Scope:** plan only (no game code in this doc’s landing PR). Next
phase after A–H on `origin/main` — get a **human + AI** session that
can run **balance / tuning loops**. Map / Phase I is **optional and
gated**, not required to start tuning.

**Authorities:** [RULES.md](RULES.md) (behavior), [PLAN.md](PLAN.md)
(A–H work shape; this file owns **next-phase** order). Companions
(Context / open docs PRs): product dialogs
([#28](https://github.com/cwhip-lang/cplanets/pull/28) →
[DIALOGS.md](DIALOGS.md) when merged), GTK gaps
([#27](https://github.com/cwhip-lang/cplanets/pull/27) →
[GTK-FEATURE-GAPS.md](GTK-FEATURE-GAPS.md) when merged). Preferences:
Cwhip stdlib stays generic; prefer `scripts/setup`; full method
comments ([CODING.md](CODING.md)).

**Context twin:** Project store
`docs/tuning-playable-plan.md` (same plan).

---

## 1. Definition of done — “tuning-ready playable”

A session is **tuning-ready** when a human can:

1. **Start** a stand-alone closed fixture (`cplanets-server` + one
   `cplanets` + one or more `cplanets-ai`) via documented
   `scripts/setup` / run steps ([CPLANETS.md](CPLANETS.md)).
2. **Edit economy / combat / travel / AI knobs** in setup / AI config
   **outside code**, restart (or reload where allowed), and see
   behavior change in digest + lists — without rebuilding for each
   magnitude tweak.
3. **Drive standing policy** from the human client (Entries OK where
   `Scale` is missing) and observe fleets / planets / digest update
   across ticks.
4. **Issue enough fleet/order chrome** to exercise explore / take /
   trade / recall paths used in balance loops (list / Entry / button
   stand-ins OK — **no map required**).
5. **Pause** when exactly one human (server gate already exists);
   client control present and gated.
6. **Re-run** the same seed + fixture after a knob edit and get a
   comparable loop (harness / smoke documented).

**Explicitly out of DoD:** Phase I map canvas; server setup GUI
hierarchy; durable save/rejoin; inventing open magnitudes; specializing
Cwhip GTK for Cplanets-only widgets.

---

## 2. Already done vs gaps

| Area | On main (A–H) | Gap for tuning loops |
| --- | --- | --- |
| **Sim / lib** | Tick machine, D1–D5 clusters, §14 knobs named in `scenarios/closed-default.setup` | Magnitudes are placeholders; some open RULES forks (formulas / tick-driver livability) — tune around defaults until locked |
| **Server** | Real-time cadence, TCP, SQLite-shaped snapshot, pause gate, presence handshake shape, digest publish; **`--setup` path load** (workstream A) | Mid-game retune (deferred); peer-drop UX thin; harness beyond smoke (workstream C) |
| **AI** | Config axes, lag (ticks+wall), surprise band, tick-period suggest | Binding-shape still open; need documented multi-seat fixture + retune cycle |
| **Human client** | List notebook (planets/fleets/digest/policy), explored dialog skeleton, policy Entries + Apply; **B:** pause, dispatch/recall, explored auto-pop, design/build progress labels | Agreements beyond stub; AFK/drop notices; Scale swap (B6); map (D) |
| **Dialogs / chrome** | Inventory ([#28](https://github.com/cwhip-lang/cplanets/pull/28)) | Implement **Intended playable** items that block loops (not map) |
| **Knobs** | Outside-code principle + fixture file; **restart contract + path load + unknown-key fail** (workstream A) | No v1 setup GUI (deferred); magnitudes still placeholders |
| **Map (I)** | Gated on DrawingArea ([PLAN.md](PLAN.md) §4.I) | **Optional** after Cwhip GTK — not on the critical path |

---

## 3. Workstreams (ordered)

Do **A → B → C** for DoD. **D** only after DrawingArea lands in an
installed SDK.

### A — Knob surface / config reload for tuning

**Goal:** change combat/production/travel/identify/AI magnitudes
without a code change, with a clear restart-vs-reload contract.

| Chunk | Deliverable |
| --- | --- |
| A1 | Document which keys in `closed-default.setup` + `ai-default.cfg` are the **tuning surface** (group: clock, galaxy, identify, travel/combat, economy, display, AI) — align with RULES §14 / dialogs setup outline |
| A2 | Server/CLI: load fixture by path (operator path today is thin); fail loud on unknown keys |
| A3 | **Reload policy:** prefer **restart process** for locked-in-progress setup (RULES); optional pre-start reload only — **do not invent** mid-game retune unless the user locks it |
| A4 | Tiny “edit knob → restart → advance N ticks → assert digest/stock delta” functional smoke (seeded) |

**Depends on:** nothing new from GTK. **Decide-when-blocking:** mid-game
knob edit vs restart-only; server GUI vs `.cfg` (see §4).

### B — Human chrome without DrawingArea

**Goal:** drive a balance loop from the list client. **Entry stand-ins
OK** where `Scale` is missing; prefer sliders only when Cwhip ships
`Gtk.Scale` (generic stdlib — not Cplanets-specialized).

| Chunk | Deliverable |
| --- | --- |
| B1 | Pause control wired to `PUT /pause` (sensitive only when one human) |
| B2 | Fleet dispatch / recall chrome (list pick + Entries/buttons; reflect in-flight lock) |
| B3 | Explored dialog auto-present / refresh on quality & productive changes |
| B4 | Minimal design/build progress chrome (non-modal labels; durations from setup) |
| B5 | Known-competitors + compose stub if wire already supports; else follow Phase E verbs only |
| B6 | When `Scale` available: swap policy % / `S` Entries → sliders (polish PR; not DoD-blocking) |

**Depends on:** Cwhip **Scale** for B6 only; B1–B5 use existing widgets
(`Button`, `Entry`, `CheckButton`, `TransientWindow`, …). See GTK gaps
doc / [#27](https://github.com/cwhip-lang/cplanets/pull/27).

### C — AI + human session harness / fixtures

**Goal:** one documented recipe + CI-friendly harness for tuning loops.

| Chunk | Deliverable |
| --- | --- |
| C1 | Operator recipe in [CPLANETS.md](CPLANETS.md): server + human + N AI, configs, seed, tick period |
| C2 | Python functional: human-shaped client (or `--once`/`--pull`) + AI attach; injectable clock advance; assert digest grows / policies apply next tick |
| C3 | Fixture packs: “small closed” + “tuning combat” / “tuning trade” scenario copies (same schema, different magnitudes) — **placeholder values OK** until locked |
| C4 | AI config presets (soft / mid / hard aggression bands) for A/B comparison |

**Depends on:** A2 path load helpful; B1–B2 for manual loops.

### D — Optional map (after DrawingArea)

**Not required for tuning DoD.** When Cwhip exposes DrawingArea +
`queueDraw` + draw primitives + pointer + scrollbars + ContextMenu
hooks (GTK gaps steps 1–4):

| Chunk | Deliverable |
| --- | --- |
| D1 | Map panel scaffold in client layout |
| D2 | Hot spots, status colors, dotted ETA |
| D3 | Pick / pan / zoom / scrollbar / right-click status |

Keep map PRs separate from A–C tuning PRs.

---

## 4. Open decisions (decide-when-blocking)

Do **not** invent. Flag when a workstream cannot proceed without a
user lock:

| Topic | Blocks | Notes |
| --- | --- | --- |
| **Planet budget knob set** under empire-pool model | Richer per-planet budget UI (B) | Standing policy % exists; per-planet spend list still thin |
| **Livability / power / experience as tick drivers** | Whether display-only dials are enough for economy tuning | Display 1–10 locked; tick-driver role open ([PLAN.md](PLAN.md) §9) |
| **Peer `dropped` digest / heartbeat thresholds** | Peer drop UX copy | Local drop notice can ship; peer notify open |
| **Pause: who unpauses** (and AI-only) | Exact unpause UX | One-human pause eligibility locked |
| **Server setup GUI vs `.cfg` for tuning** | Whether A invests in GUI | **Deferred GUI**; v1 tuning path = scenario/AI **files** + restart (RULES §14) |
| AI lag **binding shape** / auto-config **mapping** | Tick-feel defaults | Direction locked; expose both ticks+wall until locked |
| Identify **magnitudes** / **audience** | Balance targets only | Asymmetry direction locked |
| Combat / teleport **magnitudes** | Numeric targets only | Knobs exist; values open |

---

## 5. Cwhip GTK dependencies (do not specialize stdlib)

| Need | Tuning impact | Gate |
| --- | --- | --- |
| **`Gtk.Scale`** | Intended policy/budget controls | Workaround: `Entry` — **OK for DoD** |
| **`DrawingArea` + input + scrollbars + ContextMenu hooks** | Map Phase I | **Optional**; not DoD |
| Declarative / config-driven panel builder | Future server setup GUI | **Deferred** with that GUI |
| Existing: Window, Notebook, Entry, Button, TransientWindow, … | List debugger + B1–B5 | **Have** |

Gap lists may motivate generic GTK work; APIs stay general-purpose.

---

## 6. Suggested PR / chunk sizes

Match prior phase style: **one concern per PR**, docs-or-code focused,
short `.cw` files, full method comments, CTest/fn where behavior lands.

| PR style | Example |
| --- | --- |
| Docs-only | This plan; operator recipe; knob glossary |
| Thin wire/CLI | Scenario path load + unknown-key fail |
| Human chrome slice | Pause only; then dispatch/recall; then explored auto-pop |
| Harness | One Python functional per fixture class |
| Polish | Scale swap when GTK ready; map only after DrawingArea |
| Never mix | Map + knob reload; or inventing RULES magnitudes “while here” |

Rough size: **~1–3 production files + tests** per chrome/harness PR
(similar to D1–D5 / F / G / H slices), not a mega “playable” dump.

---

## 7. Suggested build order

1. **A1–A2** (docs + load path) → **C1** recipe  
2. **B1** pause → **B2** dispatch/recall  
3. **A3–A4** + **C2–C4** harness / fixtures  
4. **B3–B5** dialog/chrome that unblock observation  
5. **B6** when Scale ships; **D\*** only after DrawingArea  

[PLAN.md](PLAN.md) keeps A–H history; this file is the next-phase
pointer.

---

## Progress — workstream A (knob surface)

**Status:** implemented on the tuning-knobs branch (operator path =
files + restart; no setup GUI).

| Chunk | Landed |
| --- | --- |
| A1 | Grouped keys in `scenarios/closed-default.setup` + `config/ai-default.cfg` (clock / galaxy / identify / travel-combat / economy / display / AI) |
| A2 | `cplanets-server --setup PATH` (+ `--seed`); unknown keys fail loud on setup + AI config |
| A3 | Restart contract documented here and in [CPLANETS.md](CPLANETS.md); no mid-game retune |
| A4 | CTest `functional_setup_path` — temp fixture knobs → restart path → advance → assert planet count + wealth delta; unknown-key exit |

**How to retune:** edit the setup / AI file → stop processes →
`./scripts/setup` shell → `build` only if code changed → restart
server with `--setup` and AI with `--config`. Magnitudes stay
placeholders until RULES locks them.

---

## Progress — workstream B (list chrome)

**Status:** implemented on the tuning-list-chrome branch (list
debugger only; no map / DrawingArea).

| Chunk | Landed |
| --- | --- |
| B1 | Pause `CheckButton` → `PUT /pause`; sensitive only when `humanCount == 1` (server gate unchanged) |
| B2 | Fleets tab Entries + Dispatch / Recall → `PUT /order`, `PUT /recall`; list shows `LOCKED` / `recall-req`; Dispatch disabled when in-flight locked |
| B3 | Explored dialog auto-present / refresh via `ExploredTrack` on quality-first and productive/populated flips (manual button kept) |
| B4 | Non-modal design/build/reclaim progress label + setup `designDevelopTicks` / `yardBuildTicks` from chrome trailer |
| B5 | Deferred — known-competitors / compose not on the wire yet (Phase E verbs only); no invented protocol |
| B6 | Still Entry stand-ins for policy % / `S` (Scale polish later) |

**Wire adds:** `PUT /order` (player, fleet, dest, order string;
`trade` → self-trade stand-in), `PUT /recall`; state blob chrome
trailer after fleets (`paused`, setup durations, developing /
build / reclaim rows); fleet flags `pendingDeparture` /
`recallRequested`.

**Tests:** `fn_listChrome`, `functional_list_chrome`.
