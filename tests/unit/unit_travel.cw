/*
 * tests/unit/unit_travel.cw — ETA, hop reach, and tech teleport.
 *
 * Fixed seed galaxy; asserts Travel.etaTicks and canHop against
 * scenario tech→teleport mapping (PLAN §4.C / RULES §6).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial travel unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(11u, 1)
    game.ensureAllSeatHomes()
    Travel travel = Travel()
    Player seat = game.primaryPlayer()
    Design scout = game.designs[0]
    Planet home = game.galaxy.planets[0]
    Planet near = game.galaxy.planets[1]
    bool ok = true
    if (not travel.canHop(scout, home, near)) {
        ok = false
    }
    int64 eta = travel.etaTicks(
        game.scenario,
        seat,
        scout,
        home,
        near)
    if (eta < 1) {
        ok = false
    }
    seat.tech = game.scenario.techTeleportThreshold
    if (not game.scenario.teleports(seat.tech)) {
        ok = false
    }
    int64 zero = travel.etaTicks(
        game.scenario,
        seat,
        scout,
        home,
        near)
    if (zero != 0) {
        ok = false
    }
    int64 back = travel.recallEta(game.scenario, seat, 7)
    if (back != 0) {
        ok = false
    }
    seat.tech = 0.0
    back = travel.recallEta(game.scenario, seat, 7)
    if (back != 7) {
        ok = false
    }
    Design colony = game.designs[1]
    Planet far = game.galaxy.planets[game.scenario.worldCount - 1]
    if (travel.canHop(colony, home, far)) {
        # colony hopReach is half scoutRange; remotes are outside
        # scoutRange, so this hop should fail.
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
