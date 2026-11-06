/*
 * tests/unit/unit_scenarioFixture.cw — closed default names every §14 knob.
 *
 * Asserts closed mode, tick period in 1–30, separate identify
 * attacker/defender knobs, tech→range/teleport, battle coeffs,
 * livability 1–10 mapping, and related placeholders (PLAN §4.B).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial closed-fixture unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/scenario.cw"

start {
    Scenario s = Scenario()
    s.clampTickPeriod()
    bool ok = true
    if (not s.isClosed()) {
        ok = false
    }
    if (s.tickPeriodSeconds < 1 or s.tickPeriodSeconds > 30) {
        ok = false
    }
    if (not s.tickAutoConfigFromAiLag) {
        ok = false
    }
    if (s.aiReactionLagTicks < 0) {
        ok = false
    }
    if (s.aiReactionLagSeconds < 0.0) {
        ok = false
    }
    if (s.afkTimeoutSeconds < 0.0) {
        ok = false
    }
    if (s.worldCount < 1) {
        ok = false
    }
    if (s.usefulMix < 0.0 or s.usefulMix > 1.0) {
        ok = false
    }
    if (s.scoutRange <= 0.0) {
        ok = false
    }
    if (s.identifyAttackerBase < 0.0) {
        ok = false
    }
    if (s.identifyDefenderBase < 0.0) {
        ok = false
    }
    if (s.identifyAttackerBase <= s.identifyDefenderBase) {
        # attacker advantage is the locked direction; placeholders
        # keep attacker base above defender base.
        ok = false
    }
    if (s.techRangeBase <= 0.0) {
        ok = false
    }
    if (s.techTeleportThreshold <= 0.0) {
        ok = false
    }
    if (not s.techTeleportEnabled) {
        ok = false
    }
    if (s.designDevelopTicks < 1 or s.yardBuildTicks < 1) {
        ok = false
    }
    if (s.reclaimPercent < 0.0 or s.captureUseChance < 0.0) {
        ok = false
    }
    if (s.strandedTicksN < 0 or s.pirateIdleTicks < 0) {
        ok = false
    }
    if (s.battleStrengthDurationCoeff <= 0.0) {
        ok = false
    }
    if (s.productiveInherentDefense <= 0.0) {
        ok = false
    }
    if (s.livabilityDisplayMin != 1 or s.livabilityDisplayMax != 10) {
        ok = false
    }
    int64 low = s.displayLivability(s.livabilityInternalMin)
    int64 high = s.displayLivability(s.livabilityInternalMax)
    int64 mid = s.displayLivability(
        (s.livabilityInternalMin + s.livabilityInternalMax) / 2.0)
    if (low != 1 or high != 10) {
        ok = false
    }
    if (mid < 1 or mid > 10) {
        ok = false
    }
    if (s.detectionRange(s.startTech) <= 0.0) {
        ok = false
    }
    if (s.teleports(s.techTeleportThreshold) != true) {
        ok = false
    }
    if (s.teleports(0.0) != false) {
        ok = false
    }
    s.tickPeriodSeconds = 0
    if (s.clampTickPeriod() != 1) {
        ok = false
    }
    s.tickPeriodSeconds = 99
    if (s.clampTickPeriod() != 30) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
