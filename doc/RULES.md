# CPlanets rules and machine

Working design. The code in this repository is still the SDK starter;
this file is the spec we implement against. The README is flavor and UI
intent. **If they disagree, this document wins.**

CPlanets is loosely inspired by Spaceward Ho! (Delta Tao). It is not a
clone of that game, of Konquest, or of VGA Planets.

Numeric knobs (trade bump, attack bump, pirate strength loss, and the
rest) live in a **scenario setup file** (§12), not in code. This document
states *what* happens; the file states *how much*.

## 1. What the game is

The game is a **state machine**. A turn is `tick(state, policies, rng) →
(state, events)`. Players (human or AI) hold a **policy**: allocations,
fleet orders, role, trade agreements. They do not issue tactics inside
the tick. You can leave the machine running on the last policy, come
back, read the event list, and adjust.

The GUI is a **debugger** for that machine: show allowed state, edit
policy, step or run-ahead. It never ticks. Stand-alone play is the same
machine with AI policies. Online play is the same machine with a
**driver** as the only writer.

Winning or losing against AIs is whether that trajectory stays above
the others, plus noise from the seeded RNG.

## 2. Architecture

| Piece | Job |
| --- | --- |
| Shared library | `State`, `tick`, event log. No GUI, no HTTP. |
| Setup file | Scenario coefficients, locked once a game is in progress. |
| Driver | Load state, apply submitted policies, tick, persist, append events. |
| Store | Serialized universe (SQLite is the intended store). One writer: the driver. |
| Client | GTK (or CLI) as instrumentation. REST later: opaque request bodies. |

REST is how a client talks to the driver (`GET` visible state, `PUT`
policy, `POST` turn, `GET` events). It is not a stdlib “REST framework.”
HTTP framing may come later; **common file formats (JSON, etc.) are
deferred.** Bodies are buffers the application interprets. The setup
file is a scenario document the driver loads; it is not a stdlib format
package.

New players start in a **partition** of the same machine: same rules, no
other wills yet. Meeting others is a later tick that couples partitions
(open a border / wormhole). Isolation is not a second game.

AFK: last policy is held. Turn timeout shrinks until they return; the
universe keeps ticking.

Clock: **simultaneous turns** — collect policies, then one tick. That
preserves walk-away play. A wall-clock heartbeat is out of scope.

## 3. State

Minimum records:

- **Scenario**: coefficients from the setup file (trade bump, attack
  bump, pirate attrition, dispatch **weight** per class, …). Immutable
  after lock.
- **Galaxy**: planets with livability, resources, efficiencies, owner,
  **population**, **productive** flag, visibility per player.
- **Player**: wealth, power, experience, technology, **role**, last
  policy, detection range from tech.
- **Fleet**: hull count and class mix, origin, destination (or edge for
  ambush), ETA, **order**, **cargo** (wealth and resources sent, if
  any), owner.
- **Agreement**: pair of players (or planets), standing trade size `S`,
  open/closed.
- **Pirate station**: fleet on an edge `(A, B)` with idle-tick counter.
- **Events**: what the newspaper shows after a tick.

Ship classes (defense, scout, freighter, frigate, destroyer, cruiser,
carrier, colony) constrain cost, caps, and **who dies first in a
fight** (§10). Cost rises with quality and falls with tech. Shipyards
are a planetary resource that consume resources and wealth. A shipyard
on a non-productive planet cannot produce ships (§9).

## 4. Roles

Roles are **coefficients** on the same tick: how wealth turns into
worlds, extraction, and technology.

| Role | Intent |
| --- | --- |
| Neutral | Balanced default. |
| Conqueror | Better take / military conversion. |
| Pirate | May issue `ambush`; poor at worlds/tech. |
| Trader | Better trade profit; weak take. |
| Hermit | Better own-worlds; weak trade and take. |

Role changes must be **sticky** (cooldown, reputation, or delayed
reveal). Changing at will every tick would make everyone a pirate in
combat and a trader on the wealth step.

Only pirate (while the role is live) may `ambush`. A role flip this tick
does not place fleets on every lane.

## 5. Fleets, orders, and dispatch cost

A fleet is **edge-state**, not a picture. Orders:

| Order | Where | On resolution |
| --- | --- | --- |
| `take` | Arrival at a planet | Combat. Ownership may change; population is separate (§9). |
| `trade` | Arrival at the far planet, then return | Cargo / cover / cycle (§7). |
| `ambush` | Occupy edge `(A, B)` | Meet transits on that edge before they reach a node. |
| `recall` | Leave ambush toward a planet | Transit; not full ambush advantage. |

`take` vs `trade` is the same hull, different transition. The client
sets the order; the driver inflicts it.

Several fleets may share a planet pair. They are separate records (can
be out of phase). There is no required `TradeRoute` object: a route is
an agreement plus every fleet whose ends match.

### 5.1 Dispatch cost (every fleet)

When a fleet **leaves**, the sender pays a **wealth cost based on hull
weight**, not head-count. Each class has a weight in the setup file.
**Scouts cost almost nothing. Colony ships cost more.** Frigates,
destroyers, and heavier hulls sit on that same ladder. Fleet dispatch
is the sum of per-hull weights in the mix.

That cost is **sunk**. It is not cargo, not refunded on arrival, and
not restored if the fleet is destroyed.

A trade fleet pays that weighted wealth cost **plus** a **resource
cost** and additional **wealth cargo** (§7). Other orders pay weighted
hull wealth only, unless a later rule adds cargo.

If the sender cannot pay dispatch (and trade cargo, if any), the fleet
does not leave.

## 6. Tick order

Each tick, in this order:

1. Production on **productive** planets (role coefficients apply).
2. Decrement fleet ETAs / move along edges.
3. **Edge encounters** (ambush vs passers). On a pirate **win**: loot
   (§8), reduce pirate strength from the defender, **forced `recall`**.
4. **Arrivals**: `trade` or `take` (including colony population).
5. Pirate idle timeout → forced `recall` if due (skipped if already
   recalling from a win this tick).
6. AFK / hold-last-policy bookkeeping.
7. Partition coupling, if any.
8. Append events.

Ships cannot be stopped mid-edge except by combat, recall, or loss.
Fleets do not fight other fleets except on an ambush edge or at a
planet on `take`.

## 7. Trade

Trade is a **standing cycle** of send/receive if both parties agree.

### 7.1 Agreement

An agreement is a pair plus a standing size **`S`**. Both sides must
accept `S`. Changing `S` is a new agreement, not a per-trip bid.

The driver only ever moves **`S`**. A fleet on that pair is size `S` or
it does not leave. Do not clip the shipment down to “whatever they can
afford” and show the clipped size — that reveals wealth.

`S` scales how much **wealth cargo** and **resource cargo** are loaded
(coefficients in the setup file). Hull dispatch cost is separate and
always sunk.

### 7.2 Leave (sender)

When the fleet leaves:

1. Pay **hull wealth** dispatch (§5.1). Sunk.
2. Load **wealth cargo** and **resource cargo** for size `S`. Those
   amounts leave the sender’s stocks and sit on the fleet. Sender must
   cover both plus dispatch, or the fleet waits.

Sender wealth and resources stay down until resolution. Distance is
ETA.

### 7.3 Cover (receiver)

When the fleet **arrives** at the receiver: if the receiver can cover
the agreed `S` (wealth and any cover the setup file requires), the
exchange happens. The receiver takes the inbound **wealth** bump from
the setup file (smaller than the sender’s return profit). If they
cannot cover, **no exchange**. The fleet still turns around.

A poor sender cannot load `S` and does not leave (receiver sees a
missing arrival, not a balance). A poor receiver fails cover (sender
sees a failed trip, not a balance).

### 7.4 Return (sender)

On **return**, if the trip was filled: sender receives a **wealth
profit** (setup **trade bump**, larger than the receiver’s inbound
bump). There is **no resource profit**. The ship’s capacity has not
changed; the trip does not grow the resource stockpile beyond bringing
the hold home empty of extra yield.

If the trip was not filled: restore wealth cargo (optionally minus a
voyage cost from the setup file); still no resource profit.

Hull dispatch is never refunded.

### 7.5 No wealth probe

The sender must not discover the receiver’s wealth by offering a large
trade. Therefore:

- Amount is only the agreed `S`, never an arbitrary per-trip offer.
- Failed cover, closed lane, and similar failures use the **same**
  event shape for the sender (“round trip, no deal”), never
  “insufficient funds: 41.”
- One failed trip at agreed `S` may leak a single bit (“couldn’t cover
  `S` this time”). A ladder of probe sizes is forbidden.

### 7.6 Breaks

- Pirate takes the fleet: see §8. Other fleets on the pair keep
  cycling; the **agreement stays**.
- Recall of a trader: restore cargo if there was no fill; after a fill
  at the far planet the receiver bump already happened and the sender
  is still waiting on the residual.
- Role off `trader`: do not keep printing wealth as a conqueror.
  Either the exchange check fails or they finish the current hop and
  stop.
- Closed agreement: in-flight traders keep moving; **exchange** stops
  until both open it again.

## 8. Pirates

`ambush` parks a fleet on **one** edge, not the whole galaxy. Anyone
whose transit uses that edge this tick meets them before the node.

### 8.1 Loot (trader)

If a pirate **wins** against a **trader**, the pirate receives **100%
of the wealth cargo and resource cargo the sender had loaded**, whether
the fight is on the way **there** or on the way **back**. Direction
does not change the loot table. Hull dispatch already sunk by the
sender is not transferred (it was never on the ship).

The sender’s cargo is gone. If there was no fill yet, the receiver
never pays cover.

### 8.2 Attrition and return

After a **successful** attack (any ambush win, trader or otherwise):

- Pirate fleet **strength is reduced** by an amount from the setup
  file based on the **defender’s strength**.
- The pirate fleet **always `recall`s**. Success does not leave them
  on the edge.

Idle **timeout** still exists for uneventful waits: after *N* ticks
with no intercept, the driver inflicts `recall`. Timeout is a forced
order, not destruction. The player may `recall` earlier toward a
planet they still own (or origin).

Recalling fleets are still on the edge and can be jumped; they do not
keep full ambush advantage.

## 9. Taking planets

`take` is combat at a planet. Winning the fight is **not** the same as
having a working world.

### 9.1 Colony and production

- After a successful `take`, the attacker **owns** the planet.
- The planet is **populated on that same arrival** only if at least
  one **colony hull survives** the fight.
- Colony ships are **weakly defended**. They tend to die in battle even
  when the fleet wins, so a same-turn colonize is a gamble. The usual
  play is a follow-up colony after the shooting stops.
- If no colony survives (or none was sent), the world stays
  unpopulated until a later colony arrival.
- **Unpopulated ⇒ not productive.**
- **Not productive ⇒ no ship production** (shipyard idle). Other
  production that requires population is also off.
- A planet does not become productive from ownership or from parking
  warships.

### 9.2 Attacker loses

The attacker **loses the fleet** and the **dispatch cost** already
paid. Nothing is refunded.

### 9.3 Defender wins

The successful defender:

- Receives **resources and wealth** based on attacker size (setup
  **attack bump**).
- Loses **some planet productivity** (setup).
- If the attacker’s **tech is higher**, the defender also receives a
  **tech bump** (setup).

## 10. Combat

Planet `take` and edge ambush share a combat function. Inputs: hulls
**by class**, weapons, shields, tech, role, strengths. Outputs: winner,
**surviving hulls by class**, events. Coefficients (including pirate
attrition, attack bump, and per-class toughness) come from the setup
file. Exact functional form is open (§14).

### 10.1 Mixed fleets

A fleet is not one strength number. **Weaker hulls tend to die first;
stronger hulls without a screen take more of the hit.**

- A **frigate** is weaker than a **destroyer** and tends to die in
  battle.
- Without frigates (or other screens), **destroyers are more
  vulnerable**. Heavier ships need lighter ships in front of them.
- **Colony** hulls are among the weakest in a fight (§9.1). They do
  not screen warships; they are cargo you hope is still there after
  the shooting.

That mix is the interesting decision: cheap screens vs massed heavies
vs bringing a colony into the assault. Combat must allocate losses
**per class**, not as a single stack scaled down. Setup-file weights
say how much a screen actually protects the next class; the rule is
that a homogeneous heavy fleet is worse than the same tonnage with a
screen.

## 11. Visibility

Detection range grows with technology. Planets (and later fleets on
known edges) outside range are unknown. Hover/status in the UI is a
**view** of what the driver already marked visible. Blind or fog
options are policy on the same visibility flags.

## 12. Scenario setup file and admin

Trade bump, attack bump, dispatch weight per class, pirate attrition, cover
rules, voyage cost, idle *N*, and other magnitudes are set in a
**setup file before the game starts**.

The GUI scenario has a designated **admin** who can read and edit that
file. Other players cannot. When a game is **in progress**, the file
is **locked**: the driver refuses edits; the admin UI is read-only.
Unlock is starting a new game (or an explicit abort that ends the
current one), not a mid-game tweak.

The tick reads coefficients from the locked snapshot, not from a live
editable buffer.

## 13. Client and UI (not rules)

The map is a generated graphic with planet hot spots, pan/zoom, color
as a status gradient (e.g. settled vs taken), dotted lines as **ETA +
order** per fleet. Budgets are sliders. Clicks set orders and
agreements. Admin-only controls open the setup file before lock.
None of that is the machine.

Intended GTK growth (in Cwhip, when we get there): `DrawingArea`,
pointer, `queueDraw`, later `Scale`. Shell widgets already exist.
Do not subclass GTK from Cwhip.

## 14. Open

- Functional form of combat, production, ship cost, bumps, and pirate
  attrition (values themselves are setup-file fields).
- Role-change cooldown and whether a change is public.
- Refused `trade` on arrival with no agreement: bounce, wait, or
  convert to `take` — pick one and keep it.
- Whether agreement is player–player or planet–planet.
- Hunger vs idle-tick for pirate timeout; default *N* in the setup
  file.
- Win condition (last owner vs score vs agreed).
- Messages and relationships beyond trade agreements.
- Seeded RNG package (not `SecureRandom`).
- Setup file syntax (application-owned until common formats exist).

## 15. Implementation order

1. Library: state + `tick` + events; load a setup snapshot; CLI “run
   *N* turns, all AI.”
2. Tests: same seed, hermit vs conqueror diverge; trade cargo round
   trip (wealth profit, no resource profit); failed cover does not
   leak wealth; pirate win loots 100% cargo and recalls; failed take
   pays defender bump; surviving colony on a winning `take` populates,
   dead colony does not; screened destroyers lose fewer hulls than the
   same destroyers alone; setup file rejected while locked.
3. Driver + SQLite, one writer.
4. CLI or GTK list debugger (policy + newspaper + admin setup).
5. REST with opaque bodies when a second process needs the driver.
6. `DrawingArea` when hot spots and transit lines are the point.
