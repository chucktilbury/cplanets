/*
 * src/unit_serverPolicy.cw — last-policy table unit.
 *
 * PUT anytime; snapshot holds AFK last blob (PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial policy table unit.
 */

include "server/policyTable.cw"

start {
    bool ok = true
    PolicyTable table = PolicyTable()
    table.ensureSeats(2)
    buffer first = buffer[]
    first.append(1)
    first.append(2)
    if (not table.put(0, first)) {
        ok = false
    }
    if (ok and not table.has(0)) {
        ok = false
    }
    if (ok and table.has(1)) {
        ok = false
    }
    list snap = table.snapshot()
    if (ok and snap.length != 2) {
        ok = false
    }
    buffer got = snap[0]
    if (ok and got.length != 2) {
        ok = false
    }
    if (ok and got[0] != 1) {
        ok = false
    }
    buffer empty = snap[1]
    if (ok and empty.length != 0) {
        ok = false
    }
    buffer second = buffer[]
    second.append(9)
    if (ok and not table.put(0, second)) {
        ok = false
    }
    buffer latest = table.get(0)
    if (ok and latest.length != 1) {
        ok = false
    }
    if (ok and latest[0] != 9) {
        ok = false
    }
    print(ok)
    print("\n")
}
