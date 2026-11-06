/*
 * src/lib/tick.cw — pure tick dispatcher (Phase C / D1–D5).
 *
 * Runs RULES §7 intra-tick order without a scheduler. D5 fills
 * contact (partition couple / known competitors) and closed /
 * all-humans-quit end checks. No TCP/SQLite yet (Phase E/F).
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
 *   2026-11-05  Phase D5: contact couple + end-game checks.
 */

include "confiscate.cw"
include "contact.cw"
include "dispatch.cw"
include "endgame.cw"
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
 * incremented by State. After run, read nextFleetIdOut,
 * nextEngagementIdOut, and end-game outs. No wall clock, no TCP.
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
    Contact contact
    EndGame endGame
    int64 nextFleetIdOut
    int64 nextEngagementIdOut
    bool endedOut
    String endReasonOut
    int64 winnerIdOut

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
        contact = Contact()
        endGame = EndGame()
        nextFleetIdOut = 1
        nextEngagementIdOut = 1
        endedOut = false
        endReasonOut = ""
        winnerIdOut = -1
    }

    /*
     * Advance the galaxy one tick; append events.
     *
     * Purpose: pure `tick(state…) → events` per PLAN §1 / RULES §7.
     * Order: production → cancel → depart → recall → move →
     * midpoint → arrive → confiscate → trade → take/combat open →
     * combat advance → stranded → pirate idle → contact → end.
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
     *   alreadyEnded — skip end checks when game already over.
     *
     * Returns: nothing; sets next*Out and end-game outs.
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
        int64 nextEngagementId,
        bool alreadyEnded) {
        endedOut = alreadyEnded
        endReasonOut = ""
        winnerIdOut = -1
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
        contact.run(planets, players, fleets, events)
        endGame.run(
            scenario,
            planets,
            players,
            events,
            alreadyEnded)
        endedOut = endGame.endedOut
        endReasonOut = endGame.endReasonOut
        winnerIdOut = endGame.winnerIdOut
        nextFleetIdOut = nextFleetId
        nextEngagementIdOut = nextEngagementId
    }
}
