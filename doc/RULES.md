# CPlanets rules and machine

Working design. The code in this repository is still the SDK starter;
this file is the spec we implement against. The README is flavor and UI
intent. **If they disagree, this document wins.**

CPlanets is loosely inspired by Spaceward Ho! (Delta Tao). It is not a
clone of that game, of Konquest, or of VGA Planets.

Numeric knobs live in the **unified server config file** (§14), not
in code (process/network keys share that file; see operator
`SERVER-CONFIG.md`). This document states *what* happens; the file
states *how much*.

Keep the machine **simple to play**. Do not add logistics the player
has to memorize. Do not warn about legal-but-stupid orders (self-trade,
warships outrunning their own traders, unescorted colonies). Let them
figure it out.

## 1. What the game is

The game is a **state machine**. One step is `tick(state, policies,
rng) → (state, events)`. Players (human or AI) hold a **policy**:
allocations, fleet orders, role, trade agreements. They may update that
policy **whenever they want**; they do not wait for other players. They
do not issue tactics inside the tick. You can leave the machine running
on the last policy, come back, read the digest (events / newspaper), and
adjust.

The GUI is a **debugger** for that machine. It never ticks. Stand-alone
and online use the same **server**; humans and AIs are **clients**.

## 2. Architecture

Three **executables**, one shared library:

| Piece | Job |
| --- | --- |
| Shared library | `State`, `tick`, event log, **message types**. No GUI. |
| **Server** | Only writer: SQLite, apply policies, call `tick`, persist, publish. TCP listener. |
| **Human client** | GTK debugger: show state, edit policy, read digest. |
| **AI client** | Stand-alone process, **same protocol**. Own config (later its own dialogs), not the human settings file. |
| Server config | Process/network + scenario coefficients (§14), locked once a game is in progress. |

Clients **never** tick and **never** open the universe DB.

**Wire (v1):** TCP, **REST-shaped** (verbs + paths + body: `GET` state,
`PUT` policy, `GET` events / digest) **without an HTTP server**. Frame
the messages yourself. On a local network, bodies are **compressed
binary**, not JSON. **Common file formats stay deferred.** Version the
envelope. Policy `PUT` is the primary client write. There is no
all-players-ready barrier; a barrier-style `POST turn` / “turn ready”
is not part of this clock. **Presence** (AFK vs drop) is a separate
handshake / keep-alive from policy `PUT` — no PUT does not mean drop
(see Presence below).

**Later:** a formal HTTP REST façade on the **same commands**. Do not grow a second rule engine to serve the web.

Stand-alone play is still this: start a server, attach a human client
and/or AI clients. In-process AI that bypasses TCP is a test fake only
if it uses the same message types. Stand-alone and online share the
**same server clock**.

**Clock:** the **server** alone calls `tick` on a **configurable
real-time** cadence. **Tick period** is a setup item in **seconds**.
**Provisional** allowed range **for now:** **1–30** seconds
(inclusive); retune min/max after something mostly works. Tick period
**may auto-config from AI reaction lag** (AI lag in part controls how
long a tick feels / how fast the machine runs); it remains
**setup-tunable** — an explicit setup value may still override any
auto-config suggestion. At each tick it snapshots every player’s
**current policy**, advances from the **previous published** state
with those policies, and **publishes** the new state plus a **digest**
of events (newspaper). Between ticks the server may prepare the next
step; that prep is engineering and does not change the published rules
of `tick`. **AFK** = last policy held (player idle / not updating
policy, but **still present**). AFK timeout / shrink units are **real
time and/or tick period** (exact setup field names still thin —
§17).

**Pause.** A pause control is fine only when there is **exactly one
human** player. With **two or more humans**, pause is **not** offered
(the wall clock keeps running).

**Presence.** The server distinguishes **AFK** from an **actual drop**
(lost contact / disconnect) with a **handshake**. Missing policy
updates alone do **not** mean drop — that is AFK while the session is
alive (last policy held; AFK production shrink after timeout when
configured). Handshake failure (lost contact / `handshake_miss`) is a
drop — **unless** the client has set an intentional **suspended**
flag (`PUT /suspended`, body: playerId + flag). While **suspended**
(menu open, marked AFK, or equivalent), the seat stays **connected**
for presence: do **not** apply handshake_miss drop; keep applying
normal AFK rules (last policy + shrink). Clearing suspended resumes
normal miss drop. Soft vs hard drop effects beyond this distinction,
who is notified, and heartbeat interval are **not** locked here
(§17). AFK vs drop is **live session contact** only — not a save /
rejoin feature (see Session below).

**Lobby until go (v1).** One server process, two phases: **lobby**
then **running**. In lobby the server accepts TCP, allocates seats,
issues reconnect tokens, and the operator status menu works, but
**wall ticks do not advance** (injectable `/admin/advance` is also
blocked), **play verbs** (order / build / design / recall / reclaim /
budget) are rejected, and published chrome reports the hold as
**paused** so clients do not treat connect as serve-start. The
operator starts the game with console **`g`+Enter** (banner
`GO_KEY=g`), status-menu **Go**, or harness `PUT /admin/go` — all
share one `go()` path. Later “all humans ready” may call that same
path; **v1 = operator go only** (auto-ready is a stub). After go,
phase is **running** and cadence proceeds as below.

**Seat allocation (v1).** The **server allocates seats** on connect.
Clients must **not** choose `playerId` as seating authority — there
is no way for a client to know a free seat without being told.
Seats **grow on connect**: the live game starts with an empty seat
list and appends a seat when allocate needs one. Config / CLI
`players` is an **optional soft max** of allocated seats (`0` or
unset = unlimited within a practical absolute bound). Soft max also
acts as an **expected-ceiling hint** in the status banner; it does
**not** pre-create seats and does **not** delay operator `go`.
`PUT /handshake` body shapes:
- **empty** — new **human** connect; first **allocated** seat that
  is not connected, not quit, and has **no** outstanding reconnect
  token; otherwise **grow** a new seat when under soft max. Issues
  a fresh opaque **16-byte** token. Rejects only when soft max is
  set and full (or the practical bound is hit).
- **exactly 1 byte (`kind` u8)** — new connect with client kind:
  `0` = human (same as empty), `1` = **AI** (seat marked
  non-human so all-humans-quit ignores it). Same grow / token
  rules as empty allocate.
- **exactly 4 bytes (`playerId` u32)** — **keep-alive only** when
  that seat is already connected; otherwise **reject** (cannot
  steal a dropped / token-held seat).
- **exactly 16 bytes** — **reclaim** (or keep-alive) the seat that
  owns that opaque token.

**Lobby end-status / ghosts.** In lobby the server may age presence
(handshake_miss drop) but **must not** run eliminate-all or
all-humans-quit until after operator `go`. A connecting AI (or a
temporary miss-drop while seating) must not end the process before
the session is running. Lobby miss-drop clears the reconnect token
so the seat is free for re-allocate (no ghost seats from abandoned
clients); after go, drop keeps the token for reclaim. Operator
`go` **retires** lobby-abandoned seats (dropped, no token, not
connected): marks quit (settled; not reusable) but **keeps**
`human=true` so departed humans still count for all-humans-quit.
When another **live** human remains seated, go does not end the
session. When every human is gone (quit/drop/retire), go refreshes
end-status and ends with `all_humans_quit` even if AI seats remain
(no AI-only zombie match). Clearing `human` on retire is forbidden
— that made `humans==0` look like a pure-AI fixture and blocked
exit. Connected seats and token-held reclaimable seats are kept.
Human empty-body allocate restores `human=true` when reusing a free
former AI seat.

Handshake **response** shape: `u8 accepted`, `u32 tick`, `u8 ended`,
`u32 playerId`, **16-byte token**. Human and AI clients store the
token and use `playerId` for all later traffic. Multi-AI sessions do
**not** need distinct config `player_id` values.

**Seat display names (v1).** Every seated empire has a display name
shown in chrome / digest / status. After handshake, clients
`PUT /name` (`playerId` u32 + string). Humans set `display_name` in
the human client config (changeable there). AI clients use config
`display_name` or, when empty, a random proper name from a fixed
pool (Alex, Bethany, …). The server may spawn N AI clients
(`spawn_ai_count` / `spawn_ai_template` / `spawn_ai_dir` /
`spawn_ai_bin`) via Cwhip `process`; each child gets its own config
file and a unique name.

**Reconnect / drop (v1).** Drop frees **presence** (connected=false).
While **running**, the seat remains **reclaimable with its token**
until **quit** or **game end** (simple rule — no wall-clock reclaim
window); empty handshake **cannot** take a token-held seat.
While still in **lobby**, miss-drop / explicit drop **clears** the
reconnect token so the seat is free for a new empty/kind allocate —
abandoned lobby seats must not linger as ghost clients when a
client process restarts without the in-memory token. Keep-alive with
the assigned id refreshes presence only while still connected. This
is **live-process** reclaim, not durable save/rejoin (see Session).

**Session / game instance (v1).** Each game is **stand-alone**. There
is **no durable status save** and **no rejoin** after process end.
While **dropped** during a live game, **last policy continues** for
the remainder of that **live** process until the game ends (same
last-policy spirit as AFK); the dropped seat is reclaimable only
with its token (home stays in place). If **all human players quit**
(leave / drop with no human remaining), the **server registers the
end of the game** — do not leave an AI-only zombie match running as
a live human game. When that live game / process ends, participation
for that instance is over — start a new stand-alone game to play
again.

**Future (deferred — plan accordingly):** durable status save and
rejoin are expected later. Keep server state **SQLite-shaped** so that
path stays clean. Do **not** implement a save / rejoin API in v1.

**All worlds exist when the game starts.** How many, and the mix of
useful vs poor rocks, is setup. **Player home yards are not
pre-seeded** at scenario start: a seat receives its home (productive
yard + unassigned starter scout **stock** at that yard — not a
phantom named fleet; create+assign is the player path)
only when a client **connects and is seated** (handshake). Only
**allocated** seats exist in the players list — soft-max expected
slots that never connected do not count for eliminate-all. Allocated
seats that have not yet received a home (fixtures / rare grant
failure) are **not** eliminated for zero planets. **Drop / AFK /
quit does not destroy** a home once granted — leave it in place (no
casual home teardown; rejoin remains out of v1). New players may
join later into their **own sandbox** (a partition of that same map)
while under soft max. Partitions **do not couple** until that player
**makes contact** by exploration and/or conquest. Then they compete
like everyone else.

**Go and eliminate-all with dynamic seats.** Operator `go` starts
with whatever seats are already allocated — it does not wait for
soft max / expected count. Closed eliminate-all considers only
seats that have been allocated (`players[]`); living =
`homeGranted && !eliminated`. Soft-max slots never taken are not
blockers.

**Stocks are an empire pool** (wealth, resources, tech on the player).
Shipping metal to a specific yard to build is interesting and too
much to learn; it is **out**. Loading, cover, production, and reclaim
all hit the same pools.

**Inventory (empire vs planet).** Empire inventory is the seat’s
abstract stocks and designs (the empire pool above), plus **unassigned
hull stocks** staged at the yard planet that completed each build
(keyed by owner + design + planet). **Planet inventory** is
location-scoped **presence** on that rock — unassigned stocks at that
yard, named sitting fleets, defenses/satellites, yard jobs, population
/ productive / shipyard flags, and allocation — **not** a second
wealth/resource bank and **not** an Inventory screen. Unassigned hulls
are empire stocks at a planet; they are **not** a fleet and have **no
order**. Named fleets are separate containers (create parks an empty
named fleet at an owned planet; assign moves qty of a type from
unassigned stock at that same planet into the fleet). Dispatch leaves
from the fleet’s sitting location, so range-from-occupied-world stays
intact. There is **no** abstract no-location hangar. Builds pay the
empire pool and add to unassigned stock at that yard — they do **not**
auto-fleet. Do not invent ferry-to-yard logistics. (Planet quality
fields below are **rock yield / accessibility**, not empire-style
stockpiles. Spendable stocks stay empire-wide for now; the model
must not block a later per-planet shipping / logistics layer.)

**Planetary resources (CPL-112).** Each rock carries four inherent
quantities — **air**, **water**, **common minerals**, **rare
minerals** — each with an **accessibility** rating (setup-spawned;
1 = easy). Composites for chrome / formulas:

- **Farming / habitability** ≈ air + water. Rich air and water make
  a rock very habitable (farming → empire **wealth** credit).
- **Industry / shipbuilding** ≈ common minerals + rare minerals
  (rare weighted by setup). Mineral quantity drives planet value for
  industry and yard output (empire **resources** credit).
- Rocks may lean **farming-only**, **industry-only**, or **both**
  (both more valuable). Poor rocks are weak on both axes.

**Accessibility.** Low mineral accessibility → more **cost** and
**longer** yard extract / build. Low air/water accessibility → more
**wealth cost** and **longer** to make a colonized rock
**habitable** (`productive`). Magnitudes are setup knobs
(`access_*`, `habit_*`, `rare_mineral_weight`, …). Home yards start
fully accessible and already productive.

**Per-planet net income (CPL-113).** Each **productive** owned rock
applies a **net** into the empire pool each production tick — not a
credit-only bump. Net may be **positive or negative**.

- **Farming → wealth:**  
  `wealth_net = wealth_credit − wealth_upkeep`  
  `wealth_credit = livability × farm_access × cover × production_tick_rate × afk_scale × allocation`  
  `wealth_upkeep = livability × farm_difficulty × wealth_upkeep_tick_rate × cover × afk_scale × allocation`  
  where `farm_access` is mean air/water accessibility (floored by
  `access_floor`) and `farm_difficulty = 1 / max(access, access_floor)`.
- **Industry → resources:** same shape with mineral composite /
  mineral access / `resources_upkeep_tick_rate`.
- Low accessibility therefore **cuts credit and raises upkeep**, so
  hard rocks can be an **ongoing debit**. Easy rocks stay a credit
  when upkeep rates sit below production rate at access ≈ 1.
- `allocationPct` (and AFK / cover) scales **both** sides — throttling
  a rock throttles income intensity, not a logistics tax.
- Upkeep rates of **0** restore credit-only behavior (CPL-112 shape).

**Clamp.** Empire `wealth` / `resources` never go below **0** from
planet upkeep. Planets apply in galaxy index order; a debit that would
overdraw truncates to the remaining stock on that axis (partial drain).
Habit / yard spends use the same floor idea. Stocks stay empire-wide;
this does not invent per-planet banks.

## 3. State

- **Scenario**: setup coefficients / mappings (bumps, weights,
  identify chance, design mappings, reclaim percent, capture-use
  chance, …). Where older notes say **curve**, read **setup-tunable
  mapping / coefficients** — not a required fancy math object.
  Immutable after lock.
- **Galaxy**: planets with air / water / common+rare minerals and
  per-resource accessibility (plus derived farming/industry
  composites), owner, **explored** (per player), **population**,
  **productive**, **shipyard**, parked hulls, **defenses** (e.g.
  satellites), optional habitability countdown after colony.
  Quality is **unknown** until the rock is **explored or taken**.
- **Player**: empire **wealth** and **resources**, power, experience,
  technology, **role**, last policy, **detection/range** from
  technology (capability-scaled; §13), **designs**, known competitors.
- **Design**: speed, range, weapons, shields, size, cargo hold,
  colony/defense flags; development already paid. Speed and range
  feed **development and production cost**, and feed **ETA**
  (technology can further reduce ETA to zero — teleport; §6 / §14).
- **Fleet**: hulls by design, **sender** (dispatch planet), destination
  or ambush midpoint, order, cargo (full hold both ways on trade),
  escorts, ETA, ticks traveled, owner. Pirate loot rides on the
  pirate fleet until it **returns**.
- **Agreement**: **player–player** pair, standing size `S`, open/closed.
- **Events**: newspaper (including **broadcasts**).
- **Messages**: broadcast, or pick a **known competitor** for a
  private send.

**Homeworld:** when the seat is granted (on connect), already
**productive**, with the **first shipyard** given. From that home,
only a **few** planets sit within **scout range**.

Named classes are **default designs** and size bands. Combat uses
actual stats. A shipyard on a non-productive planet cannot **produce**.
Parked hulls and defenses can still **fight**.

## 4. Roles

Roles are **not per-partner**. They are **one** empire-wide stance:
how **you** allocate resources and how **you** get them. They are not
a diplomatic face toward A vs B. You cannot be a trader to A and a
pirate to B. Agreements, ambush, and `take` are separate orders; the
role only retunes the coefficients on the tick.

| Role | Intent |
| --- | --- |
| Neutral | Balanced default. |
| Conqueror | Better take / military conversion. |
| Pirate | May issue `ambush`; poor at worlds/tech. |
| Trader | Better trade profit; weak take. |
| Hermit | Better own-worlds; weak trade and take. |

Role change is **fairly fluid**, with one hard stop: you **cannot
stop being a pirate** while you still have fleets **waiting on
ambush**. Recall or resolve those first. Only pirate (while the role
is live) may `ambush`.

## 5. Fleets, orders, dispatch

| Order | What happens |
| --- | --- |
| `take` | Go to a rock. Unowned: occupy without a fight. Owned by another: combat when ships, defenses, or (if **productive**) inherent planetary defense apply — §11 / §12. War fleets **stay** until moved. |
| `trade` | Cargo (+ escorts) to the far planet and **back**, then cycle. |
| `ambush` | Sit at the **midpoint** of a trajectory. |
| `recall` | Return to the **sender**. Same-tick recall of a not-yet-departed order is **cancellation**. Recall into or out of a fight still subjects those fleets to battle rules (§12). |
| `explore` | Reveal quality of a rock in range (scout). Taking also reveals. |
| sit / move | On a **possession**, a fleet may sit or be given a new destination. |

**Trade fleets cycle. War fleets do not.** After a `take`, warships
stay on that world whether or not it is productive, until the player
moves or recalls them.

Escorts on a **trade** mission are part of that fleet: they go out
**full cargo both ways** with the cargo ships and **return with them**,
then cycle. They are not a `take`.

**Mid-dispatch.** Sending a fleet does **not** pause the game. The
player may still change **other** policy (other fleets, role,
allocations, agreements, …). That **particular in-flight fleet’s
order** cannot be rewritten except by **`recall`** (same-tick cancel
if not yet departed) or resolution that frees it.

**Unassigned inventory + named fleets.** Completed builds add hulls to
**unassigned** stock at the yard planet (owner + design + planet) —
not into a fleet. **Fleet create** parks a named empty container at an
owned planet. **Assign** moves type name + quantity from unassigned
stock at that same planet into the fleet (over-assign → reject / error
dialog; no silent truncate). **Split-dispatch** peels hulls from an
**assigned** sitting fleet onto a new order/destination; the remainder
stays sitting. Dispatch travel rate = **slowest hull** (lowest speed
among assigned types) in that fleet. That is the create / assign /
send loop — not a separate Inventory UI or abstract no-location hangar.

### 5.1 Dispatch and loading (sender only)

When a fleet **actually leaves** (not a cancelled same-tick order):

- **Wealth dispatch** from hull **weight** (design size/flags). Scouts
  almost nothing; colonies more. Sum of the mix. **Sunk.**
- **Trade only:** sender also pays **loading** (wealth cargo + resource
  cargo for `S`). **Only the sender** sees this. Receiver unload/reload
  for the return is **not** a separate cost; it is rolled into the
  **profit bump**. Complexity.

If the sender cannot pay, the fleet does not leave.

**Cargo vs hulls:** `S` is cargo amount. If you want 100 and each hold
is 10, you need **10 cargo hulls**, plus whatever escort you bring.

### 5.2 Recall vs reclaim

**Recall target is always the sender** (the planet that dispatched).
Return **ETA** is ticks already spent on the outbound leg — or
**zero** when technology is high enough that travel teleports
(§6 / §14). Dispatch stays sunk. Pirates can still hit a recalling
fleet.

**Same-tick recall = cancellation.** Send and recall before the fleet
has left: the order never happens. No dispatch, no loading.

**Recall and combat.** Recalling does **not** exempt a fleet from
battle rules. Fleets recalled **out of** an engagement, and fleets
recalled **into** one (heading home to a sender under attack, or
joining while a fight is still open), still **participate** under
§12. A recall wave can **undo a defeat in progress** or **share
defeat** with the side they join — outcome follows comparative
strength over the remaining engagement, not a free escape or free
reinforcement. Exact timing of when a recalling fleet counts as in
the fight is setup / formula open (§17); the principle is locked.

**Reclaim is not mid-space scrap.** Recall brings hulls home. At the
sender they can join a **new fleet** and be sent to a **shipyard
planet** to reclaim. Reclaim is only on a world **that has a shipyard**.
The **percent of production resources** returned is a setup item.
Development wealth is never returned. Destroyed hulls return nothing.

### 5.3 Designs and shipyards

Set parameters (speed, range, weapons, shields, size, cargo, colony,
defense, …) within caps. **Development** once, **mostly wealth**.
**Production** per hull at a productive shipyard, **mostly resources**.
Speed and range raise both costs. **Neither designing a type nor
building hulls is instant** — both take **time** (ticks / setup
durations). Hulls keep their stats until destroyed or reclaimed.
Closing a design does not refund development; production of it stops.

**Develop noop.** If a ship type with the **same parameters** already
exists for that seat, develop is a **no-op** (optional info dialog;
silent noop is OK). **Type names are unique per player.** When **all**
hulls of that name are reclaimed (count → 0 and the design is closed /
name freed), the name may be reused.

**Captured hulls:** setup **probability** they can actually be used.
Otherwise they are **destroyed** (Ho default). If usable, they are
interned hulls of that design, not a free development of a new one.

## 6. Range, speed, ETA, stranding, ambush point

**Range** and **speed** are hull attributes. They affect development
and production cost. **ETA** is distance and speed, further shaped
by the player’s **technology**. At a high enough tech factor
(setup threshold / mapping — §14), travel time drops to **zero**:
the fleet **teleports**. Magnitudes are setup-owned and open until
tuned (§17). A hop cannot exceed the hull’s **range from an
occupied world** of yours (home, populated possession, or a rock
you are sitting on).

Ho refuels by **occupying the world where ships are stranded**, and
lets you **reclaim** stranded hulls. This game does **not** require
that occupy-to-save. If a fleet is stranded (cannot hop), after **N
ticks** it can move again. **N is a setup item.** That is the fuel
replacement. Once they can move, they `recall` to sender or proceed;
reclaim is still the usual yard trip, not a special mid-space scrap.

**Ambush** is at the **middle of the trajectory** (fixed midpoint of
the A–B hop). Changing that geometry is probably too much complexity.
An ambush **cannot happen until the pirate is in position**: the
pirate fleet reaches that midpoint only after traveling **half the
hop ETA** in ticks (example: A→B ETA 10 ⇒ in position after 5 ticks).
Midpoint combat (§7 / §10) fires only then — not before the pirate
has traveled halfway.

## 7. Tick order

Intra-tick sequence below is unchanged by the §2 clock: only **when**
the server calls `tick` changed (real-time cadence), not this order.

1. Production on productive planets (per-planet **net** income into
   empire pools — CPL-113); shipyard builds.
2. Cancellations (same-tick recall of not-yet-departed orders).
3. Other `recall` (turn toward **sender**; recompute ETA).
4. Decrement ETA / move.
5. **Midpoint** (only fleets **in position** — pirate after half hop
   ETA; §6): if **two pirate** fleets share the point, they
   **war each other**; **passers are unharmed**; winner `recall`s
   home with **almost nothing**. Else if a pirate meets a passer:
   pirate **win** loads loot onto the pirate fleet; forced `recall`
   to sender; maybe identify (§9). Loot **credits when that pirate
   returns**. If a pirate **loses** with loot aboard to a
   **non-pirate**, the **winner** takes the loot (credits on *their*
   return). Two pirates do not stack an ambush on the same edge.
   Midpoint fights use the same multi-tick combat machine as planet
   defense (§12) when duration is not instant.
6. **Arrivals** at nodes: `trade` cycle, confiscation, `take` /
   occupy (may **open** or **join** an engagement — §11 / §12),
   colony populate, sit.
7. **Ongoing combat:** each open engagement advances one tick of
   resolution by **comparative strength** (§12) until it ends.
   Recalls into/out of the fight still count under battle rules.
8. Stranded-tick countdown; pirate idle timeout → forced `recall`
   to sender.
9. AFK; contact (exploration/conquest couples partitions); events.

## 8. Trade

Standing cycle if both agree on `S`.

### 8.1 Agreement

An agreement is between two **players** (empires), not two planets. It
is the pair plus standing size `S`. Both players accept. Changing `S`
is a new agreement. Do not clip `S` to “what they can afford.” Holds
must **cover `S`** with enough cargo hulls or the fleet does not leave
as a trade of size `S`.

### 8.2 Cargo both ways

A cargo ship is **full both ways**. Escorts return with it. Sender
paid loading on leave. Receiver handling is in the **profit bump**
only.

On arrival at the far planet, if they can cover `S`, exchange
happens (receiver inbound wealth bump, smaller than sender return
profit). If not, no exchange; fleet still turns around, still full
for the purpose of pirate loot.

On return to **sender**, if filled: sender **wealth profit** (trade
bump). **No resource profit** beyond the hold that went out and comes
back as a full cargo ship (capacity unchanged as a yield mechanic).
If not filled: restore as per setup (voyage cost optional). Dispatch
never refunded. Then the **cycle** repeats (pay dispatch/loading
again) until recalled, agreement closed, or the hulls are reassigned.

Poor sender: does not leave. Poor receiver: failed trip, same event
shape as other no-deals (**no wealth probe**).

### 8.3 Self-trade and other dumb ideas

Sending a trade mission to **your own possession** is **cost-only**:
you pay dispatch and loading, you do not get a two-party bump. Same
family as taking a world and “trading” with it, or sending a **faster
war fleet** that arrives (or fights) ahead of your own traders. Legal.
**No warning.**

### 8.4 Breaks

- Pirate fight: cargo stays with whoever the combat says; pirate
  credits loot **on return to their sender** (§10). Agreement stays
  unless identified (§9).
- Recall: back to **sender**; cycle stops for that fleet; loading
  restores if no fill yet (and not cancelled).
- Closed agreement: in-flight traders finish moving; exchange stops
  unless confiscation applies.
- Role off `trader`: finish hop or fail exchange; do not keep printing
  as a conqueror.

## 9. Attack while trading

If a player **attacks** a trade partner and the attack is
**attributed**:

1. Agreement **ends**.
2. Ships arriving from that **player** at the **victim’s remaining
   worlds** are **confiscated** (hulls + contents), subject to
   capture-use chance (§5.3). They do not trade or bounce.

`take` on a planet they own is attributed.

If the destination **became yours** (you just took it), that arrival
is **self-trade / sit**, not confiscation at your new rock (§8.3).

**Identify** (jargon): learning **who** is on the other side of an
attack — the attacker discovering their target’s identity, and/or the
defender discovering where the attack came from and/or who did it.
Attacks (including pirate ambush) do not always name either side.

**Asymmetry (locked direction):** the **attacker** should have an
**advantage** discovering who they are attacking. The **defender**
should still have a **fair chance** of discovering the attacker as
well. Those are **separate setup-tunable parameters** (attacker-side
identify knobs vs defender-side identify knobs) — do not collapse them
into one chance. Each side’s chance may still **rise with that side’s
relevant attributes** (setup mappings / coefficients; not a flat tiny
constant only). Tune so fog remains a **limitation** without making
attribution feel arbitrarily unfair; do **not** invent magnitudes
here. Default audience of a successful **defender** identify is still
**victim-only** (whether others can learn is open — §17). Then (1)(2)
apply from that moment, not retroactively. A later named `take` also
identifies.

## 10. Pirates

`ambush` is at the **midpoint**. An ambush **cannot fire** until the
pirate fleet is **in position** there — after traveling **half the hop
ETA** in ticks (§6). On a **win vs a trader**, the pirate fleet
**carries 100% of the wealth and resource cargo the sender had
loaded** (full both ways, so direction does not change the hold).
Dispatch already sunk is not transferred.

**Loot is collected when the pirate fleet returns** to its **sender**
from that victory.

**Two pirates on the same midpoint** do not both rob traffic. They
**fight each other**. Ships passing through are **unharmed**. The
winner goes home with **almost nothing** (setup leftover).

If a pirate **loses** a fight while carrying loot to a **non-pirate**
winner, that winner carries the loot and credits it on **their**
return to sender. That is not the two-pirate case.

After a successful robbery: strength reduced (setup); **forced
`recall` to sender**. Idle timeout also recalls. Recalling pirates
are not fully stationed.

## 11. Taking, occupying, defending, colony

### 11.1 Unowned

**Unowned rocks are taken without a fight.** The fleet occupies. Quality
becomes known. The rock is a **possession** you can sit on or leave.
It is **not populated** and **not productive** until a **colony**
survives there. A **new take** can only be populated by a **colony**.

### 11.2 Owned by another

If they have **ships or defenses** (satellites, parked hulls) on it,
those **defend**. Combat as §12. Attacker loses: fleet gone, dispatch
sunk. Defender wins: attack bump (wealth/resources from attacker
size), productivity loss, tech bump if attacker tech was higher.

**Productive planets always defend.** A **productive** owned world has
**inherent planetary defensive capability** even with **zero parked
fleet** and no satellite layer yet. Taking a productive planet is
**never free** — the attacker always fights that baseline (plus any
ships/satellites present). Magnitude is a setup coefficient (§14);
do not treat “empty productive” as occupy-like-empty.

**Undefended owned (non-productive only).** If the rock is **owned**
but **not productive**, and they have **no ships and no defenses**,
the world is **undefended**: occupy like empty. A Ho-shaped play:
strip a rock, leave **defensive satellites**, abandon with no mobile
fleet — the next taker still fights the defenses and spends for
little. If **all ships leave** a **non-productive** possession and
there are no defenses, it is undefended. That strip-and-empty path
does **not** make a **productive** world free to take.

### 11.3 Colony

Populate only if a **colony hull survives** (same arrival or a later
one). Colonies are **weakly defended** and **expensive**; they will
almost certainly be **escorted**. Escort warships on a colonize/`take`
are a war fleet: they **stay** unless moved.

A fleet sent to a **possession** may **sit or move**. Sitting does not
populate. Only a colony does.

**Unpopulated ⇒ not productive ⇒ no ship production.** Home is the
exception already productive with a yard.

### 11.4 Range hops

From an occupied world (including sitting on a new take), hull **range**
limits the next hop. Scouts see a few rocks from home once the seat
home is granted.

## 12. Combat

Shared function for planet defense and midpoint ambush. Inputs: hulls
by design (weapons, shields, size, speed as relevant), tech, role,
planetary defenses (including a productive world’s **inherent**
baseline — §11.2). Outputs: winner, surviving hulls by design, and
whether the engagement is still **open**. Coefficients in the setup
file.

**Multi-tick engagements.** Battles may span **more than one tick**.
An engagement stays open across ticks until resolved by **comparative
strength over time** — not a mandatory one-shot resolution on the
arrival tick. Duration is driven by how the fleets (and planetary
defense) **compare in strength**: a large gap may collapse the fight
in **zero or one** tick; a closer fight lasts longer. Exact mapping
from strength gap → ticks (and whether “0/1” is a hard short-circuit)
is **setup / formula open** (§17); the principle is locked.

**Recall into / out of a fight.** Fleets under `recall` still fight
under these rules (§5.2). Example shape (illustrative, not a
scripted sequence): send a fleet → get attacked → recall all fleets
→ take a defeat in progress → **recalled fleets can undo that defeat
or also be defeated** according to the same comparative-strength
resolution. No free escape by recalling mid-fight; no free win by
recalling in — only what battle rules grant.

**Weaker hulls die first and screen.** Frigates tend to die;
destroyers without a screen are more vulnerable. Colony hulls do not
screen. Losses are **per design**. Per-tick attrition rates and the
closed-form strength function remain open (§17).

## 13. Visibility, newspaper, messages

**Visibility** is capability-scaled. Detection/range comes from the
player’s **technology**. Once a seat home is granted, only a few
planets sit in scout range. **Exploration** reveals rocks already inside that range; it
does **not** extend range. Raising **technology** increases range.
Unexplored rocks: known to exist in range or not, **quality unknown**
until explore or take. Balance visibility as a real **limitation**,
not so harsh that play is frustrating. Setup exposes knobs for
range-from-tech (and related mappings / coefficients).

**Foreign-owned rocks stay hidden** until they are **in detection
range** of a world you own, or **discovered** by you (explore or
take — per-player explored). Another seat’s home or colony is not
globally visible just because its quality is known to its owner.
Discovery persists: a rock you explored remains visible (and
quality-known) to you even if it later leaves range. Map, planet
lists, and seat digest are views of these driver-set flags — not a
second client fog engine.

**Planet quality display (farming / industry / resources):** once a
rock is **explored** (or taken — quality becomes known **to that
player**), surface farming and industry composites plus air, water,
common/rare minerals and each accessibility rating to the human on
a **standard 1–10 scale** (enough granularity to be useful, not
burdensome). Exact numeric mapping from internal values → 1–10 is
setup-owned; do not invent magnitudes here. Farming / industry
composites **do** drive production credit (CPL-112); whether power /
experience also **drive the tick** (vs display) remains open (§17).
Human UI: explored rock **pops a dialog**; that dialog **may
change** as the planet becomes **populated** and **productive**
(§16).

**Contact** (explore and/or conquest of another partition) adds them
to **known competitors**.

The newspaper / **digest** carries **broadcasts** and the events
published after each tick, **seat-scoped** so fog-hidden foreign
rocks and other seats’ private actions do not appear. To send a
**private** message, pick from the **known competitors** list. No
contact, no name on the list.

UI is a view of flags the driver already set.

## 14. Scenario setup and admin

**Combat, production, and other tunable parameters live outside
code** — in the unified **server config** file (coefficients /
mappings; same document as process/network keys), not hard-coded
magnitudes. Expect **many** named knobs; anticipate lots of
post-complete tuning. Includes: trade/attack bumps, dispatch weight,
pirate attrition, **identify attacker-side** and **identify
defender-side** chance mappings (separate knobs; §9 asymmetry),
**tech → detection/range** mapping, design mappings / coefficients,
**design-development duration** and **yard-build duration** (ticks;
neither is instant), reclaim percent, capture-use probability, cover,
voyage cost, idle *N*, **stranded-ticks N**, **world count**,
**useful vs poor mix**, starting scout-range, **tick period**
(real-time cadence in **seconds**; provisional allowed range **for
now:** **1–30**; **may auto-config from AI reaction lag**, still
setup-tunable — §2), **AI reaction lag** (and any auto-link to tick
period), AFK timeout / shrink (real time and/or tick period; field
names thin — §17), **scenario mode** (v1 default = **closed**;
ongoing = future), **battle-duration / comparative-strength
coefficients** (how strength gap maps to engagement length;
magnitudes open — §17), **productive-planet inherent defense**
coefficient (baseline defense with zero parked fleet; take never
free), **livability (and related) → 1–10 display** mapping. Where
older notes say **curve**, read **setup-tunable mapping /
coefficients** — not a required fancy math object. Admin edits before
start; **locked** in progress. Future ongoing games would still lock
*coefficients*; new players may join sandboxes without rewriting the
map. **Future (plan accordingly, not v1):** a **server setup GUI**
with a **dialog hierarchy** for editing these knobs — keep the setup
surface organized so that path stays clean; do not ship that GUI in
v1 unless PLAN already schedules it.

## 15. Ending and the ongoing map

**Closed game (v1 default):** the game ends when **one player has
eliminated all others**. “Everyone is in trade agreements” is **not**
a win; it is unsatisfactory. First playable fixture default =
**closed**. Dropped / AFK last-policy seats (“zombies”) should lose
to **normal gameplay** in ordinary games (rare survivals OK); it must
**not** be possible to arrange a zombie that **wins consistently**.
If **all human players quit**, the **server registers the end of the
game** (§2 Session).

**Ongoing game (future):** the map continues independently of any one
player’s participation. The object is to **own all the worlds**.
Long-lived trade agreements are a good idea, not a victory screen. New
players may join sandboxes until they **contact** others by
exploration and/or conquest. Not the first playable fixture’s default.

## 16. Client and UI (not rules)

Map, hot spots, pan/zoom, colors, dotted lines = ETA + order. Sliders.
Known-competitor list, newspaper, compose-to-pick. No warning dialogs
for dumb legal orders. Human client uses Cwhip `DrawingArea`, pointer,
`queueDraw`, Scrollbars, and ContextMenu for the map panel; `Scale`
adoption for policy knobs is still open. No Cwhip GTK subclass
framework.

**No standalone Inventory product tab.** Ships→Inventory and
Fleets→Inventory submenu dialogs show type inventory (specs +
unassigned hull counts), named fleets with assigned ships, and a
separate **unassigned** line — that is the ship inventory chrome
(§2 / §5 / CPL-110 / CPL-111). Fleets→Inventory is **per planet**
with multi-select Assign / Un-assign (no separate Fleets→Assign
menu). **Empire** is a top-level dialog for empire-pool + presence
overview. Do not add a top-level Inventory product tab.

**Explored planet dialog (human client):** when a planet has been
**explored** for that human, **pop up a dialog** showing quality /
livability and related fields on the **1–10** display scale (§13).
That dialog **may change** as the planet becomes **populated** and
**productive** (same rock, richer / different content — not a second
rules engine). AI clients use their own config path; they do not need
this human dialog.

## 17. Open

- Exact combat/production formulas (values are setup fields), including
  the closed-form strength function, per-tick attrition, and the
  strength-gap → duration mapping (0/1-tick short fights allowed in
  principle; no magnitude locked). Principle that combat/production
  knobs live **outside code** (§14) is locked.
- When a recalling fleet counts as fully in an open engagement
  (arrival tick vs partial participation): thin until a formula pass.
- Identify **magnitudes** and mapping shapes for the separate
  attacker-side / defender-side knobs (§9 asymmetry direction locked;
  values open). Identify **audience** after a successful defender
  identify: victim-only (current default) vs broader knowledge.
- AFK timeout / shrink: exact setup field names and floor (units =
  real time and/or tick period under §2 clock).
- **Presence / drop follow-ups** (handshake AFK≠drop, intentional
  `PUT /suspended` hold, and v1 no-rejoin are locked in §2; these
  details are not):
  - Heartbeat / handshake interval and miss threshold.
  - Whether other humans get a digest event (e.g. `dropped`) — and
    who sees it.
- **Deferred (not v1):** durable status save / rejoin — plan
  accordingly (keep SQLite-shaped); no save / rejoin API in v1.
  live-process token reclaim is in; durable save/rejoin still deferred.
- Exact default tick period **inside** the provisional 1–30s band for
  the first fixture (setup choice; band itself is locked in §2 / §14).
  Auto-config-from-AI-lag **direction** is locked (§2); the exact
  auto-config mapping is open.
- AI reaction lag **binding shape** (every K ticks / wall time vs
  digest-gated) and numeric lag defaults: still thin; direction that
  lag **may** drive tick auto-config is locked (§2 / §14).
- Livability / power / experience as **tick drivers** (vs display):
  still open. **Display** side is locked: explored → human dialog;
  **1–10** scale; dialog may change when populated/productive
  (§13 / §16).
- Setup file syntax.
- Tech → teleport mapping shape (step vs continuous) and magnitudes
  when ETA hits zero.
- Odd-ETA / ETA-0 ambush edge cases (rounding / whether ambush can
  fire).
- **Deferred (not v1 unless PLAN schedules it):** server **setup GUI
  dialog hierarchy** for the many §14 knobs — plan accordingly
  (§14).

**Closed (do not re-open without a new decision):** agreement topology
= player–player; visibility/identify = capability-scaled with
**identify asymmetry** (attacker advantage + defender fair chance +
**separate** setup knobs); v1 end = closed eliminate-all (ongoing =
future); clock = server real-time tick + digest, policy anytime, AFK
= last policy; intentional **`PUT /suspended`** holds past
handshake_miss (still AFK rules); **pause only with exactly one
human**; **tick period**
= setup **seconds**, provisional **1–30**, **may auto-config from AI
lag**, still **setup-tunable**; **all humans quit → server ends the
game**; zombies fall to **normal play** (no consistent zombie-win
path); **home yards spawn on seat connect** (not pre-seeded; drop
leaves home in place); **server allocates seats on handshake**
(clients do not claim `playerId`; seats grow on connect; `players`
is soft max / expected hint, not a hard fixed array; opaque
reconnect token reclaim); **lobby until operator go** (no ticks
until `g` / Go / `/admin/go`; go uses whatever seats are seated);

mid-dispatch: other policy OK, that fleet
locked until recall; design/build take time (setup/ticks);
combat/production/other tunables live in **setup outside code**;
explored planet **human dialog** on **1–10** livability/quality scale
(may change when populated / productive); seeded RNG in `lib` (not
`SecureRandom`) — see [PLAN.md](PLAN.md) §3; **combat spans ticks**
with duration from **comparative strength**; **recall into/out of a
fight still under battle rules** (can reverse or share defeat);
**productive planets have inherent defense** (take never free) —
magnitudes remain setup/open above.

Work order, file shape, tests, and line-count estimates: [PLAN.md](PLAN.md).

## 18. Implementation order

Aligns with [PLAN.md](PLAN.md) §7 (AI before list GTK):

1. Library + setup snapshot; CLI N-tick host.
2. Tests: home yard + scout-range rocks; unowned take no fight;
   undefended owned **non-productive** take; productive owned
   (even zero fleet) never free; satellites defend after fleet
   leaves; multi-tick engagement advances until strength resolves;
   recall into/out of fight still under battle rules; colony
   required to populate; trade full both ways + escorts cycle;
   self-trade cost only; cargo 100 needs 10×10 holds; same-tick
   recall cancels; recall always to sender then reclaim only at
   yard; pirate loot credited on pirate return; identify chance;
   capture-use roll vs destroy; two pirates at midpoint war and
   passers live; stranded move after N ticks; closed game —
   eliminate all others; contact couples partitions; empire pool
   only; setup lock.
3. Server executable + TCP framed protocol + SQLite (real-time
   cadence; snapshot policies → `tick` → publish state + digest).
4. AI client (own config; same protocol).
5. Human client (GTK list debugger, no dumb-order warnings).
6. Optional HTTP REST façade.
7. Map canvas (`DrawingArea` panel — Phase I).
