# Cwhip GTK feature gaps for Cplanets

Inventory of GTK capabilities Cplanets still needs from the Cwhip `gtk`
package (`0.1.0`), vs what already ships. Sources checked (2026-11-06):

- Cplanets `origin/main` @ `84faa24`: `doc/RULES.md` §16/§14,
  `doc/PLAN.md` §4.G–I, `doc/CPLANETS.md`, `README.md` UI section,
  `src/client/` (Phase G list debugger).
- Cwhip GTK (`cwhip` @ `2556e7e`) and installed SDK
  `gtk/0.1.0`: `gtk.cw`, `native/gtk.c` widget kinds, `doc/GTK.md`.
- Project design notes that informed this inventory: design-decisions
  §11/§16/§18, project-context, and product preferences (panel embed,
  map pick/pan/zoom + scroll bars, ContextMenu hooks, sliders,
  config-driven setup UI deferred).

Cwhip documents itself as **not** a complete GTK binding. Gaps below are
only those Cplanets realistically needs for the human (and later
server-setup) UI — not a wishlist of every GTK widget.

Priority legend:

| Tag | Meaning |
| --- | --- |
| **playable** | Needed for a human UI that matches the intended game loop (beyond the Phase G list debugger) |
| **map** | Blocks PLAN Phase I map canvas |
| **config** | Needed for nested / setup dialog hierarchy (future server setup GUI; plan accordingly) |
| **polish** | Improves UX; workarounds exist with current widgets |

---

## 1. Executive summary

**Phase G (list GTK debugger) is not blocked** by missing Cwhip GTK
widgets. It already runs on what ships today: `Application`, `Window`,
`Notebook`, `Box`, `Label`, `Entry`, `Button`, `MenuBar`,
`ScrolledWindow`, `TransientWindow`, `schedule`.

**What blocks the intended game UI (README / RULES §16 / Phase I):**

1. **Custom drawing in a client panel** — no `DrawingArea`, no
   `queueDraw`, no public Cairo/GSK draw primitives. Without these
   there is no planet-grid graphic, no fleet ETA dotted lines, no
   status colors, no pan/zoom canvas. The canvas must be embeddable
   in the existing client layout (a panel), not a bare window-only
   surface.
2. **Pointer / gesture input + view chrome on that canvas** — no
   click-at-(x,y), drag, or scroll-wheel events exposed to Cwhip.
   Hot-spot planet pick, mouse pan/zoom, scrollbar-driven pan, and
   right-click context-menu hooks (planet status + zoom-to known
   planet) cannot be wired. `ContextMenu` already exists; what is
   missing is DrawingArea ownership, click coords, and
   app-supplied menu content.
3. **Sliders (`Gtk.Scale`)** — RULES §16 and README say settings are
   generally controlled with sliders; policy / budget / 1–10 displays
   currently fall back to `Entry` text. Not required to keep the list
   debugger alive, but required for the intended playable controls.

**Nice-to-have / deferred (not Phase I blockers):**

- **Config-file-driven nested multi-panel UI** — imperative nesting
  (`Box` / `Grid` / `Paned` / `Notebook`) exists; there is **no**
  GtkBuilder-style / declarative layout loader. Needed when building
  the **future server setup GUI dialog hierarchy** (design-decisions
  §16; RULES §14 deferred, not v1). Also useful if Cplanets wants
  human UI chrome defined outside code.
- Structured lists (`Tree` exists but is editor/directory-oriented;
  game uses scrolled `Label` blobs), `DropDown` / `SpinButton`,
  plain `TextView` for compose/newspaper, `Frame` / `Expander` /
  `Separator` for dense setup trees. `ProgressBar` landed in Cwhip
  (CPL-71) and is wired in Cplanets Ships/Fleets develop/build
  chrome (CPL-72).

**PLAN note:** Phase I map canvas is implemented in Cplanets on the
installed DrawingArea + pointer + Scrollbar/ContextMenu APIs
(`PLAN.md` §4.I). Remaining map polish: dash/text paint helpers.
Pause, explored dialog, and digest already have client/server hooks.

---

## 2. Already available in Cwhip GTK (brief)

Present in both source and installed SDK `gtk` 0.1.0 — sufficient for
the current list debugger and many dialog shells:

| Area | APIs |
| --- | --- |
| App / timing | `Application` (`run`, `quit`, `shutdown`, `post`, `schedule`, `cancel`) |
| Windows | `Window`, `TransientWindow` (explored-planet dialog) |
| Containers | `Box`, `Grid`, `ScrolledWindow`, `Notebook`, `Paned` |
| Controls | `Label`, `Button`, `Entry`, `CheckButton`, `Scrollbar`, `Scale`, `ProgressBar`, `DrawingArea` |
| Menus | `MenuBar`, `ContextMenu` (item / check / submenu / separator) |
| Lists (editor-shaped) | `Tree`, `DirectoryScan` |
| Dialogs | `FileDialog` (open/save/multi/folder), `AlertDialog` |
| Misc | `Clipboard`, `Keyboard`, `Font`, CSS class add/remove, tooltips, expand, width request, shortcuts, maximize |
| Settings text | `Gtk.Config` — **TOML validate/merge/save** for app settings models, **not** a UI layout loader |
| Optional | `sourceview` package (cedit/cdbg; Cplanets does not need it) |

`doc/GTK.md` explicitly lists as **not implemented**: styling depth,
broad dialog/model coverage, **drawing**, **input events**, arbitrary
native-widget adoption, file-open/CLI activation, broad property
coverage. No general custom-widget subclass framework.

Widget create kinds in `native/gtk.c` today: Window (1), Box (2),
Label (3), Button (4), Entry (5), CheckButton (6), ScrolledWindow (7),
SourceView (8), Notebook (9), MenuBar (10), TransientWindow (11),
Paned (12), Tree/ListView (13), Grid (14), ContextMenu (15). **No**
DrawingArea / Scale kinds.

---

## 3. Required gaps (by area)

### 3.1 Custom drawing / generated graphics — **map** (also **playable**)

| Need | Cplanets use | GTK / Cwhip name | Priority |
| --- | --- | --- | --- |
| Drawing surface **in a panel** | Planet grid canvas embedded in the client layout (Notebook / Paned / Box child), **not** a bare window-only canvas | `Gtk.DrawingArea` as a normal child widget (missing) | **map** / **playable** |
| Invalidate / redraw | Tick digest → refresh map, fleet paths | `queueDraw` / `queue_draw` on the area (missing; RULES §16 names it) | **map** |
| Draw callback | Paint map each frame | `DrawingArea.setDrawFunc` / snapshot or Cairo paint hook into Cwhip (missing) | **map** |
| 2D primitives | Stars/planets, dashed hop lines, status colors, arrival markers | Cairo or GSK path API: fill/stroke circle/rect/line, dash, color, text at point (missing as public Cwhip API) | **map** |
| Offscreen / surface (optional) | Pre-render static galaxy layer; composite fleets | `Gdk.Texture` / Cairo surface helpers (missing; can defer if draw-func is fast enough) | **polish** |

README / RULES §16 intent: computer-generated planet grid; hot spots;
dotted line = in-transit ETA + order; arrival graphic; green→red
status colors; pan/zoom. Phase G explicitly avoids this
(`guiMain.cw` / `CPLANETS.md`: no DrawingArea).

**Panel embedding (required):** Cwhip must allow a DrawingArea to be
placed like any other widget inside the existing client chrome
(`Notebook` page, `Paned`/`Box` child, etc.). A standalone
Window-that-is-only-a-canvas is not enough for the intended UI.

### 3.2 Pointer and canvas interaction — **map**

Required UX (user-refined): **pick**, **pan**, and **zoom** with the
mouse; **scroll bars** for the view (pan/scroll via scrollbar UI in
addition to mouse pan/zoom); **right-click context menu hooks** for
the clicked/selected planet (status items) and a list of known
planets to zoom/jump to.

| Need | Cplanets use | GTK / Cwhip name | Priority |
| --- | --- | --- | --- |
| Click with coordinates (pick) | Select planet hot spot; click-to-dispatch; feed context menu | Gesture click / `GtkGestureClick` → `void<fp64,fp64>` (or pixel ints) on DrawingArea (missing; only Button press exists, no coords) | **map** |
| Drag (pan) | Pan the field with the mouse | `GtkGestureDrag` / motion controllers (missing) | **map** |
| Scroll / wheel (zoom) | Zoom overview ↔ detail with the mouse | Scroll controller / zoom gesture (missing) | **map** |
| Scroll bars for the view | Pan/scroll via scrollbar UI **in addition to** mouse pan/zoom | See scrollbar note below — required hooks, not optional polish | **map** |
| Right-click / context menu hooks | Status items for current (clicked/selected) planet; list of **known planets** that can be zoomed/jumped to (focus view on that planet) | `ContextMenu` **exists** (item / check / submenu / separator) but needs DrawingArea as owner + click coords + **app-supplied menu content** (partial → required gap is the wiring) | **map** / **playable** |
| Cursor / hit-test helpers (optional) | Hand vs pointer over hot spots | Cursor name API; optional hover motion (missing) | **polish** |

**Scrollbar support Cwhip must enable for this UX** (document for
implementers; either path — or both — is acceptable as long as the
client can scroll the map view with visible bars):

1. **`ScrolledWindow` around DrawingArea** — if the canvas (or an
   oversized content child) has a natural size larger than the
   viewport, stock scrollbars pan the view. Requires DrawingArea (or
   a sized wrapper) to participate correctly as a `ScrolledWindow`
   child (min/natural size, or explicit content size API).
2. **and/or custom scrollbars tied to pan/zoom extents** — when zoom
   is a client-side transform (content size stays fixed, draw
   applies scale/offset), stock `ScrolledWindow` alone is not enough.
   Cwhip must then expose range + value get/set (e.g. `Gtk.Scrollbar`
   / `Gtk.Adjustment`, or equivalent) so Cplanets can drive
   horizontal/vertical bars from current pan/zoom and update the
   view when the user moves a bar.

Either mechanism is fine; Cwhip work should not assume mouse-only
pan. Scrollbar UI is a **required** map interaction path.

**ContextMenu (required hooks, not a new menu system):** `ContextMenu`
already ships for widgets. For the map, Cwhip must support:

- attaching / popping a `ContextMenu` owned by (or positioned for) the
  DrawingArea at the right-click coordinates;
- delivering those coordinates (and preferably which button) to the
  app so Cplanets can hit-test the planet;
- letting the **app supply menu content** each time (planet status
  items for the current selection; entries that jump/zoom the view to
  a known planet). Cwhip does not invent that content — it provides
  the popup + activation callbacks.

RULES §16: “GTK growth: `DrawingArea`, pointer, `queueDraw`, later
`Scale`.”

### 3.3 Sliders and numeric controls — **playable** (user callout)

| Need | Cplanets use | GTK / Cwhip name | Priority |
| --- | --- | --- | --- |
| Horizontal / vertical slider | Standing policy knobs (expansion %, escort %, tech bias, agreement S); planet budget / allocation; any continuous setting | `Gtk.Scale` (`GtkScale`) + value-changed signal (missing) | **playable** |
| Integer range with marks | Livability **1–10** display / edit if UI becomes interactive; tick-period 1–30; discrete bands | `Scale` with marks / digits, or `Gtk.SpinButton` (both missing) | **playable** / **config** |
| Read/write value | Sync slider ↔ policy draft ↔ PUT | `getValue` / `setValue` / range / step (missing) | **playable** |

Current workaround: `Entry` strings on the Policy tab
(`guiMain.cw`). Explored dialog shows 1–10 as **text** in a `Label`
(`guiPlanetDialog.cw`) — display works; slider is the intended control
shape per README (“Settings are in general controlled with sliders”).

### 3.4 Nested multi-panel layouts + config-file-driven UI — **config** (user callout)

| Need | Cplanets use | GTK / Cwhip name | Priority |
| --- | --- | --- | --- |
| Imperative nested panels | Map + side lists + digest; split views | **Available:** `Box`, `Grid`, `Paned`, `Notebook` | (have) |
| Declarative / config-driven UI tree | Future **server setup GUI dialog hierarchy** over many §14 knobs; optional human chrome from a file | No `GtkBuilder` / `.ui` loader; no “build widget tree from TOML/JSON” API. `Gtk.Config` is settings TOML only | **config** |
| Nested dialog / notebook of sections | Combat / production / identify / travel / AI-lag groups | `Notebook` + `TransientWindow` available; hierarchy **authored in code** today | **config** (structure OK; data-driven build missing) |
| Tree of categories → editors | Admin browses knob groups | `Tree` exists but is directory/list oriented; no form-builder binding | **config** |
| Persist UI layout (split positions, open pages) | Remember paned sizes / notebook page | App can store ints via `Gtk.Config` or game `.cfg`; no auto layout restore | **polish** |

Locked product note (design-decisions §16): knobs live outside code;
**server setup GUI dialog hierarchy is future / plan accordingly,
not v1**. Still a real Cwhip gap before that UI can be data-driven
rather than a huge hand-built widget tree.

### 3.5 Dialogs, lists, and game chrome — **playable** / **polish**

| Need | Cplanets use | GTK / Cwhip name | Priority |
| --- | --- | --- | --- |
| Explored-planet dialog | RULES §13/§16: pop on explore; 1–10; may change when populated/productive | **Available:** `TransientWindow` + labels (Phase G done) | (have) |
| Richer planet inspector | Budget menus, allocations, fleet attach | Needs `Scale` + menus; optional `Expander`/`Frame` (missing) | **playable** |
| Structured planet / fleet lists | Replace scrolled label blobs; activate row → dialog | Prefer `ListBox` / column view, or leaner game-oriented `Tree` activate with selection signal clarity | **polish** (**playable** UX) |
| Known-competitor list + compose-to-pick | RULES §13/§16 newspaper / private message | List + `Entry`/`TextView` for compose; `DropDown` or list pick (DropDown / plain TextView missing) | **playable** |
| Digest / newspaper pane | Already a notebook page of text | Label works; multiline `TextView` (non-SourceView) nicer for long digests | **polish** |
| Pause control | One-human-only pause (RULES §2; server `PUT /pause`) | **Available:** `CheckButton` / `Button` + `setSensitive` — client wiring, not a GTK gap | (have) |
| Role / enum pickers | Policy role name | `DropDown` / `ComboBox`-style (missing; Entry workaround) | **polish** |
| Alerts | Connection errors | **Available:** `AlertDialog` | (have) |
| File chooser | Open scenario / human config | **Available:** `FileDialog` | (have; optional for client) |
| Top-level menubar leaf action | Click Planets/Fleets/… root to raise a panel (no nested Open) | `GtkPopoverMenuBar` only accepts **submenus** as top-level GMenu entries. Cplanets workaround: flat `Button`s beside `MenuBar`. Optional Cwhip `MenuBar.addAction(label, action)` would generalize that | **polish** (workaround ships) |

### 3.6 Theming / CSS — **polish**

| Need | Cplanets use | Notes | Priority |
| --- | --- | --- | --- |
| Per-widget CSS classes | Status colors on chrome (not map pixels) | `addCssClass` / `removeCssClass` **available** | (have) |
| Load stylesheet | Game look without hard-coded colors in every label | No `CssProvider` / load-from-file API exposed | **polish** |
| Map colors | Green→red planet status | Belongs in draw API, not CSS | **map** |

### 3.7 Explicitly *not* required from Cwhip for Cplanets

- `GtkSourceView` / editor whitespace / indent APIs (cedit/cdbg).
- Directory project explorer (`DirectoryScan` richness).
- Full GTK subclass framework (RULES §16: “No Cwhip GTK subclass
  framework” — stay with provided widgets + draw callback).
- Clipboard (available; game does not depend on it).
- Keyboard chord recorder (available; optional shortcuts only).

---

## 4. Explicit coverage of the three user callouts

### 4.1 Slider controls

**Status:** missing end-to-end.

- Need `Gtk.Scale` (or equivalent) with range, step, get/set value,
  and a value-changed callback into Cwhip.
- Cplanets targets: policy percentages, agreement size, planet budget
  / allocation, any continuous setup knob in a future setup GUI;
  discrete 1–10 livability affordances.
- Phase G workaround: `Gtk.Entry` numeric text — acceptable for the
  list debugger, not the intended control language.

### 4.2 Multiple nested panels driven from a config file

**Status:** nesting **yes** (imperative); config-driven build **no**.

- Have: `Box` / `Grid` / `Paned` / `Notebook` / `TransientWindow` for
  arbitrary nested panels in code (Phase G uses Notebook pages).
- Missing: load a panel/dialog hierarchy from a config (`.ui`, TOML
  widget tree, or similar). `Gtk.Config` does **not** fill this —
  it is TOML settings persistence for cedit-style apps.
- Primary consumer: deferred **server setup GUI dialog hierarchy**
  over many §14 knobs. Secondary: optional human client chrome
  defined outside `.cw` sources.

### 4.3 Generated / procedural graphics (+ map interaction)

**Status:** missing; hard gate for Phase I.

- Need DrawingArea **as a panel child** + redraw + draw primitives +
  coordinate input (not a bare window-only canvas).
- Required interaction on that canvas:
  - mouse **pick**, **pan**, and **zoom**;
  - **scroll bars** for the view (see §3.2 — `ScrolledWindow` and/or
    custom bars tied to pan/zoom extents);
  - **right-click context menu hooks**: `ContextMenu` exists; Cwhip
    must wire DrawingArea owner + click coords + app-built menus
    (planet status for the clicked/selected planet; zoom/jump to
    known planets).
- Content to generate in-client from published state (not assets):
  galaxy positions, visibility fog, planet hot spots, status colors,
  in-flight dotted paths with progress, post-arrival markers,
  pan/zoom transforms.
- No image/sprite pipeline required for v1 map if vector draw is
  enough; optional texture/surface comes later.

---

## 5. Adjacent needs (only if Cplanets realistically needs them)

| Item | Verdict |
| --- | --- |
| Events / timers | **Have** `schedule` / `post` / `cancel` — enough for digest poll and `--test` auto-quit; reschedule for periodic refresh |
| Custom draw | **Missing** — see §3.1 (core) |
| CSS / theming load | Optional polish — class toggles exist |
| Clipboard | Available; not required for play |
| File chooser | Available; useful for scenario/config pick |
| Height request | Only `setWidthRequest` today — minor layout polish |
| Plain multiline text | Nice for compose / digest; SourceView is overkill |
| SpinButton / DropDown | Prefer with Scale for numeric/enum policy |
| ProgressBar | **Landed** in Cwhip (CPL-71) and wired in Cplanets Ships/Fleets develop/build chrome (CPL-72: fraction / text / pulse) |
| Frame / Expander / Separator (widget) | Help dense setup dialogs; menu separators already exist |
| Drag-and-drop between widgets | Not required by rules |
| OpenGL / video | Not required |
| Accessibility beyond GTK defaults | Not specified |

---

## 6. Suggested implementation order (Cwhip GTK work)

Ordered for Cplanets dependency, smallest useful increments first:

1. **`DrawingArea` + `queueDraw` + draw callback**, embeddable as a
   **panel child** in `Box` / `Paned` / `Notebook` (not window-only).  
   Minimal paint (clear + circles). Unblocks canvas scaffolding in
   Cplanets Phase I.

2. **Draw primitives** (stroke/fill path, color, dash, text)  
   Enough for planet dots, dotted fleet lines, status colors.

3. **Pointer input on DrawingArea** (pick / click coords → drag pan →
   wheel zoom)  
   Enables hot spots, mouse pan, mouse zoom.

4. **View scroll bars + DrawingArea `ContextMenu` hooks** (required
   with map interaction, not polish)  
   - Scroll bars: `ScrolledWindow` integration and/or
     Adjustment/`Scrollbar` APIs tied to pan/zoom extents (§3.2).  
   - Context menu: owner + right-click coords + app-supplied items
     (planet status; zoom-to known planet). `ContextMenu` widget
     already exists — finish the DrawingArea wiring.

5. **`Scale` (slider) + value-changed**  
   Replaces Entry-based policy/budget controls; feeds explored 1–10
   UX and future setup knobs. (“Later `Scale`” in RULES §16 can move
   earlier if policy UX is prioritized before full map polish.)

6. **`SpinButton` and/or `DropDown`**  
   Integer ranges and role/enum picks without free-text Entries.

7. **Config-driven / declarative panel builder**  
   Before investing in a large server setup GUI: load nested
   Notebook/Paned/Grid trees + bound Scale/Entry fields from a file.
   Keep `Gtk.Config` for settings; add a separate layout API.

8. **List / text polish**  
   Game-friendly selectable lists; plain `TextView` for digest/compose;
   `Frame`/`Expander` for setup sections; optional CSS provider.

9. **Optional surfaces / textures**  
   Only if redraw cost forces a static galaxy layer.

**Cplanets sequencing reminder:** keep Phase G list debugger on current
bindings; implement I (map) only after steps 1–4 land in an installed
SDK (draw + mouse pick/pan/zoom + scrollbars + context-menu hooks);
grow sliders into the human client as step 5 lands; defer
config-driven setup GUI until knobs stabilize (RULES §14 / design
§16).

---

## 7. Source cross-check (quick)

| Claim | Evidence |
| --- | --- |
| No DrawingArea / Scale today | `gtk.cw` class list; `gtk.c` create `case` 1–15; `GTK.md` “drawing, input events … not implemented” |
| Phase I gated on DrawingArea | `PLAN.md` §4.I; `CPLANETS.md`; client file headers |
| Sliders / map / dotted ETA / colors | `README.md` UI; `RULES.md` §16 |
| Explored 1–10 dialog done without Scale | `guiPlanetDialog.cw`; design-decisions §18 |
| Setup GUI dialog hierarchy deferred | design-decisions §16; RULES §14/§17 |
| `Gtk.Config` ≠ UI layout | `GTK.md` Config section |
| Pause not a GTK gap | `CheckButton`/`Button` exist; server `PUT /pause` already tested |

---

This document is the Cplanets-side inventory of Cwhip GTK dependencies
for the intended human UI and Phase I map canvas. It does not change
Cwhip or Cplanets code by itself; implementers should grow the
installed `gtk` package (and then Phase I) from the order in §6.
