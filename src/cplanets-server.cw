/*
 * src/cplanets-server.cw — server executable stub (Phase A).
 *
 * Future sole writer: TCP, SQLite, real-time tick schedule (RULES
 * §2). Phase A only prints the program name and lib identity. Does
 * not call tick; does not open a DB yet.
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
    print("cplanets-server\n")
    print(machine.identity())
    print("\n")
}
