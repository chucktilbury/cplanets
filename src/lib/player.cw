/*
 * src/lib/player.cw — empire pools and starting attributes (Phase B).
 *
 * Stocks are an empire pool (RULES §2 / §3): wealth, resources, and
 * tech live on the player, not per-planet logistics.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial player / empire pool fields.
 */

include "scenario.cw"

/*
 * Player is one empire seat in the game state.
 *
 * Phase B fills starting pools from Scenario and computes the
 * initial detection/range from technology. Role and designs stay
 * thin until later phases.
 */
class Player {
    int64 id
    String role
    fp64 wealth
    fp64 resources
    fp64 tech
    fp64 power
    fp64 experience
    fp64 detectionRange
    bool present

    /*
     * Construct a player with neutral role and empty pools.
     *
     * Purpose: allocate a seat before applyStartingPools fills
     * scenario defaults.
     *
     * Parameters:
     *   playerId — stable empire index (0 = first human/AI seat).
     *
     * Returns: Player with role "neutral" and zeroed pools.
     */
    Player(int64 playerId) {
        id = playerId
        role = "neutral"
        wealth = 0.0
        resources = 0.0
        tech = 0.0
        power = 0.0
        experience = 0.0
        detectionRange = 0.0
        present = true
    }

    /*
     * Fill empire pools and detection range from a scenario.
     *
     * Purpose: apply §14 starting stocks once at game start so
     * unit tests can assert empire-pool-only seeding.
     *
     * Parameters:
     *   scenario — setup snapshot with startWealth / startTech / …
     *
     * Returns: nothing; mutates this player in place.
     */
    void applyStartingPools(Scenario scenario) {
        wealth = scenario.startWealth
        resources = scenario.startResources
        tech = scenario.startTech
        power = scenario.startPower
        experience = scenario.startExperience
        detectionRange = scenario.detectionRange(tech)
    }
}
