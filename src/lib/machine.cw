/*
 * src/lib/machine.cw — shared game-machine stub (Phase A).
 *
 * Holds the library identity used by stub executables and the
 * unit_libIdentity program. No main, no GTK, no scheduler, no
 * tick — those stay in later phases (PLAN §1 / §4.A).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub (identity only).
 *   2026-11-05  CODING file header and full method comments.
 *   2026-11-05  Phase B: identity unchanged; scenario/RNG live
 *               beside this file under src/lib/.
 */

/*
 * Machine is the shared library surface for CPlanets.
 *
 * Phase A exposes only an identity string so CMake programs and the
 * unit test can link lib without pulling GTK, SQLite, or TCP.
 */
class Machine {
    /*
     * Return the shared library identity string.
     *
     * Purpose: give stub executables and unit_libIdentity a stable
     * value to print or compare, proving they include lib/.
     *
     * Parameters: none.
     *
     * Returns: managed String equal to "cplanets-lib".
     */
    String identity() {
        return("cplanets-lib")
    }
}
