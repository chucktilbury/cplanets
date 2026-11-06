/*
 * tests/unit/unit_galaxyStart.cw — home yard, scout rocks, unknown quality.
 *
 * Builds a closed start state and checks PLAN §6 setup checklist
 * items that Phase B owns (no tick yet).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial galaxy-start unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(7u, 1)
    Scenario s = game.scenario
    Galaxy g = game.galaxy
    bool ok = true
    if (g.planets.length != s.worldCount) {
        ok = false
    }
    Planet home = g.planets[0]
    if (not home.productive or not home.shipyard) {
        ok = false
    }
    if (not home.qualityKnown or home.ownerId != 0) {
        ok = false
    }
    if (g.countUnknownQuality() != s.worldCount - 1) {
        ok = false
    }
    int64 inScout = g.countInScoutRange(s)
    if (inScout < 1) {
        ok = false
    }
    if (inScout >= s.worldCount) {
        ok = false
    }
    SeededRng again = SeededRng(7u)
    Galaxy copy = Galaxy()
    copy.buildFrom(s, again, 0)
    if (copy.planets.length != g.planets.length) {
        ok = false
    } else {
        Planet a = g.planets[1]
        Planet b = copy.planets[1]
        if (a.x != b.x or a.y != b.y) {
            ok = false
        }
    }
    game.lockSetup()
    if (not game.locked) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
