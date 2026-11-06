/*
 * src/lib/tick.cw — pure tick dispatcher (Phase C).
 *
 * Runs RULES §7 intra-tick order without a scheduler. Phase D
 * steps (midpoint pirate, trade/take combat, pirate idle, AFK /
 * contact) are acknowledged no-ops so the sequence stays stable.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial pure tick dispatcher.
 */

include "dispatch.cw"
include "event.cw"
include "motion.cw"
include "production.cw"
include "recall.cw"
include "scenario.cw"

/*
 * TickDriver owns one pure step over game lists.
 *
 * Callers pass scenario + mutable collections; tickCount is
 * incremented here. No wall clock, no TCP, no SQLite.
 */
class TickDriver {
    Production production
    Recall recall
    Dispatch dispatch
    Motion motion

    /*
     * Construct the phase helpers used by one tick.
     *
     * Purpose: keep State.tick thin and the §7 order in one place.
     *
     * Parameters: none.
     *
     * Returns: TickDriver ready for run.
     */
    TickDriver() {
        production = Production()
        recall = Recall()
        dispatch = Dispatch()
        motion = Motion()
    }

    /*
     * Advance the galaxy one tick; append events.
     *
     * Purpose: pure `tick(state…) → events` per PLAN §1 / RULES §7.
     * Order: production → cancel → depart → recall → move →
     * (midpoint stub) → arrive → (combat stub) → stranded →
     * (afk/contact stub). Caller bumps tickCount.
     *
     * Parameters:
     *   scenario — setup knobs.
     *   planets — galaxy planets.
     *   players — empire seats.
     *   designs — hull templates.
     *   builds — yard BuildJob list.
     *   fleets — fleet list.
     *   events — empty list to fill.
     *   nextFleetId — fleet id counter before yard completions.
     *
     * Returns: updated nextFleetId after any new fleets.
     */
    int64 run(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list builds,
        list fleets,
        list events,
        int64 nextFleetId) {
        nextFleetId = production.run(
            scenario,
            planets,
            players,
            designs,
            builds,
            fleets,
            events,
            nextFleetId)
        recall.cancelPending(fleets, events)
        dispatch.run(
            scenario,
            planets,
            players,
            designs,
            fleets,
            events)
        recall.recallInFlight(scenario, players, fleets, events)
        motion.decrementEta(fleets, events)
        # §7.5 midpoint pirate / passer — Phase D.
        motion.arrivals(planets, fleets, events)
        # §7.7 ongoing combat — Phase D.
        motion.strandedCountdown(fleets, events)
        # §7.8 pirate idle + §7.9 AFK/contact — Phase D / F.
        return(nextFleetId)
    }
}
