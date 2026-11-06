/*
 * src/ai/tickSuggest.cw — tick period from AI reaction lag (H).
 *
 * Direction locked: AI lag may drive tick-period auto-config;
 * tick period stays setup-tunable (RULES §2 / §14 / PLAN §4.H).
 * Exact mapping magnitudes stay open — this helper uses wall
 * seconds first, then lag ticks as a fallback.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial suggestPeriodSeconds helper.
 */

include "../lib/scenario.cw"

/*
 * TickSuggest maps AI reaction lag onto a tick period.
 *
 * Used by Scenario.applyAiLagAutoConfig when the setup flag is
 * true. Explicit setup wins when the flag is false.
 */
class TickSuggest {
    /*
     * Construct a stateless suggester.
     *
     * Purpose: keep method comments on a class (CODING.md).
     *
     * Parameters: none.
     *
     * Returns: TickSuggest instance.
     */
    TickSuggest() {
    }

    /*
     * Suggest a tick period in seconds from scenario AI lag.
     *
     * Purpose: provisional auto-config mapping. Prefer
     * aiReactionLagSeconds (rounded); if that is zero, fall back
     * to aiReactionLagTicks treated as seconds. Always clamp to
     * the provisional 1–30 band.
     *
     * Parameters:
     *   scenario — setup snapshot with AI lag fields.
     *
     * Returns: int64 seconds in [1, 30].
     */
    int64 suggestPeriodSeconds(Scenario scenario) {
        int64 seconds = int64(scenario.aiReactionLagSeconds + 0.5)
        if (seconds < 1) {
            seconds = scenario.aiReactionLagTicks
        }
        if (seconds < 1) {
            seconds = 1
        } else (seconds > 30) {
            seconds = 30
        }
        return(seconds)
    }

    /*
     * Apply auto-config onto a scenario when the flag is set.
     *
     * Purpose: mutate tickPeriodSeconds from AI lag when
     * tickAutoConfigFromAiLag is true; leave it alone when false
     * (setup-tunable override path).
     *
     * Parameters:
     *   scenario — mutable setup snapshot.
     *
     * Returns: the tick period after the call (clamped).
     */
    int64 applyToScenario(Scenario scenario) {
        if (scenario.tickAutoConfigFromAiLag) {
            scenario.tickPeriodSeconds = suggestPeriodSeconds(
                scenario)
        }
        return(scenario.clampTickPeriod())
    }
}
