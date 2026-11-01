# CPlanets rules and machine

Working design. The code in this repository is still the SDK starter;
this file is the spec we implement against. The README is flavor and UI
intent. **If they disagree, this document wins.**

CPlanets is loosely inspired by Spaceward Ho! (Delta Tao). It is not a
clone of that game, of Konquest, or of VGA Planets.

Numeric knobs live in a **scenario setup file** (§12), not in code.
This document states *what* happens; the file states *how much*.

Do not warn the player about legal-but-stupid orders (self-trade,
warships outrunning their own traders, unescorted colonies). Let them
figure it out.

## 1. What the game is

The game is a **state machine**. A turn is `tick(state, policies, rng) →
(state, events)`. Players (human or AI) hold a **policy**: allocations,
fleet orders, role, trade agreements. They do not issue tactics inside
the tick. You can leave the machine running on the last policy, come
back, read the event list, and adjust.

The GUI is a **debugger** for that machine. It never ticks. Stand-alone
play is the same machine with AI policies. Online play is the same
machine with a **driver** as the only writer.

## 2. Architecture

| Piece | Job |
| --- | --- |
| Shared library | `State`, `tick`, event log. No GUI, no HTTP. |
| Setup file | Scenario coefficients, locked once a game is in progress. |
| Driver | Load state, apply submitted policies, tick, persist, append events. |
| Store | Serialized universe (SQLite is the intended store). One writer: the driver. |
| Client | GTK (or CLI) as instrumentation. REST later: opaque request bodies. |

REST is how a client talks to the driver. It is not a stdlib REST
framework. **Common file formats are deferred.** Bodies are buffers.
The setup file is application-owned.

New players start in a **partition** of the same machine. Coupling
partitions is a later tick. AFK: last policy is held; turn timeout
shrinks until they return. Clock: **simultaneous turns**.

## 3. State

- **Scenario**: setup coefficients (bumps, weights, identify chance,
  design curves, reclaim percent, capture-use chance, …). Immutable
  after lock.
- **Galaxy**: planets with livability, resources, efficiencies, owner,
  **explored** (per player), **population**, **productive**, **shipyard**,
  parked hulls, **defenses** (e.g. satellites). Quality is **unknown**
  until the rock is **explored or taken**.
- **Player**: wealth, power, experience, technology, **role**, last
  policy, detection/range from tech, **designs**.
- **Design**: speed, range, weapons, shields, size, cargo hold,
  colony/defense flags; development already paid. Speed and range
  feed **development and production cost**, and feed **ETA**.
- **Fleet**: hulls by design, **sender** (dispatch planet), destination
  or ambush midpoint, order, cargo (full hold both ways on trade),
  escorts, ETA, ticks traveled, owner. Pirate loot rides on the
  pirate fleet until it **returns**.
- **Agreement**: pair, standing size `S`, open/closed.
- **Events**: newspaper.

**Homeworld:** already **productive**, with the **first shipyard**
given. A few rocks sit within **scout range**.

Named classes are **default designs** and size bands. Combat uses
actual stats. A shipyard on a non-productive planet cannot **produce**.
Parked hulls and defenses can still **fight**.

## 4. Roles

Roles are coefficients on the same tick.

| Role | Intent |
| --- | --- |
| Neutral | Balanced default. |
| Conqueror | Better take / military conversion. |
| Pirate | May issue `ambush`; poor at worlds/tech. |
| Trader | Better trade profit; weak take. |
| Hermit | Better own-worlds; weak trade and take. |

Role changes are **sticky**. Only pirate (while the role is live) may
`ambush`.

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

## 6. Range, speed, ETA, ambush point

**Range** and **speed** are hull attributes. They affect development
and production cost. **ETA** is distance and speed. A hop cannot
exceed the hull’s **range from an occupied world** of yours (home,
populated possession, or a rock you are sitting on). This replaces
Ho-style fuel; you do not track tanks.

**Ambush** happens at the **middle of the trajectory** (midpoint of
the A–B hop), not at an arbitrary point along the edge. Changing that
is interesting and probably too much complexity.

## 7. Tick order

1. Production on productive planets; shipyard builds.
2. Cancellations (same-tick recall of not-yet-departed orders).
3. Other `recall` (turn toward **sender**; recompute ETA).
4. Decrement ETA / move.
5. **Midpoint ambush** if a fleet is at the middle this tick. Pirate
   **win**: loot is **loaded onto the pirate fleet**; pirate
   **forced `recall`** to **their sender**; maybe identify (§9).
   Loot is **credited when that pirate fleet returns**, not at the
   fight.
6. **Arrivals** at nodes: `trade` cycle, confiscation, `take` /
   occupy, colony populate, sit.
7. Pirate idle timeout → forced `recall` to sender.
8. AFK bookkeeping; partition coupling; events.

## 8. Trade

Standing cycle if both agree on `S`.

### 8.1 Agreement

Pair plus `S`. Both accept. Changing `S` is a new agreement. Do not
clip `S` to “what they can afford.” Holds must **cover `S`** with
enough cargo hulls or the fleet does not leave as a trade of size `S`.

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
2. Ships **arriving from them** at the **victim’s remaining worlds**
   are **confiscated** (hulls + contents), subject to capture-use
   chance (§5.3). They do not trade or bounce.

`take` on a planet they own is attributed.

If the destination **became yours** (you just took it), that arrival
is **self-trade / sit**, not confiscation at your new rock (§8.3).

**Pirate ambush** does not name the attacker by default. Setup-file
**small chance** the **victim only** learns who. Then (1)(2) apply
from that moment, not retroactively. A later named `take` also
identifies.

## 10. Pirates

`ambush` is at the **midpoint**. On a **win vs a trader**, the pirate
fleet **carries 100% of the wealth and resource cargo the sender had
loaded** (full both ways, so direction does not change the hold).
Dispatch already sunk is not transferred.

**Loot is collected when the pirate fleet returns** to its **sender**
from that victory. If the pirate is destroyed before they get home,
the loot does not credit (it was still on the fleet).

After a successful attack: strength reduced (setup, from defender
strength); **forced `recall` to sender**. Idle timeout also recalls
to sender. Recalling pirates are not fully stationed.

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

## 13. Visibility

Detection/range from tech. Unexplored rocks: known to exist in range
or not, **quality unknown** until explore or take. UI is a view of
flags the driver already set.

## 14. Scenario setup and admin

Includes: trade/attack bumps, dispatch weight, pirate attrition,
pirate identify chance, design curves, reclaim percent, **capture-use
probability**, cover, voyage cost, idle *N*, starting scout-range
map. Admin edits before start; **locked** in progress.

## 15. Client and UI (not rules)

Map, hot spots, pan/zoom, colors, dotted lines = ETA + order. Sliders.
No warning dialogs for dumb legal orders. GTK growth: `DrawingArea`,
pointer, `queueDraw`, later `Scale`. No Cwhip GTK subclass framework.

## 16. Open

- Exact combat/production formulas (values are setup fields).
- Role-change cooldown and whether a change is public.
- Agreement player–player vs planet–planet.
- Identify visible to anyone but the victim.
- Win condition.
- Messages / relationships beyond trade.
- Seeded RNG (not `SecureRandom`).
- Setup file syntax.
- Where **stocks** sit (empire pool vs per-planet) for loading,
  cover, and reclaim credit.
- If a pirate carrying loot is themselves ambushed before return.

## 17. Implementation order

1. Library + setup snapshot; CLI N-tick AI.
2. Tests: home yard + scout-range rocks; unowned take no fight;
   undefended owned take; satellites defend after fleet leaves;
   colony required to populate; trade full both ways + escorts
   cycle; self-trade cost only; cargo 100 needs 10×10 holds;
   same-tick recall cancels; recall always to sender then reclaim
   only at yard; pirate loot credited on pirate return; identify
   chance; capture-use roll vs destroy; setup lock.
3. Driver + SQLite.
4. Debugger UI (no dumb-order warnings).
5. REST opaque bodies.
6. `DrawingArea`.
