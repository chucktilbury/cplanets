# CPlanets product dialogs and chrome

`GTK-FEATURE-GAPS.md` (infra inventory; [PR #27](https://github.com/cwhip-lang/cplanets/pull/27)
/ Context `gtk-feature-gaps.md`) lists Cwhip GTK **infrastructure**
gaps; this doc inventories **Cplanets product** dialogs and related
chrome (what the game shows and edits), not widget binding gaps.

Cwhip stdlib stays generic — this is Cplanets-specific dialog *design*,
not a request to specialize GTK APIs. Prefer natural flow and few
hoops; match RULES and locked design decisions. Concrete about
**contents** (fields, actions, when shown); name control kinds only
when helpful (slider vs entry).

**Authorities:** repo `doc/RULES.md` (behavior), `doc/PLAN.md` (phases),
`README.md` UI section (intended map chrome), Phase G `src/client/`.
Context: `design-decisions.md`, `project-context.md`,
`gameplay-principles.md`. Do not invent rules — open items stay open.

**Status tags**

| Tag | Meaning |
| --- | --- |
| **Exists (Phase G)** | Present in the shipping human list debugger |
| **Intended playable** | Needed for the intended human play loop (beyond list debugger; may wait on map / `Scale`) |
| **Deferred** | Explicitly not v1 / plan accordingly |

---

## 1. Main window: panels vs true dialogs

### 1.1 Panels (main chrome — not modal dialogs)

| Surface | Role | Contents / actions | Status |
| --- | --- | --- | --- |
| **Main window** | Always-on client shell; never ticks | Title; File menu; status line (tick / counts) | **Exists (Phase G)** |
| **File menu** | Session chrome | Refresh (re-pull state+digest); Quit | **Exists (Phase G)** |
| **Planets notebook page** | Visibility-limited planet list | Scrolled labels: id, owner, livability/resources 1–10 or `quality=unknown`; button “Show first explored” | **Exists (Phase G)** — list stand-in for map |
| **Fleets notebook page** | Visibility-limited fleets + dispatch/recall | Scrolled labels (incl. LOCKED / recall-req); Entries + Dispatch/Recall; design/build progress label | **Exists (Phase G)** list; **dispatch/recall/progress (TUNING B)** |
| **Digest notebook page** | Newspaper / published events | Scrolled digest text (broadcasts + tick events) | **Exists (Phase G)** — read-only list |
| **Policy notebook page** | Standing policy editor | Role, expansion %, escort %, agreement `S`, tech bias %; Apply (PUT `/policy`); no dumb-order warnings | **Exists (Phase G)** — Entries today; **Intended playable** prefers sliders |
| **Map canvas panel** (future main surface) | Galaxy graphic in the client layout | Hot spots; status colors; dotted ETA/order lines; pan/zoom; pick-to-dispatch | **Intended playable** (Phase I; gated on DrawingArea) — not a dialog |

**Principle:** standing policy and lists live as **panels**. True dialogs
are for focused inspect / compose / confirm-ish flows that should not
dominate the main surface. The map is a **panel**, not a dialog.

### 1.2 True dialogs / overlays

| Dialog | When shown | Status |
| --- | --- | --- |
| Explored-planet dialog | On explore (quality known); may refresh when populated/productive | **Exists (Phase G)** + auto-present on quality/productive/populated flips (**TUNING B**); richer content still **Intended playable** |
| Planet status / budget menus | Click planet → menu options (README) | **Intended playable** |
| Map right-click context menu | Right-click / selected planet | **Intended playable** (Phase I chrome) |
| Fleet dispatch / recall surfaces | Pick destination / recall in-flight | **Exists (TUNING B)** as Fleets-tab Entries/buttons (list stand-in; map pick still **Intended playable**) |
| Design / build timing surfaces | Start or inspect design development / yard build | **Intended playable** |
| Compose private message | Player chooses send-to known competitor | **Intended playable** |
| Known-competitors picker | Contact adds names; compose-to-pick | **Intended playable** |
| Pause control | Exactly one human | Server gate **Exists**; client CheckButton **Exists (TUNING B)** (sensitive only when offered) |
| Connection / drop / AFK notices | Human-visible presence feedback | **Intended playable** where human-visible; details **open** |
| Server setup GUI hierarchy | Admin edits §14 knobs before lock | **Deferred** (not v1) |
| Dumb-order warning dialogs | — | **Out of product** (RULES: none) |

---

## 2. Explored-planet dialog (1–10; evolves)

**Locked (design-decisions §18 / RULES §13–§16):** when a planet is
**explored** for that human, **pop a dialog** showing livability /
related quality on a **1–10** scale. The dialog **may change** as the
planet becomes **populated** and **productive**. Mapping internal →
1–10 is setup-owned. AI clients do not need this human dialog.

### Exists today (Phase G)

- `GuiPlanetDialog` (`TransientWindow`): title `Planet {id}`; body from
  `PlanetRow.exploredDialogText()`.
- Fields shown: livability (1–10), quality/resources (1–10), productive
  yes/no, population present/none, note when values may change.
- Trigger: “Show first explored” button (exercises dialog without Tree
  activate) — not yet auto-pop on explore event.
- No-op when `qualityKnown` is false.

### Intended playable

| Aspect | Intent |
| --- | --- |
| **When** | Auto-present (or prominently raise) when quality first becomes known for this seat; refresh/reopen content when populated/productive changes for that rock |
| **Always** | Livability 1–10; related quality (resources / efficiencies as decided for display) on same scale band |
| **When populated** | Population presence (and richer population chrome if RULES later names display fields — **open** if livability also drives tick) |
| **When productive** | Productive status; inherent-defense implication is rules, not a warning dialog |
| **Actions** | Close; from map flow, path into budget / fleet attach without a second hoop if possible |
| **Controls** | Prefer display labels or read-only scales for 1–10; editable budget uses sliders elsewhere |

**Open (do not invent):** whether livability / power / experience also
**drive the tick** vs remain display-only; exact “related” field list
beyond livability + resources already surfaced.

---

## 3. Map right-click and planet status chrome

Depends on Phase I map panel (DrawingArea + pointer + ContextMenu
hooks — infra in GTK-FEATURE-GAPS). Product content:

### 3.1 Right-click / context menu — current planet

**Intended playable.** For the clicked or selected planet:

| Item group | Contents |
| --- | --- |
| **Status** | Owner (if known), explored vs quality-unknown, livability/resources 1–10 when known, populated/productive flags, in-range vs out-of-detection as already flagged by server |
| **Actions** | Open explored dialog (if quality known); open budget / allocation; dispatch / attach fleet toward this rock; other menu options per README (“clicks on it and selects menu options”) |
| **Not included** | Dumb-order warnings; invented confirm dialogs for legal-but-stupid sends |

### 3.2 Known-planets zoom list

**Intended playable.** Same context menu (or submenu): list of
**known** planets the seat can jump/zoom the view to (focus camera on
that rock). “Known” = visibility/driver flags already set — not a
second fog engine.

### 3.3 Map click (non-menu)

**Intended playable.** Click hot spot → select / send ships (README).
In-flight: dotted line origin→progress; arrival clears line for arrival
graphic. Planet color = status (green settled OK → red taken by other;
in-between = intermediate). Pan/zoom overview ↔ detail. Scroll bars
for pan in addition to mouse pan/zoom.

**Exists (Phase G):** none of the map chrome — list labels only.

---

## 4. Policy / budget / allocation / agreements

### 4.1 Empire standing policy (panel)

| Field | Control (intended) | Phase G today | Status |
| --- | --- | --- | --- |
| Role (empire-wide) | Entry or dropdown; not dual roles per partner | `Entry` | **Exists**; polish **Intended** |
| Expansion % | Slider | `Entry` | **Exists** as text; slider **Intended playable** |
| Escort % | Slider | `Entry` | same |
| Agreement size `S` | Slider / spin | `Entry` | same — **player–player** `S`, not planet–planet |
| Tech bias % | Slider | `Entry` | same |
| Apply | Button → PUT `/policy` anytime | Present | **Exists** |

**Flow:** edit anytime; no peer wait; mid-dispatch other policy OK
(that in-flight fleet locked until recall). No warnings for dumb legal
policy.

### 4.2 Planet budget / allocation

**Intended playable** (README: change a planet’s budget via click →
menu). Concrete product surface:

| Content | Notes |
| --- | --- |
| Per-owned-planet spend / allocation knobs | Prefer **sliders**; empire pools remain sacred (no yard logistics tax) |
| Entry point | Planet click / status menu — not a separate maze of windows |
| Exact knob list | **Open** if not already named in RULES beyond “allocations” in standing policy — do not invent per-planet logistics beyond locked empire-pool model |

### 4.3 Agreements UI

**Intended playable.** Propose / accept / change `S` / close with a
**known competitor** (player–player). Changing `S` = new agreement.
Show standing `S` and partner; holds/cargo coverage is rules — UI shows
state, does not babysit. Phase G folds a single `agreementS` into the
policy blob (debugger-shaped); full multi-partner agreement chrome is
still **Intended playable**.

---

## 5. Fleet dispatch / recall

| Surface | When | Contents / actions | Status |
| --- | --- | --- | --- |
| **Dispatch** | Map click destination or fleet action | Choose hulls/design mix from sender; order (`explore` / `take` / trade cycle / `ambush` / … per RULES); confirm send without warning dialogs | **Exists (TUNING B)** list Entries → `PUT /order` (map pick still **Intended**) |
| **In-flight lock** | After dispatch | That fleet’s order not editable except **recall**; game keeps running; other policy editable | Rules locked; list shows `LOCKED` + Dispatch disabled (**TUNING B**) |
| **Recall** | Player recalls | Same-tick cancel if not departed; else return to **sender** (ETA outbound spent, or 0 if tech teleports) | **Exists (TUNING B)** Recall → `PUT /recall` |
| **Fleet list** | Always | Read-only progress (ETA, loc, dest, order) | **Exists (Phase G)** list |

Do **not** freeze the UI on send. Do **not** allow mid-hop rewrite of
that fleet without recall.

---

## 6. Design / build timing surfaces

**Locked:** designing a type and building hulls take **time** (setup /
ticks) — not instant.

| Surface | Contents | Status |
| --- | --- | --- |
| **Design editor** | Speed, range, weapons, shields, size/cargo mix; pay development (mostly wealth); show remaining develop ticks | **Intended playable** |
| **Yard / build queue** | Produce hulls (mostly resources) at productive shipyard; show build duration remaining; reclaim path at shipyard worlds | **Intended playable** |
| **Progress chrome** | Non-modal progress (label / bar) preferred over modal “wait” dialogs — keeps flow | **Intended playable** |

Phase G has **no** design/build UI (policy stub only).

---

## 7. Newspaper / private messages / known competitors

| Surface | Contents | Status |
| --- | --- | --- |
| **Newspaper / digest panel** | Published tick events + **broadcasts**; read after each tick | **Exists (Phase G)** read-only Digest tab |
| **Known competitors list** | Names appear after **contact** (explore and/or conquest of another partition); no contact → no name | **Intended playable** (AI view counts exist; human UI list not shipped) |
| **Compose private message** | Pick recipient from known competitors; compose body; send | **Intended playable** (RULES §13/§16 compose-to-pick) |
| **Broadcast compose** | Optional send-to-all-known / broadcast path if protocol exposes it | **Intended playable** if wire already supports; else follow Phase E verbs — do not invent |

No contact, no private send target. Digest is the primary “what
happened” surface; compose is a focused dialog or side panel — avoid
extra hoops.

---

## 8. Pause (one human)

**Locked:** pause offered only with **exactly one human**; not with
two or more humans.

| Layer | Status |
| --- | --- |
| Server `PUT /pause` + `pauseAllowed` gate | **Exists** (Phase F) |
| Human client Pause control (button/check; sensitive only when offered) | **Exists (TUNING B)** CheckButton → `PUT /pause` |
| Who may unpause / AI-only games | **Open** (design-decisions §11: not locked) |

When multi-human: hide or disable pause — do not show a dead control
that errors as the primary UX.

---

## 9. Connection / drop / AFK notices (human-visible)

**Locked:** handshake distinguishes **AFK** (present, idle policy) from
**drop** (lost contact). AFK = last policy. v1: **no rejoin / no status
save**; drop → last policy for live remainder; all-humans-quit ends
game.

| Notice | Audience | Status |
| --- | --- | --- |
| Local “you are AFK / idle” soft chrome | Self | **Intended playable** if useful; magnitudes of AFK shrink **open** |
| Local “connection lost / dropped” | Self | **Intended playable** — clear that seat is not reclaimable in v1 |
| Peer `dropped` digest event | Other humans | **Open** (whether peers see it — RULES §17) |
| Heartbeat interval / miss threshold | Protocol | **Open** — not product copy until locked |
| Reconnect / save dialogs | — | **Deferred** / out of v1 |

Prefer digest lines and a small status chrome over modal stacks.

---

## 10. Future server setup GUI hierarchy (**Deferred**)

Not v1. Plan accordingly so §14 knobs stay organized outside code.
Outline of **sections of knobs** (not a full widget tree):

1. **Clock / presence** — tick period seconds (provisional 1–30); AI-lag
   auto-config link; AFK timeout/shrink fields (when named); pause is
   runtime eligibility, not a setup toggle for multi-human.
2. **Galaxy / scenario** — world count; useful vs poor mix; starting
   scout-range; scenario mode (v1 closed); fixture identity.
3. **Visibility / identify** — tech→range mapping; attacker-side and
   defender-side identify mappings (separate); balance notes only in
   docs, not extra dialogs.
4. **Travel / combat** — tech→teleport/ETA mapping; battle-duration /
   comparative-strength coefficients; productive inherent defense;
   pirate attrition; stranded-ticks `N`; idle `N`.
5. **Economy / production** — trade/attack bumps; dispatch weight;
   design cost mappings; **design-develop duration**; **yard-build
   duration**; reclaim percent; voyage cost; cover; capture-use.
6. **Display mappings** — livability (and related) → 1–10.
7. **Roles / AI** — role coefficient tables; AI reaction lag (and any
   tick auto-link).

Admin edits **before** start; locked in progress. No save/rejoin UI in
v1. File/scenario edit remains the v1 path.

---

## 11. Phase G vs remaining (summary)

### Already in Phase G / TUNING B human client

- Main window + File Refresh/Quit
- Notebook: Planets, Fleets, Digest, Policy
- Explored-planet TransientWindow (1–10 + populated/productive note);
  manual “Show first explored” + auto-present on quality /
  productive / populated flips (**TUNING B**)
- Policy Entries + Apply PUT; no dumb-order warnings
- TCP pull of seat-scoped publish flags (no second fog)
- Pause CheckButton → `PUT /pause` (one-human sensitive) (**B**)
- Fleet Dispatch / Recall Entries → `PUT /order` / `PUT /recall`
  with in-flight lock labels (**B**)
- Design/build/reclaim progress label from chrome trailer (**B**)

### Remaining for intended playable human UI

- Map canvas panel + right-click status / zoom-to-known
- Sliders for policy / budget; richer planet budget menus
- Richer design editor / yard queue (beyond progress labels)
- Known-competitors list + private compose (+ broadcast if applicable)
- Human-visible AFK / drop notices (peer notify still open)
- Full multi-partner agreements UI beyond single `agreementS` stub

### Deferred

- Server setup GUI dialog hierarchy (§10)
- Durable save / rejoin / reclaim dialogs
- Ongoing-map join/sandbox UI (future scenario mode)
- AI client’s “later dialogs” (PLAN H)

### Explicit non-goals

- Warning dialogs for legal-but-stupid orders
- Specializing Cwhip GTK for Cplanets-only widgets (use generic gaps
  list instead)

---

## 12. Open design questions (UI-relevant)

Leave open; do not invent product rules here:

1. Livability / power / experience as **tick drivers** vs display-only.
2. Exact planet **budget** knob set under empire-pool model.
3. Pause: who unpauses; AI-only games.
4. Peer visibility of `dropped`; heartbeat copy thresholds.
5. Identify **audience** after success (victim-only default).
6. Explored dialog auto-pop vs raise-existing; full “related” field set.
7. Whether compose is a modal dialog or a main-window side panel
   (prefer few hoops — either is fine if one click from digest).

---

## Cross-links

| Doc | Role |
| --- | --- |
| Context `docs/cplanets-dialogs.md` | Same inventory (Project store) |
| [GTK-FEATURE-GAPS.md](GTK-FEATURE-GAPS.md) | Cwhip GTK infra gaps (lands with PR #27 if not yet on main) |
| [RULES.md](RULES.md) §13–§16 | Visibility, messages, client UI rules |
| [PLAN.md](PLAN.md) §4.G / §4.I | Phase G done; map Phase I |
| [CPLANETS.md](CPLANETS.md) | User / operator guide |
