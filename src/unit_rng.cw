/*
 * src/unit_rng.cw — unit program for SeededRng reproducibility.
 *
 * Fixed seed; prints a bool line. No TCP, no sleep (PLAN §3).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial RNG unit program.
 */

include "lib/rng.cw"

start {
    SeededRng a = SeededRng(42u)
    SeededRng b = SeededRng(42u)
    SeededRng c = SeededRng(99u)
    bool same = true
    bool differ = false
    int64 i = 0
    while (i < 8) {
        uint64 av = a.nextU64()
        uint64 bv = b.nextU64()
        uint64 cv = c.nextU64()
        if (av != bv) {
            same = false
        }
        if (av != cv) {
            differ = true
        }
        uint64 ab = a.nextBounded(10u)
        uint64 bb = b.nextBounded(10u)
        if (ab != bb or ab >= 10u) {
            same = false
        }
        fp64 af = a.nextFp01()
        fp64 bf = b.nextFp01()
        if (af != bf or af < 0.0 or af >= 1.0) {
            same = false
        }
        i = i + 1
    }
    if (same and differ) {
        print("true\n")
    } else {
        print("false\n")
    }
}
