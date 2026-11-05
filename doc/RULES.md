# CPlanets rules and machine

Working design. The code in this repository is still the SDK starter;
this file is the spec we implement against. The README is flavor and UI
intent. **If they disagree, this document wins.**

CPlanets is loosely inspired by Spaceward Ho! (Delta Tao). It is not a
clone of that game, of Konquest, or of VGA Planets.

Numeric knobs live in a **scenario setup file** (§14), not in code.
This document states *what* happens; the file states *how much*.

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
| Setup file | Scenario coefficients, locked once a game is in progress. |

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
real-time** cadence (period is a setup item; no default magnitude is
locked here). At each tick it snapshots every player’s **current
policy**, advances from the **previous published** state with those
policies, and **publishes** the new state plus a **digest** of events
(newspaper). Between ticks the server may prepare the next step; that
prep is engineering and does not change the published rules of `tick`.
**AFK** = last policy held (player idle / not updating policy, but
**still present**). AFK timeout / shrink units are **real time and/or
tick period** (exact setup field names still thin — §17).

**Presence.** The server distinguishes **AFK** from an **actual drop**
(lost contact / disconnect) with a **handshake**. Missing policy
updates alone do **not** mean drop — that is AFK while the session is
alive. Handshake failure (lost contact) is a drop. Soft vs hard drop
effects beyond this distinction, who is notified, and heartbeat
interval are **not** locked here (§17). AFK vs drop is **live session
contact** only — not a save / rejoin feature (see Session below).

**Session / game instance (v1).** Each game is **stand-alone**. There
is **no durable status save** and **no rejoin** after leave or drop:
the player does not reclaim a seat, and there is no reconnect into a
saved game. While **dropped** during a live game, **last policy
continues** for the remainder of that **live** process until the game
ends (same last-policy spirit as AFK). When that live game / process
ends, participation for that instance is over — start a new
stand-alone game to play again.

**Future (deferred — plan accordingly):** durable status save and
rejoin are expected later. Keep server state **SQLite-shaped** so that
path stays clean. Do **not** implement a save / rejoin API in v1.

**All worlds exist when the game starts.** How many, and the mix of
useful vs poor rocks, is setup. New players may join later into their
**own sandbox** (a partition of that same map). Partitions **do not
couple** until that player **makes contact** by exploration and/or
conquest. Then they compete like everyone else.

**Stocks are an empire pool** (wealth, resources, tech on the player).
Shipping metal to a specific yard to build is interesting and too
much to learn; it is **out**. Loading, cover, production, and reclaim
all hit the same pools.

## 3. State

- **Scenario**: setup coefficients (bumps, weights, identify chance,
  design curves, reclaim percent, capture-use chance, …). Immutable
  after lock.
- **Galaxy**: planets with livability, resources, efficiencies, owner,
  **explored** (per player), **population**, **productive**, **shipyard**,
  parked hulls, **defenses** (e.g. satellites). Quality is **unknown**
  until the rock is **explored or taken**.
- **Player**: empire **wealth** and **resources**, power, experience,
  technology, **role**, last policy, **detection/range** from
  technology (capability-scaled; §13), **designs**, known competitors.
- **Design**: speed, range, weapons, shields, size, cargo hold,
  colony/defense flags; development already paid. Speed and range
  feed **development and production cost**, and feed **ETA**.
- **Fleet**: hulls by design, **sender** (dispatch planet), destination
  or ambush midpoint, order, cargo (full hold both ways on trade),
  escorts, ETA, ticks traveled, owner. Pirate loot rides on the
  pirate fleet until it **returns**.
- **Agreement**: **player–player** pair, standing size `S`, open/closed.
- **Events**: newspaper (including **broadcasts**).
- **Messages**: broadcast, or pick a **known competitor** for a
  private send.

**Homeworld:** already **productive**, with the **first shipyard**
given. At start, only a **few** planets sit within **scout range**.

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
| `take` | Go to a rock. Unowned: occupy without a fight. Owned by another with ships/defenses: combat. War fleets **stay** until moved. |
| `trade` | Cargo (+ escorts) to the far planet and **back**, then cycle. |
| `ambush` | Sit at the **midpoint** of a trajectory. |
| `recall` | Return to the **sender**. Same-tick recall of a not-yet-departed order is **cancellation**. |
| `explore` | Reveal quality of a rock in range (scout). Taking also reveals. |
| sit / move | On a **possession**, a fleet may sit or be given a new destination. |

**Trade fleets cycle. War fleets do not.** After a `take`, warships
stay on that world whether or not it is productive, until the player
moves or recalls them.

Escorts on a **trade** mission are part of that fleet: they go out
**full cargo both ways** with the cargo ships and **return with them**,
then cycle. They are not a `take`.

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
Ships do not teleport. ETA is ticks already spent on the outbound
leg. Dispatch stays sunk. Pirates can still hit a recalling fleet.

**Same-tick recall = cancellation.** Send and recall before the fleet
has left: the order never happens. No dispatch, no loading.

**Reclaim is not mid-space scrap.** Recall brings hulls home. At the
sender they can join a **new fleet** and be sent to a **shipyard
planet** to reclaim. Reclaim is only on a world **that has a shipyard**.
The **percent of production resources** returned is a setup item.
Development wealth is never returned. Destroyed hulls return nothing.

### 5.3 Designs and shipyards

Set parameters (speed, range, weapons, shields, size, cargo, colony,
defense, …) within caps. **Development** once, **mostly wealth**.
**Production** per hull at a productive shipyard, **mostly resources**.
Speed and range raise both costs. Hulls keep their stats until
destroyed or reclaimed. Closing a design does not refund development;
production of it stops.

**Captured hulls:** setup **probability** they can actually be used.
Otherwise they are **destroyed** (Ho default). If usable, they are
interned hulls of that design, not a free development of a new one.

## 6. Range, speed, ETA, stranding, ambush point

**Range** and **speed** are hull attributes. They affect development
and production cost. **ETA** is distance and speed. A hop cannot
exceed the hull’s **range from an occupied world** of yours (home,
populated possession, or a rock you are sitting on).

Ho refuels by **occupying the world where ships are stranded**, and
lets you **reclaim** stranded hulls. This game does **not** require
that occupy-to-save. If a fleet is stranded (cannot hop), after **N
ticks** it can move again. **N is a setup item.** That is the fuel
replacement. Once they can move, they `recall` to sender or proceed;
reclaim is still the usual yard trip, not a special mid-space scrap.

**Ambush** is at the **middle of the trajectory** (midpoint of the
A–B hop). Changing that is probably too much complexity.

## 7. Tick order

Intra-tick sequence below is unchanged by the §2 clock: only **when**
the server calls `tick` changed (real-time cadence), not this order.

1. Production on productive planets; shipyard builds.
2. Cancellations (same-tick recall of not-yet-departed orders).
3. Other `recall` (turn toward **sender**; recompute ETA).
4. Decrement ETA / move.
5. **Midpoint:** if **two pirate** fleets share the point, they
   **war each other**; **passers are unharmed**; winner `recall`s
   home with **almost nothing**. Else if a pirate meets a passer:
   pirate **win** loads loot onto the pirate fleet; forced `recall`
   to sender; maybe identify (§9). Loot **credits when that pirate
   returns**. If a pirate **loses** with loot aboard to a
   **non-pirate**, the **winner** takes the loot (credits on *their*
   return). Two pirates do not stack an ambush on the same edge.
6. **Arrivals** at nodes: `trade` cycle, confiscation, `take` /
   occupy, colony populate, sit.
7. Stranded-tick countdown; pirate idle timeout → forced `recall`
   to sender.
8. AFK; contact (exploration/conquest couples partitions); events.

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

**Identify.** Attacks (including pirate ambush) do not always name the
attacker. There is a setup-tuned chance the **victim** learns where
the attack came from and/or who did it. That chance **rises as the
victim’s relevant attributes increase** (setup curve; not a flat tiny
constant only). Tune so fog remains a **limitation** without making
attribution feel arbitrarily unfair. Default audience of a successful
identify is still **victim-only** (whether others can learn is open —
§17). Then (1)(2) apply from that moment, not retroactively. A later
named `take` also identifies.

## 10. Pirates

`ambush` is at the **midpoint**. On a **win vs a trader**, the pirate
fleet **carries 100% of the wealth and resource cargo the sender had
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

If they have **no ships and no defenses**, the world is **undefended**:
occupy like empty, even if they “own” it. A Ho-shaped play: strip a
rock, leave **defensive satellites**, abandon with no mobile fleet —
the next taker still fights the defenses and spends for little.

If **all ships leave** and there are no defenses, it is undefended.

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
limits the next hop. Scouts see a few rocks from home at start.

## 12. Combat

Shared function for planet defense and midpoint ambush. Inputs: hulls
by design (weapons, shields, size, speed as relevant), tech, role,
planetary defenses. Outputs: winner, surviving hulls by design.
Coefficients in the setup file.

**Weaker hulls die first and screen.** Frigates tend to die;
destroyers without a screen are more vulnerable. Colony hulls do not
screen. Losses are **per design**.

## 13. Visibility, newspaper, messages

**Visibility** is capability-scaled. Detection/range comes from the
player’s **technology**. At start, only a few planets sit in scout
range. **Exploration** reveals rocks already inside that range; it
does **not** extend range. Raising **technology** increases range.
Unexplored rocks: known to exist in range or not, **quality unknown**
until explore or take. Balance visibility as a real **limitation**,
not so harsh that play is frustrating. Setup exposes knobs for
range-from-tech (and related curves).

**Contact** (explore and/or conquest of another partition) adds them
to **known competitors**.

The newspaper / **digest** carries **broadcasts** and the events
published after each tick. To send a **private** message, pick from
the **known competitors** list. No contact, no name on the list.

UI is a view of flags the driver already set.

## 14. Scenario setup and admin

Includes: trade/attack bumps, dispatch weight, pirate attrition,
**identify-from-attributes** chance curve, **tech → detection/range**
curve, design curves, reclaim percent, capture-use probability, cover,
voyage cost, idle *N*, **stranded-ticks N**, **world count**,
**useful vs poor mix**, starting scout-range, **tick period**
(real-time cadence), AFK timeout / shrink (real time and/or tick
period; field names thin — §17), **scenario mode** (v1 default =
**closed**; ongoing = future). Admin edits before start; **locked** in
progress. Future ongoing games would still lock *coefficients*; new
players may join sandboxes without rewriting the map.

## 15. Ending and the ongoing map

**Closed game (v1 default):** the game ends when **one player has
eliminated all others**. “Everyone is in trade agreements” is **not**
a win; it is unsatisfactory. First playable fixture default =
**closed**.

**Ongoing game (future):** the map continues independently of any one
player’s participation. The object is to **own all the worlds**.
Long-lived trade agreements are a good idea, not a victory screen. New
players may join sandboxes until they **contact** others by
exploration and/or conquest. Not the first playable fixture’s default.

## 16. Client and UI (not rules)

Map, hot spots, pan/zoom, colors, dotted lines = ETA + order. Sliders.
Known-competitor list, newspaper, compose-to-pick. No warning dialogs
for dumb legal orders. GTK growth: `DrawingArea`, pointer,
`queueDraw`, later `Scale`. No Cwhip GTK subclass framework.

## 17. Open

- Exact combat/production formulas (values are setup fields).
- Identify audience after success: victim-only (current default) vs
  broader knowledge once identify fires.
- AFK timeout / shrink: exact setup field names and floor (units =
  real time and/or tick period under §2 clock).
- **Presence / drop follow-ups** (handshake AFK≠drop and v1 no-rejoin
  are locked in §2; these details are not):
  - Heartbeat / handshake interval and miss threshold.
  - Whether other humans get a digest event (e.g. `dropped`) — and
    who sees it.
- **Deferred (not v1):** durable status save / rejoin — plan
  accordingly (keep SQLite-shaped); no save / rejoin API in v1.
  v1 reconnect / reclaim is **closed** (no rejoin).
- Pause under the real-time tick (stand-alone / host): preference not
  locked.
- Default tick-period magnitude for v1 feel (beyond setup-tunable):
  not locked.
- AI reaction lag binding (every K ticks / wall time vs digest-gated):
  not locked.
- Livability / power / experience: real tick drivers with setup curves,
  or display/legacy until later — not closed here.
- Setup file syntax.

**Closed (do not re-open without a new decision):** agreement topology
= player–player; visibility/identify = capability-scaled; v1 end =
closed eliminate-all (ongoing = future); clock = server real-time tick
+ digest, policy anytime, AFK = last policy; **handshake distinguishes
AFK vs actual drop** (presence ≠ policy PUT); **v1 session** =
stand-alone game instance, **no status save**, **no rejoin** (drop →
last policy for live remainder only); seeded RNG in `lib` (not
`SecureRandom`) — see [PLAN.md](PLAN.md) §3.

Work order, file shape, tests, and line-count estimates: [PLAN.md](PLAN.md).

## 18. Implementation order

Aligns with [PLAN.md](PLAN.md) §7 (AI before list GTK):

1. Library + setup snapshot; CLI N-tick host.
2. Tests: home yard + scout-range rocks; unowned take no fight;
   undefended owned take; satellites defend after fleet leaves;
   colony required to populate; trade full both ways + escorts
   cycle; self-trade cost only; cargo 100 needs 10×10 holds;
   same-tick recall cancels; recall always to sender then reclaim
   only at yard; pirate loot credited on pirate return; identify
   chance; capture-use roll vs destroy; two pirates at midpoint war
   and passers live; stranded move after N ticks; closed game —
   eliminate all others; contact couples partitions; empire pool
   only; setup lock.
3. Server executable + TCP framed protocol + SQLite (real-time
   cadence; snapshot policies → `tick` → publish state + digest).
4. AI client (own config; same protocol).
5. Human client (GTK list debugger, no dumb-order warnings).
6. Optional HTTP REST façade.
7. `DrawingArea` (when GTK can draw).
