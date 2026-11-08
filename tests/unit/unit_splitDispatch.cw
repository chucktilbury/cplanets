/*
 * tests/unit/unit_splitDispatch.cw — peel sitting hulls then order.
 *
 * Yard builds merge same-design hulls into one sit stack. Split
 * dispatch peels a subset, leaves the remainder sitting, and
 * queues the peeled fleet as pendingDeparture (CPL-69).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial peel + issueOrderHulls unit program.
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

    # Peel 2 of 3 → new fleet; parent keeps 1 sitting.
    int64 detached = game.peelSittingHulls(1, 2)
    if (detached < 0 or detached == 1) {
        ok = false
    }
    Fleet parent = game.findFleet(1)
    Fleet child = game.findFleet(detached)
    if (ok and (parent.hullCount != 1 or not parent.sitting)) {
        ok = false
    }
    if (ok and (child.hullCount != 2
        or not child.sitting
        or child.locationPlanetId != parent.locationPlanetId
        or child.designId != parent.designId)) {
        ok = false
    }

    # Dispatch the peeled stack to planet 1.
    if (ok and not game.issueOrder(detached, "move", 1)) {
        ok = false
    }
    child = game.findFleet(detached)
    if (ok and (not child.pendingDeparture or child.sitting)) {
        ok = false
    }
    parent = game.findFleet(1)
    if (ok and (not parent.sitting or parent.pendingDeparture)) {
        ok = false
    }

    # Oversize peel refused; zero peels return same id.
    if (ok and game.peelSittingHulls(1, 9) >= 0) {
        ok = false
    }
    if (ok and game.peelSittingHulls(1, 0) != 1) {
        ok = false
    }

    # issueOrderHulls peels then orders in one call.
    State stacked = State()
    stacked.startClosed(19u, 1)
    stacked.ensureAllSeatHomes()
    if (ok and not stacked.issueOrderHulls(1, "explore", 1, 2)) {
        ok = false
    }
    Fleet left = stacked.findFleet(1)
    if (ok and (left.hullCount != 1 or not left.sitting)) {
        ok = false
    }
    bool foundPending = false
    int64 index = 0
    while (index < stacked.fleets.length) {
        Fleet f = stacked.fleets[index]
        if (f.id != 1
            and f.pendingDeparture
            and f.hullCount == 2
            and f.order.equals("explore")) {
            foundPending = true
        }
        index = index + 1
    }
    if (ok and not foundPending) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
