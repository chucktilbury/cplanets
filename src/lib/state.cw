/*
 * src/lib/state.cw — game state bootstrap (Phase B).
 *
 * Assembles scenario, galaxy, empire pools, and seeded RNG into the
 * starting snapshot. No tick, no TCP, no SQLite (PLAN §4.B).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial closed-game start helpers.
 */

include "galaxy.cw"
include "setupParse.cw"

/*
 * State is the published game snapshot before any tick.
 *
 * Phase B only constructs the start layout. Setup lock is a bool
 * for later phases; tickCount stays at zero.
 */
class State {
    Scenario scenario
    Galaxy galaxy
    list players
    SeededRng rng
    bool locked
    int64 tickCount

    /*
     * Construct an empty state shell.
     *
     * Purpose: allow field-by-field fill from startClosed /
     * startFromText without a partial constructor.
     *
     * Parameters: none.
     *
     * Returns: State with empty players and unlocked setup.
     */
    State() {
        scenario = Scenario()
        galaxy = Galaxy()
        players = []
        rng = SeededRng(1u)
        locked = false
        tickCount = 0
    }

    /*
     * Start a closed-scenario game from the default fixture.
     *
     * Purpose: one-call bootstrap for unit tests and the tick CLI
     * host — home yard, scout rocks, empire pools, seeded RNG.
     *
     * Parameters:
     *   seed — PRNG seed (0 remapped inside SeededRng).
     *   playerCount — number of empire seats (>= 1).
     *
     * Returns: nothing; fills this State in place.
     */
    void startClosed(uint64 seed, int64 playerCount) {
        scenario = Scenario()
        scenario.clampTickPeriod()
        finishStart(seed, playerCount)
    }

    /*
     * Start a game from application-text setup.
     *
     * Purpose: load named §14 knobs from text, then build galaxy and
     * pools the same way as startClosed.
     *
     * Parameters:
     *   text — setup document body.
     *   seed — PRNG seed.
     *   playerCount — number of empire seats (>= 1).
     *
     * Returns: nothing; fills this State in place.
     */
    void startFromText(
        String text,
        uint64 seed,
        int64 playerCount) {
        SetupParse parser = SetupParse()
        scenario = parser.parseText(text)
        finishStart(seed, playerCount)
    }

    /*
     * Shared galaxy / pool wiring after scenario is chosen.
     *
     * Purpose: keep startClosed and startFromText aligned on player
     * seats, home ownership, and RNG.
     *
     * Parameters:
     *   seed — PRNG seed.
     *   playerCount — empire seats; values < 1 become 1.
     *
     * Returns: nothing; mutates this State.
     */
    void finishStart(uint64 seed, int64 playerCount) {
        rng = SeededRng(seed)
        locked = false
        tickCount = 0
        players = []
        int64 seats = playerCount
        if (seats < 1) {
            seats = 1
        }
        int64 index = 0
        while (index < seats) {
            Player seat = Player(index)
            seat.applyStartingPools(scenario)
            players.append(seat)
            index = index + 1
        }
        galaxy = Galaxy()
        galaxy.buildFrom(scenario, rng, 0)
    }

    /*
     * Mark setup locked once a game is in progress.
     *
     * Purpose: mirror RULES §14 lock without a server yet. Phase B
     * tests may call this after start.
     *
     * Parameters: none.
     *
     * Returns: nothing; sets locked true.
     */
    void lockSetup() {
        locked = true
    }

    /*
     * Return the first player seat (empire 0).
     *
     * Purpose: unit tests read home-owner pools without indexing
     * through an any-typed list at every call site.
     *
     * Parameters: none.
     *
     * Returns: Player at players[0]; raises if no seats.
     */
    Player primaryPlayer() {
        Player seat = players[0]
        return(seat)
    }
}
