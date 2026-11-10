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
 *   2026-11-07  afkProductionScale for AFK timeout shrink wire-up.
 *   2026-11-08  homeGranted: home spawned on seat connect, not at
 *               scenario start.
 *   2026-11-08  markReseated clears drop when a free seat is
 *               reassigned on a new connect.
 *   2026-11-10  displayName: seat display name (CPL-106).
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
    # Operator-facing seat label (human config or AI proper name).
    # Empty until PUT /name or offline fixture sets it; label()
    # falls back to "Player {id}".
    String displayName
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
    # True once this seat's home yard and starter scout fleet were
    # created on connect/handshake (every seat; RULES §2). Unseated
    # seats are not living for eliminate-all and are not eliminated
    # for zero planets.
    bool homeGranted
    int64 partitionId
    list knownCompetitors
    # Multiplier on productive gains; GameDriver sets this from
    # afk_timeout_seconds / afk_shrink_factor (default 1.0 = no-op).
    fp64 afkProductionScale

    /*
     * Construct a player with neutral role and empty pools.
     *
     * Purpose: allocate a seat before applyStartingPools fills
     * scenario defaults. Home is deferred until connect.
     *
     * Parameters:
     *   playerId — stable empire index (0 = first human/AI seat).
     *
     * Returns: Player with role "neutral" and zeroed pools.
     */
    Player(int64 playerId) {
        id = playerId
        displayName = ""
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
        homeGranted = false
        partitionId = playerId
        knownCompetitors = []
        afkProductionScale = 1.0
    }

    /*
     * Effective chrome / digest label for this seat.
     *
     * Purpose: prefer the configured or assigned displayName;
     * fall back to a stable "Player {id}" so lists never show a
     * blank identity before PUT /name arrives.
     *
     * Parameters: none.
     *
     * Returns: non-empty display string.
     */
    String label() {
        if (displayName.length > 0) {
            return(displayName)
        }
        return(format("Player {}", id))
    }

    /*
     * Set the seat display name from client config / spawn.
     *
     * Purpose: human clients send their config display_name; AI
     * clients send a proper name (config or random pool). Empty
     * input is ignored so a blank PUT cannot wipe a prior label.
     *
     * Parameters:
     *   name — trimmed display name (non-empty to apply).
     *
     * Returns: true when the stored name changed.
     */
    bool setDisplayName(String name) {
        String trimmed = name.trim()
        if (trimmed.length < 1) {
            return(false)
        }
        if (displayName.equals(trimmed)) {
            return(false)
        }
        displayName = trimmed
        return(true)
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

    /*
     * Clear drop flags when a free seat is seated again.
     *
     * Purpose: v1 reconnect assigns free never-seated or free
     * dropped seats to new connects (no identity reclaim). A
     * dropped seat that is allocated again becomes a live
     * participant; quit seats are never reallocated.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void markReseated() {
        dropped = false
        present = true
        quit = false
    }
}
