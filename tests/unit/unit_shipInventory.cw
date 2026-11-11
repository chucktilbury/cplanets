/*
 * tests/unit/unit_shipInventory.cw — CPL-101 stock / assign model.
 *
 * Develop noop and name collision; builds credit unassigned stocks
 * (not fleets); assign over-qty rejects; mixed primary+escort ETA
 * uses the slower hull; reclaim-stock frees a player type name when
 * the last hulls are gone.
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial CPL-101 inventory unit program.
 *   2026-11-09  Assign players[0] to Player before .wealth (any).
 */

include "lib/design.cw"
include "lib/hullStock.cw"
include "lib/shipInventory.cw"
include "lib/state.cw"
include "lib/travel.cw"

start {
    bool ok = true
    ShipInventory book = ShipInventory()
    Travel travel = Travel()

    # --- develop noop: same params → same id, wealth unchanged ---
    State noop = State()
    noop.startClosed(101u, 1)
    noop.ensureAllSeatHomes()
    Design scoutDraft = Design(-1)
    scoutDraft.makeScout(
        noop.scenario.scoutRange,
        noop.scenario.designScoutSpeed,
        noop.scenario.designScoutSize)
    scoutDraft.name = "scout-copy"
    Player beforeNoop = noop.players[0]
    fp64 wealth0 = beforeNoop.wealth
    int64 firstId = noop.queueDesignDevelop(0, scoutDraft)
    if (firstId != 0) {
        ok = false
    }
    Player afterNoop = noop.players[0]
    if (ok and afterNoop.wealth != wealth0) {
        ok = false
    }
    int64 secondId = noop.queueDesignDevelop(0, scoutDraft)
    if (ok and secondId != firstId) {
        ok = false
    }
    Player afterSecond = noop.players[0]
    if (ok and afterSecond.wealth != wealth0) {
        ok = false
    }

    # --- name collision different params → -1 ---
    State collide = State()
    collide.startClosed(103u, 1)
    collide.ensureAllSeatHomes()
    Design warA = Design(-1)
    warA.name = "custom"
    warA.speed = 1.5
    warA.hopReach = 4.0
    warA.size = 1.0
    warA.cargoHold = 0.0
    warA.scout = false
    warA.colony = false
    warA.defense = false
    int64 customId = collide.queueDesignDevelop(0, warA)
    if (customId < 0) {
        ok = false
    }
    Design warB = Design(-1)
    warB.name = "custom"
    warB.speed = 2.5
    warB.hopReach = 4.0
    warB.size = 1.0
    warB.cargoHold = 0.0
    warB.scout = false
    warB.colony = false
    warB.defense = false
    int64 collision = collide.queueDesignDevelop(0, warB)
    if (ok and collision != -1) {
        ok = false
    }
    if (ok and collide.lastInventoryError.length < 1) {
        ok = false
    }

    # --- build completes into stocks not fleets ---
    State yard = State()
    yard.startClosed(105u, 1)
    yard.ensureAllSeatHomes()
    Player rich = yard.players[0]
    rich.resources = rich.resources + 10000.0
    yard.players[0] = rich
    int64 hullBefore = yard.findFleet(1).hullCount
    int64 stockBefore = book.available(yard.stocks, 0, 0, 0)
    if (not yard.queueYardBuild(0, 0, 0, 1)) {
        ok = false
    }
    int64 t = 0
    while (t < yard.scenario.yardBuildTicks) {
        yard.tick()
        t = t + 1
    }
    int64 hullAfter = yard.findFleet(1).hullCount
    int64 stockAfter = book.available(yard.stocks, 0, 0, 0)
    if (ok and hullAfter != hullBefore) {
        ok = false
    }
    if (ok and stockAfter != stockBefore + 1) {
        ok = false
    }

    # --- assign over-qty rejects ---
    State over = State()
    over.startClosed(107u, 1)
    over.ensureAllSeatHomes()
    int64 emptyId = over.createNamedFleet(0, "alpha", 0)
    if (emptyId < 1) {
        ok = false
    }
    book.credit(over.stocks, 0, 0, 0, 1)
    if (over.assignHullsToFleet(0, emptyId, "scout", 2)) {
        ok = false
    }
    if (ok and over.lastInventoryError.length < 1) {
        ok = false
    }
    if (ok and book.available(over.stocks, 0, 0, 0) != 1) {
        ok = false
    }

    # --- assign ok then dispatch ETA uses slower escort ---
    State mixed = State()
    mixed.startClosed(109u, 1)
    mixed.ensureAllSeatHomes()
    int64 mixedId = mixed.createNamedFleet(0, "mixed", 0)
    if (mixedId < 1) {
        ok = false
    }
    book.credit(mixed.stocks, 0, 0, 0, 1)
    book.credit(mixed.stocks, 0, 1, 0, 1)
    if (not mixed.assignHullsToFleet(0, mixedId, "scout", 1)) {
        ok = false
    }
    if (ok and not mixed.assignHullsToFleet(
        0, mixedId, "colony", 1)) {
        ok = false
    }
    Fleet mixedFleet = mixed.findFleet(mixedId)
    if (ok and mixedFleet.escortDesignId != 1) {
        ok = false
    }
    if (ok and mixedFleet.escortHullCount != 1) {
        ok = false
    }
    Design scout = mixed.designs[0]
    Design colony = mixed.designs[1]
    Player seat = mixed.players[0]
    Planet origin = mixed.galaxy.planets[0]
    Planet dest = mixed.galaxy.planets[1]
    int64 etaFast = travel.etaTicks(
        mixed.scenario, seat, scout, origin, dest)
    int64 etaSlow = travel.etaTicks(
        mixed.scenario, seat, colony, origin, dest)
    # Colony is slower (speed 1 vs scout 2) when distance > 0.
    if (ok and etaFast > 0 and etaSlow <= etaFast) {
        ok = false
    }
    if (ok and not mixed.issueOrder(mixedId, "move", 1)) {
        ok = false
    }
    Fleet ordered = mixed.findFleet(mixedId)
    if (ok and etaSlow > 0 and ordered.eta != etaSlow) {
        ok = false
    }

    # --- reclaim stock frees design name when last hulls gone ---
    State free = State()
    free.startClosed(111u, 1)
    free.ensureAllSeatHomes()
    Design owned = Design(-1)
    owned.name = "recyclable"
    owned.speed = 1.2
    owned.hopReach = 3.0
    owned.size = 1.0
    owned.cargoHold = 0.0
    owned.scout = false
    owned.colony = false
    owned.defense = false
    int64 ownedId = free.queueDesignDevelop(0, owned)
    if (ownedId < 0) {
        ok = false
    }
    int64 wait = 0
    while (wait < free.scenario.designDevelopTicks + 1) {
        free.tick()
        wait = wait + 1
    }
    Design ready = free.designs[ownedId]
    if (ok and not ready.isReady()) {
        ok = false
    }
    Player payer = free.players[0]
    payer.resources = payer.resources + 10000.0
    free.players[0] = payer
    if (ok and not free.queueYardBuild(0, 0, ownedId, 1)) {
        ok = false
    }
    wait = 0
    while (wait < free.scenario.yardBuildTicks + 1) {
        free.tick()
        wait = wait + 1
    }
    if (ok and book.available(free.stocks, 0, ownedId, 0) != 1) {
        ok = false
    }
    if (ok and not free.queueReclaimStock(0, 0, ownedId, 1)) {
        ok = false
    }
    wait = 0
    while (wait < free.scenario.yardBuildTicks + 2) {
        free.tick()
        wait = wait + 1
    }
    Design closed = free.designs[ownedId]
    if (ok and not closed.closed) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
