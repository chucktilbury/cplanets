/*
 * tests/unit/unit_stranded.cw — out-of-reach hop strands; moves after N.
 *
 * Colony toward a remote rock exceeds hopReach; after strandedTicksN
 * ticks the fleet is unstuck (PLAN §6 / RULES §6).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stranded-N unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(23u, 1)
    game.ensureAllSeatHomes()
    # Replace home scout stock with a colony fleet (short reach).
    Fleet colony = Fleet(1, 0, 0, 1, 1)
    game.fleets.clear()
    game.fleets.append(colony)
    int64 farId = game.scenario.worldCount - 1
    bool ok = true
    if (not game.issueOrder(1, "move", farId)) {
        ok = false
    }
    list events = game.tick()
    Fleet fleet = game.findFleet(1)
    if (not fleet.stranded) {
        ok = false
    }
    if (fleet.strandedLeft != game.scenario.strandedTicksN - 1) {
        # countdown already ticked once in the same tick's step 8.
        ok = false
    }
    bool sawStrand = false
    int64 index = 0
    while (index < events.length) {
        TickEvent ev = events[index]
        if (ev.kind.equals("stranded")) {
            sawStrand = true
        }
        index = index + 1
    }
    if (not sawStrand) {
        ok = false
    }
    int64 left = fleet.strandedLeft
    int64 step = 0
    while (step < left) {
        game.tick()
        step = step + 1
    }
    fleet = game.findFleet(1)
    if (fleet.stranded) {
        ok = false
    }
    # Now able to issue a short hop.
    if (not game.issueOrder(1, "move", 1)) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
