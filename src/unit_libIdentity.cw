/*
 * src/unit_libIdentity.cw — unit program for Machine.identity.
 *
 * Cwhip stages SOURCE from this file's directory, so the program
 * lives next to lib/ (PLAN §4.A). CTest wrapper:
 * tests/unit/libIdentity.cmake. Prints a bool line; no TCP, no sleep.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit program.
 *   2026-11-05  CODING file header.
 */

include "lib/machine.cw"

start {
    Machine machine = Machine()
    String<> identity = machine.identity
    if (identity().equals("cplanets-lib")) {
        print("true\n")
    } else {
        print("false\n")
    }
}
