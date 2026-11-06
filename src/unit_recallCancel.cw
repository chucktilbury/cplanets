/*
 * src/unit_recallCancel.cw — same-tick recall cancels (no dispatch).
 *
 * Issue move + recall before tick; no depart, cancel event, fleet
 * sitting. Wealth equals start + production only (PLAN §6 /
 * RULES §5.2).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial same-tick cancel unit program.
 *   2026-11-05  Account for production credit on wealth check.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(19u, 1)
    Player seat = game.primaryPlayer()
    fp64 w0 = seat.wealth
    bool ok = true
    if (not game.issueOrder(1, "move", 1)) {
        ok = false
    }
    if (not game.recallFleet(1)) {
        ok = false
    }
    list events = game.tick()
    seat = game.primaryPlayer()
    Planet homeRock = game.galaxy.planets[0]
    fp64 prod = homeRock.livability * game.scenario.coverFactor * 0.01
    if (seat.wealth != w0 + prod) {
        ok = false
    }
    Fleet fleet = game.findFleet(1)
    if (not fleet.sitting or fleet.departed or fleet.pendingDeparture) {
        ok = false
    }
    bool sawCancel = false
    bool sawDepart = false
    int64 index = 0
    while (index < events.length) {
        TickEvent ev = events[index]
        if (ev.kind.equals("cancel") and ev.fleetId == 1) {
            sawCancel = true
        }
        if (ev.kind.equals("depart") and ev.fleetId == 1) {
            sawDepart = true
        }
        index = index + 1
    }
    if (not sawCancel or sawDepart) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
