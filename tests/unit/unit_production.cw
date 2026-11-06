/*
 * tests/unit/unit_production.cw — productive home credits empire pools.
 *
 * Fixed seed; one tick must raise wealth/resources and emit a
 * production event (PLAN §4.C / RULES §7.1).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial production unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(13u, 1)
    Player before = game.primaryPlayer()
    fp64 w0 = before.wealth
    fp64 r0 = before.resources
    list events = game.tick()
    Player after = game.primaryPlayer()
    bool ok = true
    if (after.wealth <= w0) {
        ok = false
    }
    if (after.resources <= r0) {
        ok = false
    }
    if (game.tickCount != 1) {
        ok = false
    }
    if (not game.locked) {
        ok = false
    }
    bool saw = false
    int64 index = 0
    while (index < events.length) {
        TickEvent ev = events[index]
        if (ev.kind.equals("production")) {
            saw = true
        }
        index = index + 1
    }
    if (not saw) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
