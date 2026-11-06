/*
 * src/lib/player.cw — empire pools and starting attributes (Phase B/D5).
 *
 * Stocks are an empire pool (RULES §2 / §3): wealth, resources, and
 * tech live on the player, not per-planet logistics. D5 adds
 * partition id, known competitors, human/quit/drop/eliminated.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial player / empire pool fields.
 *   2026-11-05  Phase D5: partition, competitors, quit/drop flags.
 */

include "scenario.cw"

/*
 * Player is one empire seat in the game state.
 *
 * Phase B fills starting pools from Scenario and computes the
 * initial detection/range from technology. D5 tracks sandbox
 * partition membership and known competitors after contact.
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
    bool human
    bool quit
    bool dropped
    bool eliminated
    int64 partitionId
    list knownCompetitors

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
        human = true
        quit = false
        dropped = false
        eliminated = false
        partitionId = playerId
        knownCompetitors = []
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

    /*
     * True when competitorId is already on the known list.
     *
     * Purpose: contact and message compose skip duplicates
     * (RULES §13).
     *
     * Parameters:
     *   competitorId — other empire id.
     *
     * Returns: true when already known.
     */
    bool knowsCompetitor(int64 competitorId) {
        int64 index = 0
        while (index < knownCompetitors.length) {
            int64 other = knownCompetitors[index]
            if (other == competitorId) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Add a competitor id when missing.
     *
     * Purpose: contact couples partitions into mutual known lists.
     *
     * Parameters:
     *   competitorId — other empire id (ignored when self / < 0).
     *
     * Returns: true when the id was newly appended.
     */
    bool addCompetitor(int64 competitorId) {
        if (competitorId < 0 or competitorId == id) {
            return(false)
        }
        if (knowsCompetitor(competitorId)) {
            return(false)
        }
        knownCompetitors.append(competitorId)
        return(true)
    }

    /*
     * Mark this seat as an AI client (not human).
     *
     * Purpose: all-humans-quit ignores AI seats (RULES §2 / §15).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void markAi() {
        human = false
    }

    /*
     * Mark a voluntary leave / quit.
     *
     * Purpose: session end for this human; last policy is irrelevant
     * once quit. All-humans-quit uses this flag.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void markQuit() {
        quit = true
        present = false
        dropped = false
    }

    /*
     * Mark a drop (lost contact) — zombie last-policy seat.
     *
     * Purpose: distinguish drop from AFK; zombie keeps last policy
     * and falls to normal play (RULES §2 / §15).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void markDrop() {
        dropped = true
        present = false
        quit = false
    }
}
