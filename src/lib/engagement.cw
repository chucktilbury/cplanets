/*
 * src/lib/engagement.cw — open combat instance (Phase D1).
 *
 * One planet defense fight (RULES §11 / §12). Midpoint ambush
 * engagements reuse this shape in D3/D4; D1 only opens at rocks.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial planet engagement for take defense.
 */

/*
 * Engagement is one open comparative-strength fight.
 *
 * planetId is the defended rock (−1 reserved for later midpoint).
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
    int64 ticksOpen
    bool open

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
        ticksOpen = 0
        open = false
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
