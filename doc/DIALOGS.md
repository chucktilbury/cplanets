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
| **Main window** | Always-on client shell; never ticks | Title; File + Fleets/Ships submenus + Planets/Digest/Policy openers; status line (tick / counts); map canvas | **Exists (Phase G + menubar + CPL-110)** |
| **File menu** | Session chrome | Refresh (re-pull state+digest); Quit | **Exists (Phase G)** + live GUI also polls state+digest on `refresh_ms` (default 1000; `0`=off; distinct from presence keep-alive) |
| **Panel openers** | Former Notebook names | **Planets / Digest / Policy** — root-label flat Buttons raise non-modal dialogs. **Fleets / Ships** — real MenuBar submenus of smaller Apply+Close dialogs (**CPL-110**) | **Exists** |
| **Map canvas panel** | Galaxy graphic as the main client surface | Hot spots; status colors; dotted ETA paths; pan/zoom; pick→fleet dest; ContextMenu status + zoom-to-known + dispatch/budget | **Exists (Phase I + pick-to-dispatch)** |

**Principle:** the map is the main **panel**. Standing policy and list
chrome open as **non-modal menubar dialogs**. Ships/Fleets use
**smaller submenu dialogs** (Apply + Close) instead of one mega
panel each. Focused inspect dialogs (explored / examine) remain
separate TransientWindows.

### 1.2 True dialogs / overlays

| Dialog | When shown | Status |
| --- | --- | --- |
| **Planets panel dialog** | Planets root click (or map budget ContextMenu) | **Exists** — former Planets notebook page in `GuiPanelDialog` (list + explored button + budget Scale) |
| **Fleets→Create** | Fleets → Create | **Exists (CPL-110)** — name + park planet; Apply → `PUT /fleet` |
| **Fleets→Deploy** | Fleets → Deploy (or map dispatch ContextMenu) | **Exists (CPL-110)** — fleet/order/dest/hulls; Apply → `PUT /order`; Recall button; **travel** ProgressBar; map pick fills dest |
| **Fleets→Inventory** | Fleets → Inventory | **Exists (CPL-111)** — per-planet stock multi-select + fleets; Assign / Un-assign buttons (`PUT /assign` / `PUT /unassign`); Apply → Examine |
| **Ships→Develop** | Ships → Develop | **Exists (CPL-110/111)** — design Entries + kind (default **scout**); Apply → `PUT /design`; develop **ProgressBar**; noop when same params exist |
| **Ships→Build** | Ships → Build | **Exists (CPL-111)** — yard + seat-developed type + **qty**; Apply → `PUT /build`; build **ProgressBar**; no phantom scout/colony |
| **Ships→Reclaim** | Ships → Reclaim | **Exists (CPL-110)** — stock reclaim Apply → `PUT /reclaim-stock`; fleet reclaim button → `PUT /reclaim-hulls`; reclaim **ProgressBar** |
| **Ships→Inventory** | Ships → Inventory | **Exists (CPL-110)** — type inventory (specs + available); select type; Apply → Examine |
| **Empire panel dialog** | Empire root click | **Exists (CPL-111)** — empire pool + planets + fleets + stock; Apply refreshes; Close |
| **Digest panel dialog** | Digest root click | **Exists** — newspaper + known competitors + compose (recipient choice row); tooltips |
| **Policy panel dialog** | Policy root click | **Exists** — role choice row + % Scales + Apply; tooltips |
| Explored-planet dialog | On explore (quality known); may refresh when populated/productive | **Exists (Phase G)** + auto-present on quality/productive/populated flips (**TUNING B**); richer content still **Intended playable** |
| Fleet examine dialog | Fleets→Inventory **Apply** (selected / first visible) | **Exists** — `GuiFleetDialog` TransientWindow from `FleetRow.examineDialogText()` |
| Design / ship examine dialog | Ships→Inventory **Apply** (selected / first catalog) | **Exists** — `GuiShipDialog` TransientWindow from `DesignRow.examineDialogText()` |
| Planet status / budget menus | Click planet → menu options (README) | Budget **Exists** on Planets panel + map ContextMenu (owned) |
| Map right-click context menu | Right-click / selected planet | **Exists** — status + explored + zoom-to-known + dispatch/budget (owned) |
| Fleet dispatch / recall surfaces | Pick destination / recall in-flight | **Exists** — Fleets→Deploy; map pick fills dest; ContextMenu “Dispatch fleet here” → Deploy + `PUT /order` |
| Design / build timing surfaces | Start or inspect design development / yard build | **Exists** — Ships→Develop / Ships→Build |
| Compose private message | Player chooses send-to known competitor | **Exists** (Digest panel DropDown + multiline TextView) |
| Known-competitors picker | Contact adds names; compose-to-pick | **Exists** (list + To choice row) |
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
- Fields shown: farming/industry composites (1–10), air/water/common+rare
  minerals and each accessibility (1–10), productive
  yes/no, population present/none, note when values may change.
- Trigger: “Show first explored” button (exercises dialog without Tree
  activate) — not yet auto-pop on explore event.
- No-op when `qualityKnown` is false.

### Intended playable

| Aspect | Intent |
| --- | --- |
| **When** | Auto-present (or prominently raise) when quality first becomes known for this seat; refresh/reopen content when populated/productive changes for that rock |
| **Always** | Farming + industry 1–10; air / water / common+rare minerals and accessibility on same scale band (CPL-112) |
| **When populated** | Population presence (and richer population chrome if RULES later names display fields — **open** if livability also drives tick) |
| **When productive** | Productive status; inherent-defense implication is rules, not a warning dialog |
| **Actions** | Close; from map flow, path into budget / fleet attach without a second hoop if possible |
| **Controls** | Prefer display labels or read-only scales for 1–10; editable budget uses sliders elsewhere |

**Open (do not invent):** whether livability / power / experience also
**drive the tick** vs remain display-only; exact “related” field list
beyond livability + resources already surfaced.

---

## 3. Map right-click and planet status chrome

Phase I map panel ships (DrawingArea + pointer + ContextMenu). Product
content:

### 3.1 Right-click / context menu — current planet

**Exists** for status, open explored, dispatch toward rock, and
budget (owned). For the clicked or selected planet:

| Item group | Contents |
| --- | --- |
| **Status** | Owner (if known), explored vs quality-unknown, livability/resources 1–10 when known, populated/productive flags, in-range vs out-of-detection as already flagged by server |
| **Actions** | Open explored dialog (if quality known); open budget / allocation; dispatch / attach fleet toward this rock; other menu options per README (“clicks on it and selects menu options”) |
| **Not included** | Dumb-order warnings; invented confirm dialogs for legal-but-stupid sends |

### 3.2 Known-planets zoom list

**Exists (Phase I).** Same context menu submenu: list of **known**
planets the seat can jump/zoom the view to (focus camera on that
rock). “Known” = visibility/driver flags already set — not a second
fog engine. Foreign-owned rocks stay off the map/lists until in
range or seat-discovered (RULES §13 / CPL-107).

### 3.3 Map click (non-menu)

**Exists.** Click hot spot → select and set Fleets dest (README send
path via Dispatch / ContextMenu). In-flight: dotted line
origin→progress; arrival clears line for arrival graphic. Planet color
= status (green settled OK → red taken by other; in-between =
intermediate). Pan/zoom overview ↔ detail. Scroll bars for pan in
addition to mouse pan/zoom.

Map panel pick/pan/zoom/scrollbars; primary pick fills Fleets dest
Entry; ContextMenu status + zoom-to-known + “Dispatch fleet here” /
“Budget this planet”; dotted hop paths when `outboundEta` published.
Dispatch still uses Fleets→Deploy fleet/order/dest/**hulls** +
`PUT /order` (no second order surface). Hulls peels a subset from an
**assigned** sitting fleet so remaining assigned hulls can go
elsewhere. Unassigned stock is not dispatched until create+assign
puts it into a named fleet (CPL-101).

---

## 4. Policy / budget / allocation / agreements

### 4.1 Empire standing policy (panel)

| Field | Control (intended) | Today | Status |
| --- | --- | --- | --- |
| Role (empire-wide) | Entry or dropdown; not dual roles per partner | `GuiChoiceRow` → `Gtk.DropDown` | **Exists** |
| Expansion % | Slider / spin | `SpinButton` (0–100) | **Exists** |
| Escort % | Slider / spin | `SpinButton` (0–100) | **Exists** |
| Agreement size `S` | Slider / spin | `SpinButton` (0–100) | **Exists** — **player–player** `S` |
| Tech bias % | Slider / spin | `SpinButton` (0–100) | **Exists** |
| Apply | Button → PUT `/policy` anytime | Present | **Exists** |

**Flow:** edit anytime; no peer wait; mid-dispatch other policy OK
(that in-flight fleet locked until recall). No warnings for dumb legal
policy.

### 4.2 Planet budget / allocation

**Exists** as Planets panel allocation % Scale → `PUT /budget`.
Production tick applies per-planet **net** income
(`credit − upkeep`, CPL-113) into empire wealth/resources; both
sides scale by `allocationPct/100` (plus `production_tick_rate` /
upkeep rates / cover / AFK; no per-planet logistics tax). Map
ContextMenu “Budget this planet” fills the same Entry/Scale for
owned rocks. Concrete surface:

| Content | Notes |
| --- | --- |
| Per-owned-planet `allocationPct` (0–100) | **Scale**; default **100** = full net-income intensity; empire pools remain sacred (no yard logistics tax) |
| Tick effect | Owned populated habit-complete rock → empire pool **net** × `allocationPct/100` (may debit); **productive** ↔ structural net > 0 (CPL-114) |
| Entry point | Planets root click; map ContextMenu for owned rocks |
| Exact richer knob list | Still **open** under empire-pool model — do not invent logistics |

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
| **Create / assign** | Before first send of new hulls | Create named empty fleet at owned planet; assign type name + qty from **unassigned** stock at that same planet | **Exists (CPL-110)** — Fleets→Create / Fleets→Assign Apply dialogs; over-assign → **error dialog**; unassigned line on Inventory/Assign |
| **Dispatch** | Map click destination or fleet action | Choose hulls from an **assigned** sitting fleet; order (`explore` / `take` / trade cycle / `ambush` / … per RULES); confirm send without warning dialogs; travel rate = slowest hull in fleet | **Exists (CPL-110)** — Fleets→Deploy Apply (fleet / order / dest / **hulls**, `0`=all) → `PUT /order`; map pick sets dest; ContextMenu raises Deploy; reject reason on missing/locked fleet |
| **In-flight lock** | After dispatch | That fleet’s order not editable except **recall**; game keeps running; other policy editable | Rules locked; Deploy lock hint + Recall (**TUNING B**) |
| **Recall** | Player recalls | Same-tick cancel if not departed; else return to **sender** (ETA outbound spent, or 0 if tech teleports) | **Exists (TUNING B)** Deploy Recall → `PUT /recall` |
| **Fleet list** | Fleets→Inventory | Named fleets (assigned ships) + **unassigned** inventory line; select + Examine | **Exists (CPL-110)** |

Do **not** freeze the UI on send. Do **not** allow mid-hop rewrite of
that fleet without recall.

---

## 6. Design / build timing surfaces

**Locked:** designing a type and building hulls take **time** (setup /
ticks) — not instant.

| Surface | Contents | Status |
| --- | --- | --- |
| **Design editor** | Name, speed, hop reach, size, cargo, kind (scout/colony/defense/war); pay development (wealth); show remaining develop ticks; develop is **noop** if same parameters already exist for that seat (silent OK) | **Exists (CPL-110)** Ships→Develop Apply → `PUT /design` (weapons/shields wait on Design fields; size is cost stand-in); noop feedback **CPL-101** |
| **Type inventory** | Rows by type name + specs + **unassigned available** hull count; select + Examine | **Exists (CPL-110)** — Ships→Inventory (not a top-level Inventory product tab) |
| **Yard / build queue** | Produce hulls (resources) at productive shipyard → **unassigned** stock at that yard (not auto-fleet); show build duration remaining; reclaim path at shipyard worlds | **Exists (CPL-110)** Ships→Build Apply → `PUT /build`; Ships→Reclaim → `PUT /reclaim-stock` / `PUT /reclaim-hulls`; build→unassigned **CPL-101** |
| **Progress chrome** | Non-modal progress (label / bar) preferred over modal “wait” dialogs — keeps flow | **Exists (CPL-110)** — develop/build/reclaim ProgressBars in matching Ships dialogs; Deploy **travel** bar from eta/outboundEta; pulse if indeterminate + detail Label |

Enum/id picks use `GuiChoiceRow` (thin `Gtk.DropDown` wrapper);
integer ranges use `Gtk.SpinButton`. Float design fields stay
Entries; digest compose body uses `Gtk.TextView`.
Ships/Fleets submenu dialogs use Apply + Close footers
(`GuiPanelDialog`). Timed develop/build/reclaim use existing
`State.queueDesignDevelop` / `queueYardBuild` / `queueReclaim`.

---

## 7. Newspaper / private messages / known competitors

| Surface | Contents | Status |
| --- | --- | --- |
| **Newspaper / digest panel** | Published tick events + **broadcasts**; read after each tick | **Exists** Digest root-click dialog |
| **Known competitors list** | Names appear after **contact**; no contact → no name | **Exists** (published chrome + Digest list) |
| **Compose private message** | Pick recipient from known competitors; compose body; send | **Exists** (`PUT /message`; seat-scoped digest) |
| **Broadcast compose** | Send-to-all-known via same verb + broadcast flag | **Exists** |

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
**drop** (lost contact). Intentional **`PUT /suspended`** (human AFK
CheckButton; AI status menu while open) holds the seat past
handshake_miss without treating it as a drop; last policy + AFK
shrink still apply. AFK = last policy. v1: **no rejoin / no status
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

### Already in Phase G / TUNING B / Phase I human client

- Main window + File Refresh/Quit + **Planets / Digest / Policy**
  root-click openers + **Fleets / Ships** MenuBar submenus (**CPL-110**)
- **Map canvas** as the main panel: DrawingArea hot spots, status
  colors, dotted hop paths, pick/pan/zoom, Scrollbars, ContextMenu
  status + zoom-to-known + dispatch/budget; pick fills Deploy dest
  (**Phase I + pick-to-dispatch**)
- Non-modal **Planets / Digest / Policy** dialogs; Ships submenu
  Develop/Build/Reclaim/Inventory; Fleets submenu
  Create/Assign/Deploy/Inventory — each Apply+Close (`GuiPanelDialog`)
- Explored-planet TransientWindow (1–10 + populated/productive note);
  manual “Show first explored” + auto-present on quality /
  productive / populated flips (**TUNING B**); map menu open explored
- Policy role **choice row** + % **Scales** + Apply PUT; no
  dumb-order warnings; panel-dialog tooltips
- Planets panel budget Scale → `PUT /budget` (allocationPct; tick
  spend); map ContextMenu budget raises Planets panel for owned rocks
- Digest known-competitors + private/broadcast compose →
  `PUT /message` (seat-scoped digest; recipient choice row)
- TCP pull of seat-scoped publish flags (no second fog)
- Pause CheckButton → `PUT /pause` (one-human sensitive) (**B**)
- Fleets→Deploy Apply / Recall → `PUT /order` / `PUT /recall` with
  in-flight lock labels (**B**); hulls Spin peel for split-dispatch;
  map pick-to-dispatch
- Design/build/reclaim **ProgressBars** + Deploy **travel**
  ProgressBar (**B** + **CPL-72** + **CPL-110**)
- Ships→Develop / Build / Reclaim + Inventory examine
  (`PUT /design`, `/build`, `/reclaim-stock`, `/reclaim-hulls`)
- Fleets→Create / Assign / Inventory examine (**CPL-101** + **CPL-110**)

### Remaining for intended playable human UI

- Richer planet budget knobs once RULES names them (beyond
  allocationPct production fraction)
- Richer design editor (weapons/shields fields) beyond Entries
- Human-visible AFK / drop notices (peer notify still open)
- Full multi-partner agreements UI beyond single `agreementS` stub
### Deferred

- Server setup GUI dialog hierarchy (§10)
- Durable save / rejoin / reclaim dialogs
- Ongoing-map join/sandbox UI (future scenario mode)
- AI client’s “later dialogs” (PLAN H)

### Explicit non-goals

- Warning dialogs for legal-but-stupid orders
- A standalone top-level **Inventory** product tab (Ships→Inventory /
  Fleets→Inventory cover unassigned + fleets — CPL-101 / CPL-110 /
  RULES §16)
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
| [PLAN.md](PLAN.md) §4.G / §4.I | Phase G list debugger; Phase I map panel |
| [CPLANETS.md](CPLANETS.md) | User / operator guide |
