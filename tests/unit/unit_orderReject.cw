/*
 * tests/unit/unit_orderReject.cw — PUT /order reject reasons + yard.
 *
 * Fleet id 0 never exists (GUI Entry used to default there). Yard
 * builds still complete into a sitting fleet that can be dispatched
 * (merge or spawn). Driver.lastOrderError must name the miss.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial missing-fleet + post-build dispatch unit.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    State game = State()
    game.startClosed(47u, 1)
    game.ensureAllSeatHomes()
    GameDriver drv = GameDriver(game, true, "", false, 10000u)

    # Fleet 0 does not exist — clear reason (playable Entry trap).
    if (drv.issueOwnedOrder(0, 0, "explore", 1, 0)) {
        ok = false
    }
    if (ok and not drv.lastOrderError.equals("fleet 0 does not exist")) {
        ok = false
    }

    # Send the home stack away, then build a new sit fleet at home.
    Player seat = drv.game.players[0]
    seat.resources = seat.resources + 10000.0
    drv.game.players[0] = seat
    if (ok and not drv.issueOwnedOrder(0, 1, "explore", 1, 0)) {
        ok = false
    }
    drv.advanceTicks(2)
    if (ok and not drv.queueOwnedBuild(0, 0, 0)) {
        ok = false
    }
    int64 waited = 0
    while (waited < 20 and drv.game.builds.length > 0) {
        drv.advanceTicks(1)
        waited = waited + 1
    }
    if (ok and drv.game.builds.length != 0) {
        ok = false
    }
    int64 sitId = -1
    int64 index = 0
    while (index < drv.game.fleets.length) {
        Fleet f = drv.game.fleets[index]
        if (f.sitting
            and f.locationPlanetId == 0
            and f.ownerId == 0
            and f.hullCount > 0) {
            sitId = f.id
        }
        index = index + 1
    }
    if (ok and sitId < 1) {
        ok = false
    }
    if (ok and not drv.issueOwnedOrder(0, sitId, "move", 2, 0)) {
        ok = false
    }
    if (ok and drv.lastOrderError.length > 0) {
        ok = false
    }

    # Merge path: build adds hulls to existing sit stack id 1.
    State stacked = State()
    stacked.startClosed(49u, 1)
    stacked.ensureAllSeatHomes()
    GameDriver d2 = GameDriver(stacked, true, "", false, 10000u)
    Player s2 = d2.game.players[0]
    s2.resources = s2.resources + 10000.0
    d2.game.players[0] = s2
    int64 before = d2.game.findFleet(1).hullCount
    if (ok and not d2.queueOwnedBuild(0, 0, 0)) {
        ok = false
    }
    d2.advanceTicks(10)
    int64 after = d2.game.findFleet(1).hullCount
    if (ok and after != before + 1) {
        ok = false
    }
    if (ok and d2.game.fleets.length != 1) {
        ok = false
    }
    if (ok and not d2.issueOwnedOrder(0, 1, "explore", 1, 1)) {
        ok = false
    }

    # Oversize peel reason.
    State fat = State()
    fat.startClosed(51u, 1)
    fat.ensureAllSeatHomes()
    GameDriver d3 = GameDriver(fat, true, "", false, 10000u)
    if (d3.issueOwnedOrder(0, 1, "explore", 1, 99)) {
        ok = false
    }
    if (ok and d3.lastOrderError.length < 1) {
        ok = false
    }

    drv.close()
    d2.close()
    d3.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
