/*
 * src/lib/rng.cw — seeded PRNG for tick and setup (Phase B).
 *
 * Lives in lib so fn/unit tests and tick share one reproducible
 * stream. Not SecureRandom (RULES §17 / PLAN §3). xorshift64 is
 * enough for game rolls; magnitudes stay scenario-owned.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial seeded xorshift64 helper.
 */

/*
 * SeededRng is a deterministic uint64 stream.
 *
 * Same seed yields the same sequence across runs. Zero seed is
 * remapped so the generator never sticks at the all-zero state.
 */
class SeededRng {
    uint64 state

    /*
     * Construct a generator from an explicit seed.
     *
     * Purpose: pin reproducibility for unit/fn tests and for a
     * scenario start that names its seed.
     *
     * Parameters:
     *   seed — any uint64; 0 is replaced with 1.
     *
     * Returns: a SeededRng ready for nextU64 / nextBounded /
     * nextFp01.
     */
    SeededRng(uint64 seed) {
        if (seed == 0u) {
            state = 1u
        } else {
            state = seed
        }
    }

    /*
     * Advance the generator and return the next raw uint64.
     *
     * Purpose: supply bits for rolls, placement, and higher-level
     * helpers without touching wall-clock entropy.
     *
     * Parameters: none.
     *
     * Returns: the next xorshift64 value; also updates state.
     */
    uint64 nextU64() {
        uint64 x = state
        x = x ^ (x << 13)
        x = x ^ (x >> 7)
        x = x ^ (x << 17)
        state = x
        return(x)
    }

    /*
     * Return a value in [0, bound).
     *
     * Purpose: pick discrete indices (planet slots, mix rolls)
     * without callers writing their own modulo.
     *
     * Parameters:
     *   bound — exclusive upper bound; 0 returns 0.
     *
     * Returns: nextU64() % bound, or 0 when bound is 0.
     */
    uint64 nextBounded(uint64 bound) {
        if (bound == 0u) {
            return(0u)
        }
        return(nextU64() % bound)
    }

    /*
     * Return a coarse fp64 in [0.0, 1.0).
     *
     * Purpose: place rocks and roll fractions with a simple unit
     * interval. Precision is placeholder-grade (1e-6 steps).
     *
     * Parameters: none.
     *
     * Returns: fp64 in [0.0, 1.0).
     */
    fp64 nextFp01() {
        uint64 steps = 1000000u
        return(fp64(nextBounded(steps)) / 1000000.0)
    }

    /*
     * Return the current internal state without advancing.
     *
     * Purpose: let tests assert seed continuity after a known
     * number of draws.
     *
     * Parameters: none.
     *
     * Returns: the current uint64 state word.
     */
    uint64 currentState() {
        return(state)
    }
}
