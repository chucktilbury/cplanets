/*
 * tests/fn/fn_tickCore.cw — Phase C rule cluster over several ticks.
 *
 * Fixed seed: production, dispatch+move/arrive, teleport ETA→0,
 * same-tick cancel, in-flight recall, stranded-N, yard build.
 * No trade/pirate/take combat (Phase D).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase C function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-10  Yard build asserts unassigned stock (CPL-101).
 */

include "lib/shipInventory.cw"
include "lib/state.cw"

/*
 * FnCheck counts TickEvent kinds for Phase C asserts.
 *
 * Purpose: keep the start block free of duplicated scan loops.
 */
class FnCheck {
    /*
     * Construct a stateless event counter.
     *
     * Purpose: match other small test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnCheck instance.
     */
    FnCheck() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert depart/cancel/arrive/stranded/recall counts.
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
}

start {
    FnCheck check = FnCheck()
    bool ok = true

    # --- production + ordinary hop arrive ---
    State game = State()
    game.startClosed(29u, 1)
    game.ensureAllSeatHomes()
    fp64 w0 = game.primaryPlayer().wealth
    if (not game.issueOrder(1, "move", 1)) {
        ok = false
    }
    Fleet pending = game.findFleet(1)
    int64 need = pending.eta
    if (need < 1) {
        ok = false
    }
    list ev = game.tick()
    if (check.countKind(ev, "production") < 1) {
        ok = false
    }
    if (check.countKind(ev, "depart") != 1) {
        ok = false
    }
    # Production credits home; dispatch must still sink scout weight.
    Design scout = game.designs[0]
    Dispatch bill = Dispatch()
    fp64 cost = bill.dispatchCost(game.scenario, scout, 3)
    Planet homeRock = game.galaxy.planets[0]
    fp64 prod = homeRock.livability * game.scenario.coverFactor * 0.01
    fp64 delta = game.primaryPlayer().wealth - (w0 + prod - cost)
    if (delta < 0.0) {
        delta = 0.0 - delta
    }
    if (delta > 0.0001) {
        ok = false
    }
    # Depart tick already decremented once; need-1 more ticks.
    int64 waited = 1
    while (waited < need) {
        game.tick()
        waited = waited + 1
    }
    Fleet arrived = game.findFleet(1)
    if (not arrived.sitting or arrived.locationPlanetId != 1) {
        ok = false
    }

    # --- high-tech teleport ETA → 0 ---
    State tele = State()
    tele.startClosed(31u, 1)
    tele.ensureAllSeatHomes()
    Player seat = tele.primaryPlayer()
    seat.tech = tele.scenario.techTeleportThreshold
    tele.players[0] = seat
    if (not tele.issueOrder(1, "move", 1)) {
        ok = false
    }
    Fleet tf = tele.findFleet(1)
    if (tf.eta != 0) {
        ok = false
    }
    ev = tele.tick()
    if (check.countKind(ev, "depart") != 1) {
        ok = false
    }
    if (check.countKind(ev, "arrive") != 1) {
        ok = false
    }
    tf = tele.findFleet(1)
    if (not tf.sitting or tf.locationPlanetId != 1) {
        ok = false
    }

    # --- same-tick cancel ---
    State cancel = State()
    cancel.startClosed(37u, 1)
    cancel.ensureAllSeatHomes()
    fp64 cw = cancel.primaryPlayer().wealth
    cancel.issueOrder(1, "move", 1)
    cancel.recallFleet(1)
    ev = cancel.tick()
    if (check.countKind(ev, "cancel") != 1
        or check.countKind(ev, "depart") != 0) {
        ok = false
    }
    Planet cancelHome = cancel.galaxy.planets[0]
    fp64 cancelProd = cancelHome.livability * cancel.scenario.coverFactor * 0.01
    fp64 cancelDelta = cancel.primaryPlayer().wealth - (cw + cancelProd)
    if (cancelDelta < 0.0) {
        cancelDelta = 0.0 - cancelDelta
    }
    if (cancelDelta > 0.0001) {
        ok = false
    }

    # --- in-flight recall toward sender ---
    State rec = State()
    rec.startClosed(41u, 1)
    rec.ensureAllSeatHomes()
    Design d = rec.designs[0]
    d.speed = 0.1
    rec.designs[0] = d
    rec.fleets.clear()
    rec.fleets.append(Fleet(1, 0, 0, 0, 3))
    if (not rec.issueOrder(1, "move", 1)) {
        ok = false
    }
    Fleet rf = rec.findFleet(1)
    if (rf.eta < 2) {
        ok = false
    }
    rec.tick()
    rf = rec.findFleet(1)
    if (not rf.departed) {
        ok = false
    }
    rec.recallFleet(1)
    ev = rec.tick()
    if (check.countKind(ev, "recall") != 1) {
        ok = false
    }
    rf = rec.findFleet(1)
    if (rf.destPlanetId != rf.senderPlanetId
        and rf.locationPlanetId != 0) {
        ok = false
    }

    # --- stranded then unstuck ---
    State strand = State()
    strand.startClosed(43u, 1)
    strand.ensureAllSeatHomes()
    strand.fleets.clear()
    strand.fleets.append(Fleet(1, 0, 0, 1, 1))
    int64 farId = strand.scenario.worldCount - 1
    strand.issueOrder(1, "move", farId)
    ev = strand.tick()
    if (check.countKind(ev, "stranded") != 1) {
        ok = false
    }
    Fleet sf = strand.findFleet(1)
    int64 wait = sf.strandedLeft
    int64 i = 0
    while (i < wait) {
        strand.tick()
        i = i + 1
    }
    sf = strand.findFleet(1)
    if (sf.stranded) {
        ok = false
    }

    # --- yard build completes into unassigned stock (CPL-101) ---
    State yard = State()
    yard.startClosed(47u, 1)
    yard.ensureAllSeatHomes()
    ShipInventory book = ShipInventory()
    int64 hull0 = yard.findFleet(1).hullCount
    int64 stock0 = book.available(yard.stocks, 0, 0, 0)
    if (not yard.queueYardBuild(0, 0, 0, 1)) {
        ok = false
    }
    int64 t = 0
    while (t < yard.scenario.yardBuildTicks) {
        yard.tick()
        t = t + 1
    }
    int64 hull1 = yard.findFleet(1).hullCount
    int64 stock1 = book.available(yard.stocks, 0, 0, 0)
    if (hull1 != hull0) {
        ok = false
    }
    if (stock1 != stock0 + 1) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
