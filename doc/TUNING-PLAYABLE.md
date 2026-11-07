# Playable completeness + knobs — next-phase plan

**Scope:** plan / docs. After A–H on `origin/main`, workstreams
**A–C landed a session harness** (setup path, list chrome for pause /
dispatch-recall, fixtures + AI presets). That harness is **plumbing**,
not balance-complete. “Tuning” means **balancing game variables to
make play interesting** — not merely getting files and TCP working.

**North star (current):** (1) playable completeness for a first-move
loop, (2) **full externalized knobs** (text file at minimum for
virtually every planet / ship / player / combat / travel / production /
identify / clock variable; some via human GUI; most **server**
settings stay textfile), (3) **then** balance passes. Do **not** treat
magnitude balancing as the current priority.

**Authorities:** [RULES.md](RULES.md) (behavior), [PLAN.md](PLAN.md)
(A–H history), [KNOB-COVERAGE.md](KNOB-COVERAGE.md) (inventory), this
file (phase order). Companions: [DIALOGS.md](DIALOGS.md),
[GTK-FEATURE-GAPS.md](GTK-FEATURE-GAPS.md), [CODING.md](CODING.md).
Prefer `./scripts/setup`. Preferences: Cwhip stdlib stays generic;
full method comments.

**Context twin:** Project store `docs/tuning-playable-plan.md`.

**Open sibling:** [#34](https://github.com/cwhip-lang/cplanets/pull/34)
(solo one-shot TCP) — still open when this reframe landed; pull when
merged.

---

## 1. What A–C delivered (plumbing)

| Workstream | Status | What it is |
| --- | --- | --- |
| **A** knob surface | Done (PR #30) | `--setup` / unknown-key fail / restart-only contract |
| **B** list chrome | Done (PR #31) | Pause, dispatch/recall, explored auto-pop, design/build **labels** |
| **C** session harness | Done (PR #32) | `scripts/tuning-session`, fixture packs, AI soft/mid/hard, CTest |
| **D** map | Done (Phase I) | Map panel chrome; not required for balance passes |

A–C make it possible to **edit named keys, restart, and observe**.
They do **not** mean combat/economy magnitudes are “tuned,” and they
do **not** finish first-move playable chrome (ship create / design /
yard queue still missing — see [KNOB-COVERAGE.md](KNOB-COVERAGE.md)
and [DIALOGS.md](DIALOGS.md)).

---

## 2. Definition of done — next slice (playable + knobs)

A session is ready for **balance passes** when:

1. **First-move chrome** exists for ship create / design / yard (list
   stand-ins OK; no map required) so a human is not stuck with only
   seeded fleets.
2. **Virtually every** sim variable that touches planets, ships,
   players, combat, travel, production, identify, clock is settable
   from a **text file** (wire named-but-unused keys; lift remaining
   hardcoded rates/costs/templates) — inventory in
   [KNOB-COVERAGE.md](KNOB-COVERAGE.md).
3. **Selective human GUI** setters exist where play needs them
   (policy / budgets / design-build); **server** knobs stay files.
4. Human can still **start** via `scripts/setup` / run recipe, **pause**
   (one human), **re-run** same seed after knob edits.

**Explicitly later:** inventing open magnitudes; richer map dispatch
polish (hull-mix picker, etc.); full server setup GUI hierarchy;
durable save/rejoin; specializing Cwhip GTK for Cplanets-only widgets.

---

## 3. Suggested build order (post A–C)

1. **Playable chrome gaps** — ship create / design editor / yard queue
   (and other Intended-playable blockers in [DIALOGS.md](DIALOGS.md)
   that block a first loop).
2. **Externalize remaining knobs** — see [KNOB-COVERAGE.md](KNOB-COVERAGE.md)
   top gaps (`attack_bump` / AFK wire-up, production `0.01`, build/design
   cost bases, galaxy spawn fractions, design templates, handshake miss).
3. **Selective GUI setters** — Entry/Scale for human dials; keep server
   as textfile (RULES §14).
4. **Balance tuning** — edit files → restart → harness / manual loops.
   No invented magnitudes in code PRs “while here.”

Optional **D** map only after DrawingArea in an installed SDK.

---

## 4. Open decisions (decide-when-blocking)

Unchanged principle: do **not** invent. Flag when blocked:

| Topic | Blocks | Notes |
| --- | --- | --- |
| **Planet budget knob set** under empire-pool model | Richer per-planet budget UI | Standing policy % exists |
| **Livability / power / experience as tick drivers** | Economy driver role | Display 1–10 locked |
| **Peer `dropped` digest / heartbeat thresholds** | Peer drop UX | Local drop notice can ship |
| **Pause: who unpauses** (and AI-only) | Exact unpause UX | One-human pause eligibility locked |
| **Server setup GUI vs `.cfg`** | Admin GUI invest | **v1 = files**; most server settings stay textfile |
| AI lag **binding shape** | Tick-feel defaults | Expose ticks+wall until locked |
| Identify / combat / teleport **magnitudes** | Balance only | Knobs exist or need wire-up; values open |

---

## 5. Cwhip GTK dependencies (do not specialize stdlib)

| Need | Impact | Gate |
| --- | --- | --- |
| **`Gtk.Scale`** | Policy/budget polish | Entry OK until Scale ships |
| **`DrawingArea` + input + scrollbars + ContextMenu** | Map Phase I | Optional |
| Declarative setup panel builder | Future server setup GUI | Deferred |
| Existing Notebook / Entry / Button / TransientWindow | List debugger + chrome | Have |

---

## 6. Suggested PR / chunk sizes

One concern per PR; short `.cw` files; full method comments;
CTest/fn where behavior lands.

| PR style | Example |
| --- | --- |
| Docs-only | This plan; [KNOB-COVERAGE.md](KNOB-COVERAGE.md) |
| Playable chrome slice | Yard build Entry → queue; design draft form |
| Knob externalize slice | One cluster of literals → setup keys + parse + test |
| Balance later | Fixture magnitude edits only — after chrome + coverage |
| Never mix | Map + knob dump; inventing RULES magnitudes “while here” |

---

## Progress archive — A / B / C (plumbing)

### A — Knob surface (PR #30)

| Chunk | Landed |
| --- | --- |
| A1 | Grouped keys in `scenarios/closed-default.setup` + `config/ai-default.cfg` |
| A2 | `cplanets-server --setup PATH` (+ `--seed`); unknown keys fail loud |
| A3 | Restart contract in [CPLANETS.md](CPLANETS.md); no mid-game retune |
| A4 | CTest `functional_setup_path` |

### B — List chrome (PR #31)

| Chunk | Landed |
| --- | --- |
| B1–B4 | Pause; dispatch/recall; explored auto-pop; design/build progress **labels** |
| B5 | Deferred (known-competitors / compose) |
| B6 | Scale polish later |
| **Still missing** | Ship create / design editor / yard queue chrome |

### C — Session harness (PR #32)

| Chunk | Landed |
| --- | --- |
| C1–C4 | Operator recipe; `functional_session_harness`; tuning fixtures; AI soft/mid/hard |

**How to re-run a comparable loop (after balance work starts):** edit
setup/AI knobs → stop → `./scripts/tuning-session --setup … --seed 77
--ai-config …` with the **same seed** → attach human. CI proof:
`ctest -R functional_session_harness`.
