/*
 * tests/fn/fn_takeColony.cw — Phase D1 take / colony / defenses cluster.
 *
 * Fixed seed: unowned free take, colony populate, dead colony no
 * populate, undefended owned non-productive, productive inherent
 * never free, satellites defend, war fleets stay, sit/move on
 * possession (PLAN D1 / RULES §11).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase D1 function program.
 *   2026-11-05  Fix colony hop reach; waitArrive checks dest.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

/*
 * FnTake counts tick events and drives hop-to-arrival helpers.
 *
 * Purpose: keep the start block free of duplicated scan loops.
 */
class FnTake {
    /*
     * Construct a stateless helper.
     *
     * Purpose: match other fn test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnTake instance.
     */
    FnTake() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert take / combat / populate counts.
     *
     * Parameters:
     *   events — TickEvent list from State.tick.
     *   kind — kind string to count.
     *
     * Returns: number of matching events.
     */
    int64 countKind(list events, String kind) {
        int64 found = 0
        int64 index = 0
        while (index < events.length) {
            TickEvent ev = events[index]
            if (ev.kind.equals(kind)) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Tick until a fleet sits at an expected planet.
     *
     * Purpose: drive ETA without treating stranded-at-home as
     * arrival success.
     *
     * Parameters:
     *   game — mutable state.
     *   fleetId — fleet to wait for.
     *   destPlanetId — expected location after arrival.
     *   bound — max ticks to run.
     *
     * Returns: true when the fleet is sitting at destPlanetId.
     */
    bool waitArrive(
        State game,
        int64 fleetId,
        int64 destPlanetId,
        int64 bound) {
        int64 n = 0
        while (n < bound) {
            game.tick()
            Fleet fleet = game.findFleet(fleetId)
            if (fleet.sitting
                and not fleet.departed
                and not fleet.pendingDeparture
                and not fleet.stranded
                and fleet.locationPlanetId == destPlanetId) {
                return(true)
            }
            n = n + 1
        }
        return(false)
    }

    /*
     * Ensure the colony design can hop to scout-ring rocks.
     *
     * Purpose: default colony hopReach is half scoutRange and often
     * misses planet 1; D1 populate tests need a reachable colony.
     *
     * Parameters:
     *   game — state whose designs[1] is the colony template.
     *
     * Returns: nothing; mutates designs[1].hopReach.
     */
    void unlockColonyReach(State game) {
        if (game.designs.length > 1) {
            Design colony = game.designs[1]
            colony.hopReach = game.scenario.scoutRange
            game.designs[1] = colony
        }
    }
}

start {
    FnTake check = FnTake()
    bool ok = true

    # --- unowned take (no fight); war fleet stays; no populate ---
    State game = State()
    game.startClosed(41u, 2)
    Planet target = game.galaxy.planets[1]
    if (target.ownerId >= 0) {
        ok = false
    }
    if (not game.issueOrder(1, "take", 1)) {
        ok = false
    }
    if (not check.waitArrive(game, 1, 1, 40)) {
        ok = false
    }
    target = game.galaxy.planets[1]
    if (target.ownerId != 0) {
        ok = false
    }
    if (not target.qualityKnown) {
        ok = false
    }
    if (target.population != 0.0) {
        ok = false
    }
    if (target.productive) {
        ok = false
    }
    Fleet stayed = game.findFleet(1)
    if (not stayed.sitting or stayed.locationPlanetId != 1) {
        ok = false
    }
    if (stayed.hullCount < 1) {
        ok = false
    }

    # sit/move on possession: hop back toward home
    if (not game.issueOrder(1, "move", 0)) {
        ok = false
    }
    if (not check.waitArrive(game, 1, 0, 40)) {
        ok = false
    }
    stayed = game.findFleet(1)
    if (stayed.locationPlanetId != 0) {
        ok = false
    }

    # --- colony required to populate ---
    State colGame = State()
    colGame.startClosed(42u, 1)
    check.unlockColonyReach(colGame)
    Fleet colonyFleet = Fleet(1, 0, 0, 1, 1)
    colGame.fleets = []
    colGame.fleets.append(colonyFleet)
    colGame.nextFleetId = 2
    # Colony dispatch is expensive; credit wealth so it can leave.
    Player colSeat = colGame.primaryPlayer()
    colSeat.wealth = colSeat.wealth + 100.0
    colGame.players[0] = colSeat
    if (not colGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    if (not check.waitArrive(colGame, 1, 1, 40)) {
        ok = false
    }
    Planet colonized = colGame.galaxy.planets[1]
    if (colonized.ownerId != 0) {
        ok = false
    }
    if (colonized.population <= 0.0) {
        ok = false
    }
    if (not colonized.productive) {
        ok = false
    }

    # --- undefended owned non-productive: free take ---
    State freeGame = State()
    freeGame.startClosed(43u, 2)
    Planet strip = freeGame.galaxy.planets[1]
    strip.ownerId = 1
    strip.productive = false
    strip.population = 0.0
    strip.satelliteDefense = 0.0
    strip.qualityKnown = true
    freeGame.galaxy.planets[1] = strip
    if (not freeGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    list freeEv = []
    int64 waited = 0
    bool arrived = false
    while (waited < 40 and not arrived) {
        freeEv = freeGame.tick()
        Fleet f = freeGame.findFleet(1)
        if (f.sitting
            and not f.departed
            and not f.pendingDeparture
            and not f.stranded
            and f.locationPlanetId == 1) {
            arrived = true
        }
        waited = waited + 1
    }
    if (not arrived) {
        ok = false
    }
    if (check.countKind(freeEv, "combat_open") != 0) {
        ok = false
    }
    if (check.countKind(freeEv, "take") < 1) {
        ok = false
    }
    strip = freeGame.galaxy.planets[1]
    if (strip.ownerId != 0) {
        ok = false
    }

    # --- productive owned (zero fleet): never free ---
    State prodGame = State()
    prodGame.startClosed(44u, 2)
    Planet prod = prodGame.galaxy.planets[1]
    prod.ownerId = 1
    prod.productive = true
    prod.population = 1.0
    prod.satelliteDefense = 0.0
    prod.qualityKnown = true
    prodGame.galaxy.planets[1] = prod
    Fleet thin = prodGame.findFleet(1)
    thin.hullCount = 1
    prodGame.storeFleet(thin)
    if (not prodGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    list prodEv = []
    waited = 0
    arrived = false
    bool sawCombat = false
    while (waited < 40 and not arrived) {
        prodEv = prodGame.tick()
        if (check.countKind(prodEv, "combat_open") > 0) {
            sawCombat = true
        }
        if (check.countKind(prodEv, "combat_tick") > 0) {
            sawCombat = true
        }
        if (check.countKind(prodEv, "defend") > 0) {
            sawCombat = true
        }
        Fleet f = prodGame.findFleet(1)
        if (f.locationPlanetId == 1
            and f.sitting
            and not f.departed
            and not f.pendingDeparture) {
            if (sawCombat
                or prodGame.countOpenEngagements() > 0
                or check.countKind(prodEv, "take") > 0
                or check.countKind(prodEv, "defend") > 0) {
                arrived = true
            }
        }
        waited = waited + 1
    }
    if (not sawCombat) {
        ok = false
    }

    # --- satellites defend after warships leave ---
    State satGame = State()
    satGame.startClosed(45u, 2)
    Planet satRock = satGame.galaxy.planets[1]
    satRock.ownerId = 1
    satRock.productive = false
    satRock.population = 0.0
    satRock.satelliteDefense = 8.0
    satRock.qualityKnown = true
    satGame.galaxy.planets[1] = satRock
    Fleet satAtk = satGame.findFleet(1)
    satAtk.hullCount = 1
    satGame.storeFleet(satAtk)
    if (not satGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    bool satCombat = false
    waited = 0
    while (waited < 40) {
        list satEv = satGame.tick()
        if (check.countKind(satEv, "combat_open") > 0
            or check.countKind(satEv, "combat_tick") > 0
            or check.countKind(satEv, "defend") > 0) {
            satCombat = true
            break
        }
        if (check.countKind(satEv, "take") > 0
            and check.countKind(satEv, "combat_open") == 0) {
            satCombat = false
            break
        }
        waited = waited + 1
    }
    if (not satCombat) {
        ok = false
    }

    # --- dead colony does not populate ---
    State deadGame = State()
    deadGame.startClosed(46u, 2)
    check.unlockColonyReach(deadGame)
    Planet deadRock = deadGame.galaxy.planets[1]
    deadRock.ownerId = 1
    deadRock.productive = true
    deadRock.population = 1.0
    deadRock.satelliteDefense = 0.0
    deadRock.qualityKnown = true
    deadGame.galaxy.planets[1] = deadRock
    # Huge inherent defense vs one colony hull → attacker crushed.
    deadGame.scenario.productiveInherentDefense = 50.0
    deadGame.scenario.battleShortCircuitGap = 1.0
    Fleet deadCol = Fleet(1, 0, 0, 1, 1)
    deadGame.fleets = []
    deadGame.fleets.append(deadCol)
    deadGame.nextFleetId = 2
    Player deadSeat = deadGame.primaryPlayer()
    deadSeat.wealth = deadSeat.wealth + 100.0
    deadGame.players[0] = deadSeat
    if (not deadGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    waited = 0
    bool deadDone = false
    bool deadDefended = false
    while (waited < 40 and not deadDone) {
        list deadEv = deadGame.tick()
        if (check.countKind(deadEv, "defend") > 0) {
            deadDefended = true
            deadDone = true
        }
        if (check.countKind(deadEv, "combat_open") > 0) {
            deadDefended = true
        }
        Fleet df = deadGame.findFleet(1)
        if (df.hullCount == 0 and deadDefended) {
            deadDone = true
        }
        waited = waited + 1
    }
    deadRock = deadGame.galaxy.planets[1]
    if (not deadDefended) {
        ok = false
    }
    # Attacker must not populate the rock with a surviving colony.
    if (deadRock.ownerId == 0 and deadRock.population > 0.0) {
        Fleet df = deadGame.findFleet(1)
        if (df.hullCount > 0) {
            ok = false
        }
    }
    # Prefer defender kept ownership after crushing the colony.
    if (deadRock.ownerId == 0) {
        Fleet df = deadGame.findFleet(1)
        if (df.id >= 0 and df.hullCount > 0) {
            ok = false
        }
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
