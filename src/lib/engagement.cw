/*
 * src/lib/engagement.cw — open combat instance (Phase D1 / D4).
 *
 * One comparative-strength fight at a planet or (later) midpoint
 * edge (RULES §11 / §12). D4 keeps planet fights multi-tick with
 * participant tagging on fleets.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial planet engagement for take defense.
 *   2026-11-05  Phase D4: midpoint edge fields (reserved).
 */

/*
 * Engagement is one open comparative-strength fight.
 *
 * planetId is the defended rock (−1 reserved for midpoint).
 * attackerFleetId is the take fleet that opened or joined. open
 * stays true until combat resolves ownership.
 */
class Engagement {
    int64 id
    int64 planetId
    int64 attackerFleetId
    int64 attackerOwnerId
    int64 defenderOwnerId
    fp64 attackerStrengthLeft
    fp64 defenderStrengthLeft
    fp64 planetaryDefenseLeft
    int64 ticksOpen
    bool open
    int64 edgeLo
    int64 edgeHi

    /*
     * Construct a closed empty engagement slot.
     *
     * Purpose: allocate before Combat.openAtPlanet fills sides.
     *
     * Parameters:
     *   engagementId — stable id in the state engagement list.
     *
     * Returns: Engagement with open == false.
     */
    Engagement(int64 engagementId) {
        id = engagementId
        planetId = -1
        attackerFleetId = -1
        attackerOwnerId = -1
        defenderOwnerId = -1
        attackerStrengthLeft = 0.0
        defenderStrengthLeft = 0.0
        planetaryDefenseLeft = 0.0
        ticksOpen = 0
        open = false
        edgeLo = -1
        edgeHi = -1
    }

    /*
     * Open this slot as a planet defense fight.
     *
     * Purpose: record sides and starting strengths for multi-tick
     * advance (RULES §12).
     *
     * Parameters:
     *   planet — defended rock id.
     *   fleet — attacking take fleet id.
     *   attacker — attacking empire id.
     *   defender — defending empire id.
     *   atk — starting attacker comparative strength.
     *   defn — starting defender comparative strength.
     *
     * Returns: nothing; mutates this Engagement.
     */
    void openPlanet(
        int64 planet,
        int64 fleet,
        int64 attacker,
        int64 defender,
        fp64 atk,
        fp64 defn) {
        planetId = planet
        attackerFleetId = fleet
        attackerOwnerId = attacker
        defenderOwnerId = defender
        attackerStrengthLeft = atk
        defenderStrengthLeft = defn
        planetaryDefenseLeft = 0.0
        ticksOpen = 0
        open = true
        edgeLo = -1
        edgeHi = -1
    }

    /*
     * Open this slot as a midpoint engagement.
     *
     * Purpose: shared multi-tick machine for close ambush fights
     * when the strength gap does not short-circuit (RULES §7.5).
     *
     * Parameters:
     *   lo / hi — undirected edge endpoints.
     *   fleet — initiating fleet id.
     *   attacker — one side owner.
     *   defender — other side owner.
     *   atk / defn — starting strengths.
     *
     * Returns: nothing; mutates this Engagement.
     */
    void openMidpoint(
        int64 lo,
        int64 hi,
        int64 fleet,
        int64 attacker,
        int64 defender,
        fp64 atk,
        fp64 defn) {
        planetId = -1
        edgeLo = lo
        edgeHi = hi
        attackerFleetId = fleet
        attackerOwnerId = attacker
        defenderOwnerId = defender
        attackerStrengthLeft = atk
        defenderStrengthLeft = defn
        planetaryDefenseLeft = 0.0
        ticksOpen = 0
        open = true
    }

    /*
     * Mark this engagement resolved.
     *
     * Purpose: stop further advance ticks after a side collapses.
     *
     * Parameters: none.
     *
     * Returns: nothing; sets open false.
     */
    void close() {
        open = false
    }
}
