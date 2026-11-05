/*
 * src/cplanets-ai.cw — AI client stub (Phase A).
 *
 * Future stand-alone AI client on the same TCP protocol as the
 * human client, with its own config (PLAN §4.H / RULES §2). Phase A
 * only prints the program name and lib identity.
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
    print("cplanets-ai\n")
    print(machine.identity())
    print("\n")
}
