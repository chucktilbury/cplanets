/*
 * tests/unit/unit_libIdentity.cw — unit program for Machine.identity.
 *
 * CTest wrapper: tests/unit/unit_libIdentity.cmake. Prints a
 * bool line; no TCP, no sleep. Production code is included
 * via the test build's `cwhip -p src` search path.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit program.
 *   2026-11-05  CODING file header.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
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
