/*
 * src/cplanets-tick.cw — headless N-tick host stub (Phase A).
 *
 * Optional CLI that will call lib-only tick for unit/fn tests so
 * they need not link GTK or SQLite (PLAN §1). Phase A only prints
 * the program name and lib identity.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 */

include "lib/machine.cw"

start {
    Machine machine = Machine()
    print("cplanets-tick\n")
    print(machine.identity())
    print("\n")
}
