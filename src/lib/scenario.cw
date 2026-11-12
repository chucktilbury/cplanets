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
 *   2026-11-07  Server verbosity (0 quiet / 1 settings / 2+ combat).
 *   2026-11-07  Verbosity 0–10 scale; clampVerbosity (clamp, not reject).
 *   2026-11-07  Externalize production/build/galaxy/design template
 *               knobs (same placeholder magnitudes as prior literals).
 *   2026-11-11  yardBuildExtraHullTimeFrac — per-hull-over-1 build
 *               time factor (CPL-111, default 0.10).
 *   2026-11-11  CPL-112: rare mineral weight, access spawn band /
 *               floor, habitability base ticks + wealth cost.
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
    # Extra fraction of base yard_build_ticks charged per hull
    # beyond the first in one PUT /build qty (CPL-111). 0.10 →
    # qty 2 costs 110% of one-hull ticks (rounded up, min 1).
    fp64 yardBuildExtraHullTimeFrac
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

    # Production / yard / design cost bases (former literals).
    fp64 productionTickRate
    fp64 yardBuildCostPerSize
    fp64 designDevelopCostPerSize
    fp64 colonyHopFraction

    # Galaxy spawn fractions / fallbacks (former galaxy.cw literals).
    fp64 homeSpawnMinRadiusFraction
    fp64 homeSpawnMaxRadiusFraction
    fp64 homeSpawnMinRadiusFloor
    fp64 usefulLivabilityFraction
    fp64 poorLivabilityFraction
    fp64 poorResourcesFraction
    fp64 homeFallbackLivability
    fp64 homeFallbackResources
    fp64 contactReach

    # CPL-112 planetary resource / accessibility knobs.
    # industry composite = common + rare * rareMineralWeight.
    fp64 rareMineralWeight
    # Spawn accessibility uniform in [accessMin, accessMax].
    fp64 accessMin
    fp64 accessMax
    # Floor for 1/access difficulty (never divide by zero).
    fp64 accessFloor
    # Colony terraforming: ticks and wealth × habit difficulty.
    int64 habitBaseTicks
    fp64 habitBaseWealthCost

    # Default hull template magnitudes (former design.cw make* literals).
    fp64 designScoutSpeed
    fp64 designScoutSize
    fp64 designColonySpeed
    fp64 designColonySize
    fp64 designColonyHold
    fp64 designFreighterSpeed
    fp64 designFreighterSize
    fp64 designFreighterHold
    fp64 designEscortSpeed
    fp64 designEscortSize
    fp64 designFrigateSpeed
    fp64 designFrigateSize
    fp64 designDestroyerSpeed
    fp64 designDestroyerSize

    fp64 livabilityInternalMin
    fp64 livabilityInternalMax
    int64 livabilityDisplayMin
    int64 livabilityDisplayMax

    fp64 startWealth
    fp64 startResources
    fp64 startTech
    fp64 startPower
    fp64 startExperience

    # Headless server stdout logging (operators / debug). Not a
    # balance magnitude. Scale 0–10 (clamped). CLI --verbosity may
    # overlay after load. Provisional: 0 errors only, 3+ settings,
    # 6+ combat, 10 full dumps (see ServerVerboseLog).
    int64 verbosity

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
        yardBuildExtraHullTimeFrac = 0.10
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

        productionTickRate = 0.01
        yardBuildCostPerSize = 10.0
        designDevelopCostPerSize = 50.0
        colonyHopFraction = 0.5

        homeSpawnMinRadiusFraction = 0.25
        homeSpawnMaxRadiusFraction = 0.95
        homeSpawnMinRadiusFloor = 0.5
        usefulLivabilityFraction = 0.6
        poorLivabilityFraction = 0.2
        poorResourcesFraction = 0.5
        homeFallbackLivability = 50.0
        homeFallbackResources = 50.0
        contactReach = 4.0

        rareMineralWeight = 2.0
        accessMin = 0.35
        accessMax = 1.0
        accessFloor = 0.20
        habitBaseTicks = 1
        habitBaseWealthCost = 25.0

        designScoutSpeed = 2.0
        designScoutSize = 0.5
        designColonySpeed = 1.0
        designColonySize = 5.0
        designColonyHold = 10.0
        designFreighterSpeed = 1.0
        designFreighterSize = 2.0
        designFreighterHold = 10.0
        designEscortSpeed = 1.5
        designEscortSize = 3.0
        designFrigateSpeed = 1.5
        designFrigateSize = 2.0
        designDestroyerSpeed = 1.0
        designDestroyerSize = 8.0

        livabilityInternalMin = 0.0
        livabilityInternalMax = 100.0
        livabilityDisplayMin = 1
        livabilityDisplayMax = 10

        startWealth = 1000.0
        startResources = 500.0
        startTech = 1.0
        startPower = 1.0
        startExperience = 0.0

        verbosity = 0
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
     * Clamp verbosity into the legal 0–10 band.
     *
     * Purpose: harden after text load or CLI overlay. Out-of-range
     * values clamp (not reject) while the ladder is provisional.
     *
     * Parameters: none (mutates this scenario).
     *
     * Returns: the clamped verbosity value.
     */
    int64 clampVerbosity() {
        if (verbosity < 0) {
            verbosity = 0
        } else (verbosity > 10) {
            verbosity = 10
        }
        return(verbosity)
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
     * Convert accessibility (0..1) into a cost/time difficulty.
     *
     * Purpose: CPL-112 — low access → more cost and longer extract
     * / terraform. difficulty = 1 / max(access, accessFloor).
     *
     * Parameters:
     *   access — raw accessibility in 0..1 (may be out of range).
     *
     * Returns: multiplier >= 1.0 when access <= 1; larger when hard.
     */
    fp64 accessDifficulty(fp64 access) {
        fp64 a = access
        if (a < 0.0) {
            a = 0.0
        }
        fp64 floor = accessFloor
        if (floor < 0.01) {
            floor = 0.01
        }
        if (a < floor) {
            a = floor
        }
        return(1.0 / a)
    }

    /*
     * Map accessibility 0..1 onto the human 1–10 display scale.
     *
     * Purpose: explored dialog / wire for CPL-112 access ratings
     * without a separate mapping table.
     *
     * Parameters:
     *   access — accessibility in 0..1.
     *
     * Returns: integer in the livability display band.
     */
    int64 displayAccess(fp64 access) {
        fp64 a = access
        if (a < 0.0) {
            a = 0.0
        }
        if (a > 1.0) {
            a = 1.0
        }
        return(displayLivability(a * livabilityInternalMax))
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
