/*
 * tests/unit/unit_serverClock.cw — injectable cadence clock unit.
 *
 * Fixed advances: due/markFired without wall sleep (PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial server clock unit.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "server/clock.cw"

start {
    bool ok = true
    ServerClock clock = ServerClock(5, true)
    if (clock.periodMs != 5000) {
        ok = false
    }
    if (ok and not clock.due()) {
        ok = false
    }
    clock.markFired()
    if (ok and clock.due()) {
        ok = false
    }
    if (ok and not clock.advanceMs(4999u)) {
        ok = false
    }
    if (ok and clock.due()) {
        ok = false
    }
    if (ok and not clock.advanceMs(1u)) {
        ok = false
    }
    if (ok and not clock.due()) {
        ok = false
    }
    ServerClock clamped = ServerClock(99, true)
    if (ok and clamped.periodMs != 30000) {
        ok = false
    }
    ServerClock low = ServerClock(0, true)
    if (ok and low.periodMs != 1000) {
        ok = false
    }
    print(ok)
    print("\n")
}
