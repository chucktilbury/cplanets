/*
 * src/unit_aiTickSuggest.cw — AI-lag → tick auto-config unit.
 *
 * Flag on: period comes from lag seconds (clamped). Flag off:
 * explicit tick_period_seconds wins (setup-tunable).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial tick-suggest unit program.
 */

include "ai/tickSuggest.cw"
include "lib/scenario.cw"

start {
    bool ok = true
    TickSuggest suggest = TickSuggest()

    Scenario autoOn = Scenario()
    autoOn.tickAutoConfigFromAiLag = true
    autoOn.aiReactionLagSeconds = 7.2
    autoOn.aiReactionLagTicks = 1
    autoOn.tickPeriodSeconds = 5
    int64 period = suggest.applyToScenario(autoOn)
    if (period != 7) {
        ok = false
    }
    if (autoOn.tickPeriodSeconds != 7) {
        ok = false
    }

    Scenario autoOff = Scenario()
    autoOff.tickAutoConfigFromAiLag = false
    autoOff.aiReactionLagSeconds = 9.0
    autoOff.tickPeriodSeconds = 11
    period = suggest.applyToScenario(autoOff)
    if (period != 11) {
        ok = false
    }

    Scenario clampHi = Scenario()
    clampHi.tickAutoConfigFromAiLag = true
    clampHi.aiReactionLagSeconds = 99.0
    period = suggest.applyToScenario(clampHi)
    if (period != 30) {
        ok = false
    }

    Scenario fromTicks = Scenario()
    fromTicks.tickAutoConfigFromAiLag = true
    fromTicks.aiReactionLagSeconds = 0.0
    fromTicks.aiReactionLagTicks = 4
    period = suggest.applyToScenario(fromTicks)
    if (period != 4) {
        ok = false
    }

    # Scenario helper path matches TickSuggest.
    Scenario direct = Scenario()
    direct.tickAutoConfigFromAiLag = true
    direct.aiReactionLagSeconds = 3.0
    direct.tickPeriodSeconds = 20
    if (direct.applyAiLagAutoConfig() != 3) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
