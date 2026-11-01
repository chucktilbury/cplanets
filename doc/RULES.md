# CPlanets rules and machine

Working design. The code in this repository is still the SDK starter;
this file is the spec we implement against. The README is flavor and UI
intent. **If they disagree, this document wins.**

CPlanets is loosely inspired by Spaceward Ho! (Delta Tao). It is not a
clone of that game, of Konquest, or of VGA Planets.

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
| Driver | Load state, apply submitted policies, tick, persist, append events. |
| Store | Serialized universe (SQLite is the intended store). One writer: the driver. |
| Client | GTK (or CLI) as instrumentation. REST later: opaque request bodies. |

REST is how a client talks to the driver (`GET` visible state, `PUT`
policy, `POST` turn, `GET` events). It is not a stdlib “REST framework.”
HTTP framing may come later; **common file formats (JSON, etc.) are
deferred.** Bodies are buffers the application interprets.

New players start in a **partition** of the same machine: same rules, no
other wills yet. Meeting others is a later tick that couples partitions
(open a border / wormhole). Isolation is not a second game.

AFK: last policy is held. Turn timeout shrinks until they return; the
universe keeps ticking.

Clock: **simultaneous turns** — collect policies, then one tick. That
preserves walk-away play. A wall-clock heartbeat is out of scope.

## 3. State

Minimum records:

- **Galaxy**: planets with livability, resources, efficiencies (worlds /
  extraction / tech), owner, visibility per player.
- **Player**: wealth, power, experience, technology, **role**, last
  policy, detection range from tech.
- **Fleet**: hull/class, origin, destination (or edge for ambush), ETA,
  **order**, escrow if any, owner.
- **Agreement**: pair of players (or planets), standing trade size `S`,
  open/closed.
- **Pirate station**: fleet on an edge `(A, B)` with idle-tick counter.
- **Events**: what the newspaper shows after a tick.

Ship classes (defense, scout, freighter, warships, colony) constrain
cost and attribute caps. Cost rises with quality and falls with tech.
Shipyards are a planetary resource that consume resources and wealth.
Exact combat and build formulas are open (see §12).

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

## 5. Fleets and orders

A fleet is **edge-state**, not a picture. Orders:

| Order | Where | On resolution |
| --- | --- | --- |
| `take` | Arrival at a planet | Combat; survivor owns the planet. |
| `trade` | Arrival at the far planet, then return | Escrow / cover / cycle (§7). |
| `ambush` | Occupy edge `(A, B)` | Meet transits on that edge before they reach a node. |
| `recall` | Leave ambush toward a planet | Transit; not full ambush advantage. |

`take` vs `trade` is the same hull, different transition. The client
sets the order; the driver inflicts it.

Several fleets may share a planet pair. They are separate records (can
be out of phase). There is no required `TradeRoute` object: a route is
an agreement plus every fleet whose ends match.

## 6. Tick order

Each tick, in this order:

1. Production and planet budgets (role coefficients apply).
2. Decrement fleet ETAs / move along edges.
3. **Edge encounters** (ambush vs passers). Same combat function as
   `take`, optional first-shot bonus for a stationed pirate.
4. **Arrivals**: `trade` or `take`.
5. Pirate idle timeout → forced `recall` if due.
6. AFK / hold-last-policy bookkeeping.
7. Partition coupling, if any.
8. Append events.

Ships cannot be stopped mid-edge except by combat, recall, or loss.
Fleets do not fight other fleets except on an ambush edge or at a
planet on `take`.

## 7. Trade

Trade is a **standing cycle** of send/receive if both parties agree.
It is not a one-shot wealth bump with no lockup.

### 7.1 Agreement

An agreement is a pair plus a standing size **`S`**. Both sides must
accept `S`. Changing `S` is a new agreement, not a per-trip bid.

The driver only ever moves **`S`**. A fleet on that pair is size `S` or
it does not leave. Do not clip the shipment down to “whatever they can
afford” and show the clipped size — that reveals wealth.

### 7.2 Escrow (sender)

When the fleet **leaves** the sender’s planet, sender wealth `-= S`
(sender must already have `S`; otherwise the fleet waits). That wealth
does not come back until the fleet **returns**, several ticks later
depending on distance.

### 7.3 Cover (receiver)

When the fleet **arrives** at the receiver: if receiver wealth `>= S`,
they cover. They pay at that tick and take the inbound bump (smaller
than the sender’s eventual profit). If they cannot cover, **no
exchange**. The fleet still turns around.

A poor sender cannot escrow `S` and does not leave (receiver sees a
missing arrival, not a balance). A poor receiver fails cover (sender
sees a failed trip, not a balance).

### 7.4 Settlement (sender)

On **return**:

- Filled: wealth `+= S + profit_send`.
- Not filled: wealth `+= S`, optionally minus a small voyage cost.

`profit_send` is a little larger than the receiver’s inbound bump. The
receiver is paid when the ship is at their planet; the sender is paid
when it is home.

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

- Pirate destroys or captures the fleet: sender escrow is gone;
  receiver does not pay if there was no fill. Other fleets on the pair
  keep cycling; the **agreement stays**.
- Recall of a trader: return escrow if there was no fill; after a fill
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

Without an exit, the fleet never re-enters a node (no refit, trade, or
`take`). Use **both**:

- Player may `recall` toward a planet they still own (or origin).
- Idle **timeout**: after *N* ticks with no intercept (or a hunger
  rule), the driver inflicts `recall`. Timeout is a forced order, not
  destruction.

Recalling fleets are still on the edge and can be jumped; they do not
keep full ambush advantage.

## 9. Combat

One function for planet `take` and edge ambush. Inputs: weapons,
shields, tech, role, maybe kill-style weights; output: survivors and
an event. Exact formula is open (§12).

## 10. Visibility

Detection range grows with technology. Planets (and later fleets on
known edges) outside range are unknown. Hover/status in the UI is a
**view** of what the driver already marked visible. Blind or fog
options are policy on the same visibility flags.

## 11. Client and UI (not rules)

The map is a generated graphic with planet hot spots, pan/zoom, color
as a status gradient (e.g. settled vs taken), dotted lines as **ETA +
order** per fleet. Budgets are sliders. Clicks set orders and
agreements. None of that is the machine.

Intended GTK growth (in Cwhip, when we get there): `DrawingArea`,
pointer, `queueDraw`, later `Scale`. Shell widgets already exist.
Do not subclass GTK from Cwhip.

## 12. Open

- Numeric formulas: combat, production, ship cost, `profit_send` vs
  receiver bump, pirate first-shot, voyage cost on empty return.
- Role-change cooldown and whether a change is public.
- Refused `trade` on arrival with no agreement: bounce, wait, or
  convert to `take` — pick one and keep it.
- Whether agreement is player–player or planet–planet.
- Hunger vs idle-tick for pirate timeout; value of *N*.
- Win condition (last owner vs score vs agreed).
- Messages and relationships beyond trade agreements.
- Seeded RNG package (not `SecureRandom`).

## 13. Implementation order

1. Library: state + `tick` + events; CLI “run *N* turns, all AI.”
2. Tests: same seed, hermit vs conqueror diverge; trade escrow round
   trip; failed cover does not leak wealth; pirate timeout recalls.
3. Driver + SQLite, one writer.
4. CLI or GTK list debugger (policy + newspaper).
5. REST with opaque bodies when a second process needs the driver.
6. `DrawingArea` when hot spots and transit lines are the point.
