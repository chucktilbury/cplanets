/*
 * tests/unit/unit_dispatch.cw — dispatch wealth sunk on real departure.
 *
 * Fixed seed; move order that survives the tick pays dispatch and
 * leaves. Cannot-pay stays sitting (PLAN §4.C / RULES §5.1).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial dispatch unit program.
 *   2026-11-05  Net wealth of production; colony cannot-pay case.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(17u, 1)
    game.ensureAllSeatHomes()
    Fleet home = game.findFleet(1)
    bool ok = true
    if (home.id != 1 or home.hullCount != 3) {
        ok = false
    }
    Player seat = game.primaryPlayer()
    fp64 w0 = seat.wealth
    Design scout = game.designs[0]
    Dispatch bill = Dispatch()
    fp64 expectCost = bill.dispatchCost(game.scenario, scout, 3)
    if (not game.issueOrder(1, "move", 1)) {
        ok = false
    }
    list events = game.tick()
    seat = game.primaryPlayer()
    Planet homeRock = game.galaxy.planets[0]
    fp64 prod = homeRock.livability * game.scenario.coverFactor * (
        game.scenario.productionTickRate
        - game.scenario.wealthUpkeepTickRate)
    fp64 expected = w0 + prod - expectCost
    fp64 delta = seat.wealth - expected
    if (delta < 0.0) {
        delta = 0.0 - delta
    }
    if (delta > 0.0001) {
        ok = false
    }
    bool departed = false
    int64 index = 0
    while (index < events.length) {
        TickEvent ev = events[index]
        if (ev.kind.equals("depart") and ev.fleetId == 1) {
            departed = true
        }
        index = index + 1
    }
    if (not departed) {
        ok = false
    }

    # Cannot-pay: colony dispatch 5.0 > production credit ~1.0.
    State poor = State()
    poor.startClosed(17u, 1)
    poor.ensureAllSeatHomes()
    poor.fleets.clear()
    poor.fleets.append(Fleet(1, 0, 0, 1, 1))
    Player p = poor.primaryPlayer()
    p.wealth = 0.0
    poor.players[0] = p
    if (not poor.issueOrder(1, "move", 1)) {
        ok = false
    }
    list ev2 = poor.tick()
    Fleet stuck = poor.findFleet(1)
    if (not stuck.sitting or stuck.departed) {
        ok = false
    }
    bool fail = false
    index = 0
    while (index < ev2.length) {
        TickEvent ev = ev2[index]
        if (ev.kind.equals("depart_fail")) {
            fail = true
        }
        if (ev.kind.equals("depart")) {
            ok = false
        }
        index = index + 1
    }
    if (not fail) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
