/*
 * src/lib/identify.cw — attack identify chance helpers (Phase D3).
 *
 * RULES §9 asymmetry: attacker advantage discovering who they
 * attack; defender fair chance discovering the attacker; separate
 * setup knobs; each side scales with that side's attributes.
 * Default audience of a successful defender identify is victim-
 * only (event playerId = victim).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial identify asymmetry helpers.
 */

include "player.cw"
include "rng.cw"
include "scenario.cw"

/*
 * Identify rolls attacker-side and defender-side discovery.
 *
 * Magnitudes stay scenario-owned; this helper only applies the
 * separate mappings and clamps to [0, 1].
 */
class Identify {
    /*
     * Construct a stateless identify helper.
     *
     * Purpose: match other tick-phase objects.
     *
     * Parameters: none.
     *
     * Returns: Identify instance.
     */
    Identify() {
    }

    /*
     * Clamp a probability into [0.0, 1.0].
     *
     * Purpose: keep rolls well-defined after attribute scaling.
     *
     * Parameters:
     *   chance — raw probability.
     *
     * Returns: chance clipped to [0, 1].
     */
    fp64 clamp01(fp64 chance) {
        if (chance < 0.0) {
            return(0.0)
        }
        if (chance > 1.0) {
            return(1.0)
        }
        return(chance)
    }

    /*
     * Relevant attribute used for identify scaling.
     *
     * Purpose: capability-scaled identify (RULES §9 / §13). Tech
     * is the locked visibility driver; power/experience remain
     * open as tick drivers and are not mixed in here.
     *
     * Parameters:
     *   seat — empire whose chance is being computed.
     *
     * Returns: attribute value for the per-attr coefficient.
     */
    fp64 attrFor(Player seat) {
        return(seat.tech)
    }

    /*
     * Attacker-side identify chance (advantage mapping).
     *
     * Purpose: separate attacker knobs — base + per-attr * tech
     * (RULES §9 / §14). Defaults keep attacker base above
     * defender base (scenario fixture).
     *
     * Parameters:
     *   scenario — identifyAttackerBase / PerAttr.
     *   attacker — attacking empire.
     *
     * Returns: probability in [0, 1].
     */
    fp64 attackerChance(Scenario scenario, Player attacker) {
        fp64 scaled = scenario.identifyAttackerPerAttr * attrFor(
            attacker)
        fp64 raw = scenario.identifyAttackerBase + scaled
        return(clamp01(raw))
    }

    /*
     * Defender-side identify chance (fair-chance mapping).
     *
     * Purpose: separate defender knobs — not collapsed into the
     * attacker mapping (RULES §9).
     *
     * Parameters:
     *   scenario — identifyDefenderBase / PerAttr.
     *   defender — defending / victim empire.
     *
     * Returns: probability in [0, 1].
     */
    fp64 defenderChance(Scenario scenario, Player defender) {
        fp64 scaled = scenario.identifyDefenderPerAttr * attrFor(
            defender)
        fp64 raw = scenario.identifyDefenderBase + scaled
        return(clamp01(raw))
    }

    /*
     * Roll whether the attacker learns the victim's identity.
     *
     * Purpose: seeded discover-who-I-attack check.
     *
     * Parameters:
     *   scenario — attacker knobs.
     *   attacker — attacking seat.
     *   rng — seeded stream (mutated).
     *
     * Returns: true when the roll succeeds.
     */
    bool rollAttacker(
        Scenario scenario,
        Player attacker,
        SeededRng rng) {
        fp64 chance = attackerChance(scenario, attacker)
        return(rng.nextFp01() < chance)
    }

    /*
     * Roll whether the defender learns the attacker's identity.
     *
     * Purpose: seeded fair-chance defender identify; caller emits
     * a victim-only audience event on success.
     *
     * Parameters:
     *   scenario — defender knobs.
     *   defender — victim seat.
     *   rng — seeded stream (mutated).
     *
     * Returns: true when the roll succeeds.
     */
    bool rollDefender(
        Scenario scenario,
        Player defender,
        SeededRng rng) {
        fp64 chance = defenderChance(scenario, defender)
        return(rng.nextFp01() < chance)
    }
}
