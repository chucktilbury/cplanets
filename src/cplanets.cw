/*
 * src/cplanets.cw — human GTK client stub (Phase A).
 *
 * Future list debugger: policy editors, digest, planet/fleet lists
 * (PLAN §4.G). Phase A only prints the program name and lib
 * identity. Never ticks; never opens the universe DB (RULES §2).
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
    print("cplanets\n")
    print(machine.identity())
    print("\n")
}
