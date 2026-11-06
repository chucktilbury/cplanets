/*
 * src/lib/recall.cw — cancel + in-flight recall (Phase C).
 *
 * Same-tick recall of a not-yet-departed order is cancellation
 * (no dispatch). Other recall turns toward the sender and
 * recomputes ETA (RULES §5.2 / §7.2–3). Combat participation of
 * recalling fleets is Phase D.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial cancel/recall phase for tick core.
 *   2026-11-05  Phase D4: recall from open engagement (still fights).
 */

include "event.cw"
include "fleet.cw"
include "player.cw"
include "scenario.cw"
include "travel.cw"

/*
 * Recall applies RULES §7 steps 2–3.
 *
 * Cancellations remove pending fleets without charging dispatch.
 * In-flight recalls retarget dest to sender and set return ETA.
 */
class Recall {
    Travel travel

    /*
     * Construct a recall phase with Travel for return ETA.
     *
     * Purpose: teleport-aware recallEta (RULES §5.2).
     *
     * Parameters: none.
     *
     * Returns: Recall ready for cancelPending / recallInFlight.
     */
    Recall() {
        travel = Travel()
    }

    /*
     * Cancel pending fleets that requested recall this tick.
     *
     * Purpose: same-tick recall = cancellation; no dispatch, no
     * loading (RULES §5.2 / §7.2). Hulls remain sitting at sender.
     *
     * Parameters:
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void cancelPending(list fleets, list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingDeparture and fleet.recallRequested) {
                int64 at = fleet.senderPlanetId
                fleet.locationPlanetId = at
                fleet.becomeSitting()
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "cancel",
                        fleet.id,
                        at,
                        fleet.ownerId,
                        0))
            }
            index = index + 1
        }
    }

    /*
     * Turn departed fleets with recall toward their sender.
     *
     * Purpose: RULES §7.3 — recompute return ETA from ticks
     * already spent (or 0 when tech teleports).
     *
     * Parameters:
     *   scenario — teleport mapping.
     *   players — technology attributes.
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void recallInFlight(
        Scenario scenario,
        list players,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.recallRequested
                and (fleet.departed
                    or (fleet.sitting and fleet.engagementId >= 0))) {
                if (fleet.ownerId < 0
                    or fleet.ownerId >= players.length) {
                    fleet.recallRequested = false
                    fleets[index] = fleet
                } else {
                    Player seat = players[fleet.ownerId]
                    int64 traveled = fleet.ticksTraveled
                    if (fleet.sitting and fleet.engagementId >= 0) {
                        traveled = 0
                    }
                    int64 back = travel.recallEta(
                        scenario,
                        seat,
                        traveled)
                    fleet.destPlanetId = fleet.senderPlanetId
                    fleet.eta = back
                    fleet.outboundEta = back
                    fleet.ticksTraveled = 0
                    fleet.order = "recall"
                    fleet.recallRequested = false
                    fleet.departed = true
                    fleet.pendingDeparture = false
                    fleet.sitting = false
                    fleets[index] = fleet
                    events.append(
                        TickEvent(
                            "recall",
                            fleet.id,
                            fleet.senderPlanetId,
                            fleet.ownerId,
                            back))
                }
            }
            index = index + 1
        }
    }
}
