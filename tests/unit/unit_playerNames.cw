/*
 * tests/unit/unit_playerNames.cw — proper-name pool (CPL-106).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial name-pool unit.
 */

include "lib/playerNames.cw"

start {
    bool ok = true
    PlayerNames names = PlayerNames()
    list pool = names.pool()
    if (pool.length < 10) {
        ok = false
    }
    if (ok and not names.nameInList("Bethany", pool)) {
        ok = false
    }
    if (ok and not names.nameInList("Alex", pool)) {
        ok = false
    }
    SeededRng rng = SeededRng(42u)
    String first = names.pick(rng)
    if (ok and first.length < 1) {
        ok = false
    }
    if (ok and not names.nameInList(first, pool)) {
        ok = false
    }
    list used = []
    used.append(first)
    String second = names.pickUnused(SeededRng(99u), used)
    if (ok and second.length < 1) {
        ok = false
    }
    # Same seed → same first pick (reproducible).
    String again = names.pick(SeededRng(42u))
    if (ok and not again.equals(first)) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
