/*
 * src/lib/scenario.cw — scenario setup knobs (Phase B).
 *
 * Holds every RULES §14 named coefficient / mapping for the closed
 * default fixture. Magnitudes are placeholders for post-complete
 * tuning; combat/production stay outside code. Immutable after the
 * game locks (State.locked).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial §14 knob surface + closed defaults.
 *   2026-11-05  Phase H: applyAiLagAutoConfig helper.
 */

/*
 * Scenario is the setup snapshot for one game instance.
 *
 * Defaults match the closed v1 fixture (scenarioMode = closed,
 * tick period in the provisional 1–30s band). Loaders overlay
 * application-text keys onto a fresh Scenario().
 */
class Scenario {
    String scenarioMode
    int64 tickPeriodSeconds
    bool tickAutoConfigFromAiLag
    int64 aiReactionLagTicks
    fp64 aiReactionLagSeconds
    fp64 afkTimeoutSeconds
    fp64 afkShrinkFactor

    int64 worldCount
    fp64 usefulMix
    fp64 scoutRange
    fp64 galaxyRadius

    fp64 identifyAttackerBase
    fp64 identifyAttackerPerAttr
    fp64 identifyDefenderBase
    fp64 identifyDefenderPerAttr

    fp64 techRangeBase
    fp64 techRangePerTech
    fp64 techTeleportThreshold
    bool techTeleportEnabled

    int64 designDevelopTicks
    int64 yardBuildTicks
    fp64 designSpeedCostCoeff
    fp64 designRangeCostCoeff

    fp64 reclaimPercent
    fp64 captureUseChance
    fp64 coverFactor
    fp64 voyageCost
    int64 pirateIdleTicks
    int64 strandedTicksN
    fp64 tradeBump
    fp64 attackBump
    fp64 dispatchWeightScout
    fp64 dispatchWeightColony
    fp64 pirateAttrition
    fp64 pirateLeftover
    fp64 battleStrengthDurationCoeff
    fp64 battleShortCircuitGap
    fp64 productiveInherentDefense

    fp64 livabilityInternalMin
    fp64 livabilityInternalMax
    int64 livabilityDisplayMin
    int64 livabilityDisplayMax

    fp64 startWealth
    fp64 startResources
    fp64 startTech
    fp64 startPower
    fp64 startExperience

    /*
     * Construct the closed-scenario default fixture.
     *
     * Purpose: name every §14 knob with a placeholder magnitude so
     * tests and loaders share one baseline (PLAN §4.B).
     *
     * Parameters: none.
     *
     * Returns: Scenario with scenarioMode "closed" and tick period
     * inside the provisional 1–30s band.
     */
    Scenario() {
        scenarioMode = "closed"
        tickPeriodSeconds = 5
        tickAutoConfigFromAiLag = true
        aiReactionLagTicks = 1
        # Match tick period so auto-config is a no-op on the
        # closed default; still setup-tunable when the flag is off.
        aiReactionLagSeconds = 5.0
        afkTimeoutSeconds = 120.0
        afkShrinkFactor = 1.0

        worldCount = 24
        usefulMix = 0.35
        scoutRange = 3.0
        galaxyRadius = 20.0

        identifyAttackerBase = 0.35
        identifyAttackerPerAttr = 0.05
        identifyDefenderBase = 0.20
        identifyDefenderPerAttr = 0.04

        techRangeBase = 3.0
        techRangePerTech = 0.5
        techTeleportThreshold = 10.0
        techTeleportEnabled = true

        designDevelopTicks = 5
        yardBuildTicks = 3
        designSpeedCostCoeff = 1.0
        designRangeCostCoeff = 1.0

        reclaimPercent = 0.50
        captureUseChance = 0.25
        coverFactor = 1.0
        voyageCost = 0.0
        pirateIdleTicks = 10
        strandedTicksN = 5
        tradeBump = 1.20
        attackBump = 1.0
        dispatchWeightScout = 0.1
        dispatchWeightColony = 5.0
        pirateAttrition = 0.30
        pirateLeftover = 0.05
        battleStrengthDurationCoeff = 1.0
        battleShortCircuitGap = 3.0
        productiveInherentDefense = 1.0

        livabilityInternalMin = 0.0
        livabilityInternalMax = 100.0
        livabilityDisplayMin = 1
        livabilityDisplayMax = 10

        startWealth = 1000.0
        startResources = 500.0
        startTech = 1.0
        startPower = 1.0
        startExperience = 0.0
    }

    /*
     * Clamp tickPeriodSeconds into the provisional 1–30 band.
     *
     * Purpose: enforce RULES §2 / §14 provisional range after a
     * text load or admin edit, without inventing a permanent law.
     *
     * Parameters: none (mutates this scenario).
     *
     * Returns: the clamped tickPeriodSeconds value.
     */
    int64 clampTickPeriod() {
        if (tickPeriodSeconds < 1) {
            tickPeriodSeconds = 1
        } else (tickPeriodSeconds > 30) {
            tickPeriodSeconds = 30
        }
        return(tickPeriodSeconds)
    }

    /*
     * Optionally rewrite tick period from AI reaction lag.
     *
     * Purpose: RULES §2 / §14 — tick period may auto-config from
     * AI lag; remains setup-tunable when the flag is false.
     * Provisional mapping: round aiReactionLagSeconds (fallback
     * to aiReactionLagTicks as seconds), then clamp 1–30.
     *
     * Parameters: none (mutates this scenario when flag is true).
     *
     * Returns: tickPeriodSeconds after auto-config / clamp.
     */
    int64 applyAiLagAutoConfig() {
        if (tickAutoConfigFromAiLag) {
            int64 seconds = int64(aiReactionLagSeconds + 0.5)
            if (seconds < 1) {
                seconds = aiReactionLagTicks
            }
            tickPeriodSeconds = seconds
        }
        return(clampTickPeriod())
    }

    /*
     * Map internal livability onto the human 1–10 display scale.
     *
     * Purpose: surface explored quality without inventing tick
     * drivers (RULES §13 / §14). Linear map; open magnitudes.
     *
     * Parameters:
     *   internal — raw livability in [min, max] setup units.
     *
     * Returns: integer in [livabilityDisplayMin, livabilityDisplayMax].
     */
    int64 displayLivability(fp64 internal) {
        fp64 lo = livabilityInternalMin
        fp64 hi = livabilityInternalMax
        fp64 span = hi - lo
        int64 dMin = livabilityDisplayMin
        int64 dMax = livabilityDisplayMax
        if (span <= 0.0) {
            return(dMin)
        }
        fp64 t = (internal - lo) / span
        if (t < 0.0) {
            t = 0.0
        } else (t > 1.0) {
            t = 1.0
        }
        fp64 scaled = fp64(dMin) + t * fp64(dMax - dMin)
        int64 rounded = int64(scaled + 0.5)
        if (rounded < dMin) {
            return(dMin)
        }
        if (rounded > dMax) {
            return(dMax)
        }
        return(rounded)
    }

    /*
     * Compute detection/range from a player's technology.
     *
     * Purpose: capability-scaled visibility (RULES §13). Exploration
     * reveals inside this range; it does not extend it.
     *
     * Parameters:
     *   tech — player technology attribute.
     *
     * Returns: range distance in galaxy units.
     */
    fp64 detectionRange(fp64 tech) {
        return(techRangeBase + techRangePerTech * tech)
    }

    /*
     * Whether technology is high enough for ETA-zero teleport.
     *
     * Purpose: expose the §6 / §14 tech→teleport threshold without
     * implementing travel math yet (Phase C).
     *
     * Parameters:
     *   tech — player technology attribute.
     *
     * Returns: true when teleport is enabled and tech meets the
     * setup threshold.
     */
    bool teleports(fp64 tech) {
        if (not techTeleportEnabled) {
            return(false)
        }
        return(tech >= techTeleportThreshold)
    }

    /*
     * True when this scenario is the closed eliminate-all mode.
     *
     * Purpose: let starters and tests branch on v1 default win
     * condition without string compares scattered around.
     *
     * Parameters: none.
     *
     * Returns: true if scenarioMode equals "closed".
     */
    bool isClosed() {
        return(scenarioMode.equals("closed"))
    }
}
