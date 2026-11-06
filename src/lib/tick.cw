/*
 * src/lib/tick.cw — pure tick dispatcher (Phase C / D1–D4).
 *
 * Runs RULES §7 intra-tick order without a scheduler. D4 fills
 * shared multi-tick combat, design/reclaim timing, confiscation
 * after attributed attack. AFK/contact stay later stubs.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial pure tick dispatcher.
 *   2026-11-05  Phase D1: take arrivals + combat advance.
 *   2026-11-05  Phase D2: tradeArrive before take.
 *   2026-11-05  Phase D3: midpoint ambush + pirate idle.
 *   2026-11-05  Phase D4: reclaim list, confiscation, capture rng.
 */

include "confiscate.cw"
include "dispatch.cw"
include "event.cw"
include "midpoint.cw"
include "motion.cw"
include "production.cw"
include "recall.cw"
include "rng.cw"
include "scenario.cw"
include "take.cw"
include "tradeArrive.cw"

/*
 * TickDriver owns one pure step over game lists.
 *
 * Callers pass scenario + mutable collections; tickCount is
 * incremented by State. After run, read nextFleetIdOut and
 * nextEngagementIdOut. No wall clock, no TCP, no SQLite.
 */
class TickDriver {
    Production production
    Recall recall
    Dispatch dispatch
    Motion motion
    Midpoint midpoint
    Confiscate confiscate
    TradeArrive tradeArrive
    Take take
    int64 nextFleetIdOut
    int64 nextEngagementIdOut

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
        midpoint = Midpoint()
        confiscate = Confiscate()
        tradeArrive = TradeArrive()
        take = Take()
        nextFleetIdOut = 1
        nextEngagementIdOut = 1
    }

    /*
     * Advance the galaxy one tick; append events.
     *
     * Purpose: pure `tick(state…) → events` per PLAN §1 / RULES §7.
     * Order: production → cancel → depart → recall → move →
     * midpoint → arrive → confiscate → trade → take/combat open →
     * combat advance → stranded → pirate idle → (afk stub).
     *
     * Parameters:
     *   scenario — setup knobs.
     *   planets — galaxy planets.
     *   players — empire seats.
     *   designs — hull templates.
     *   builds — yard BuildJob list.
     *   reclaims — yard ReclaimJob list.
     *   fleets — fleet list.
     *   engagements — open combat list.
     *   agreements — player–player trade pacts.
     *   arms — confiscation arms.
     *   events — empty list to fill.
     *   rng — seeded stream for identify / capture-use.
     *   nextFleetId — fleet id counter before yard completions.
     *   nextEngagementId — engagement id counter.
     *
     * Returns: nothing; sets nextFleetIdOut / nextEngagementIdOut.
     */
    void run(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list builds,
        list reclaims,
        list fleets,
        list engagements,
        list agreements,
        list arms,
        list events,
        SeededRng rng,
        int64 nextFleetId,
        int64 nextEngagementId) {
        nextFleetId = production.run(
            scenario,
            planets,
            players,
            designs,
            builds,
            reclaims,
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
        midpoint.run(
            scenario,
            players,
            designs,
            fleets,
            agreements,
            events,
            rng)
        motion.arrivals(planets, players, fleets, events)
        nextFleetId = confiscate.processArrivals(
            scenario,
            arms,
            planets,
            players,
            designs,
            fleets,
            events,
            rng,
            nextFleetId)
        tradeArrive.processArrivals(
            scenario,
            planets,
            players,
            designs,
            fleets,
            agreements,
            events)
        nextEngagementId = take.processArrivals(
            scenario,
            planets,
            designs,
            fleets,
            engagements,
            agreements,
            arms,
            events,
            rng,
            nextEngagementId,
            nextFleetId)
        nextFleetId = take.nextFleetIdOut
        nextFleetId = take.advanceEngagements(
            scenario,
            planets,
            designs,
            fleets,
            engagements,
            events,
            rng,
            nextFleetId)
        motion.strandedCountdown(fleets, events)
        midpoint.idleTimeout(scenario, players, fleets, events)
        # §7.9 AFK/contact — Phase F / D5.
        nextFleetIdOut = nextFleetId
        nextEngagementIdOut = nextEngagementId
    }
}
