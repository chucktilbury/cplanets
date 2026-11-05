/*
 * src/unit_empirePools.cw — empire pool seeding from scenario.
 *
 * Stocks live on the player (RULES §2); Phase B only checks start
 * pools and detection range from tech.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial empire-pool unit program.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(3u, 2)
    Player p0 = game.primaryPlayer()
    Player p1 = game.players[1]
    Scenario s = game.scenario
    bool ok = true
    if (p0.wealth != s.startWealth) {
        ok = false
    }
    if (p0.resources != s.startResources) {
        ok = false
    }
    if (p0.tech != s.startTech) {
        ok = false
    }
    if (p0.power != s.startPower) {
        ok = false
    }
    if (p0.experience != s.startExperience) {
        ok = false
    }
    if (p0.detectionRange != s.detectionRange(s.startTech)) {
        ok = false
    }
    if (p1.wealth != s.startWealth) {
        ok = false
    }
    if (p0.id != 0 or p1.id != 1) {
        ok = false
    }
    if (not p0.role.equals("neutral")) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
