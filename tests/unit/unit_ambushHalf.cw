/*
 * tests/unit/unit_ambushHalf.cw — half-hop ambush ETA helper.
 *
 * Asserts integer-division midpoint timing (ETA 10 ⇒ 5) used by
 * Midpoint.halfEta (PLAN D3 / RULES §6).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial ambush half-ETA unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/midpoint.cw"

start {
    Midpoint mid = Midpoint()
    bool ok = true
    if (mid.halfEta(10) != 5) {
        ok = false
    }
    if (mid.halfEta(11) != 5) {
        ok = false
    }
    if (mid.halfEta(1) != 0) {
        ok = false
    }
    if (mid.halfEta(0) != 0) {
        ok = false
    }
    if (mid.halfEta(2) != 1) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
