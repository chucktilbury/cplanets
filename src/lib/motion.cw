/*
 * src/lib/motion.cw — ETA decrement, arrivals, sit, stranded-N.
 *
 * RULES §7 steps 4, 6 (sit/arrive only), and 8 (stranded
 * countdown). Midpoint pirate, trade cycle, take/combat, and
 * pirate idle are Phase D stubs elsewhere.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial motion/arrive/stranded for tick core.
 */

include "event.cw"
include "fleet.cw"
include "planet.cw"

/*
 * Motion advances in-flight fleets and stranded countdowns.
 *
 * Arrivals in Phase C only sit on the destination rock — no take
 * ownership change, no trade bounce, no combat join.
 */
class Motion {
    /*
     * Construct a motion phase helper.
     *
     * Purpose: match other tick-phase objects.
     *
     * Parameters: none.
     *
     * Returns: Motion instance.
     */
    Motion() {
    }

    /*
     * Decrement ETA / move for every departed fleet.
     *
     * Purpose: RULES §7.4. Fleets with ETA already 0 (teleport)
     * stay at 0 for the arrivals pass.
     *
     * Parameters:
     *   fleets — mutable fleet list.
     *   events — event log (optional move marks).
     *
     * Returns: nothing.
     */
    void decrementEta(list fleets, list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.departed and not fleet.stranded) {
                if (fleet.eta > 0) {
                    fleet.eta = fleet.eta - 1
                    fleet.ticksTraveled = fleet.ticksTraveled + 1
                    fleets[index] = fleet
                    events.append(
                        TickEvent(
                            "move",
                            fleet.id,
                            fleet.destPlanetId,
                            fleet.ownerId,
                            fleet.eta))
                }
            }
            index = index + 1
        }
    }

    /*
     * Arrive fleets whose ETA has reached zero.
     *
     * Purpose: Phase C sit/move — land at dest and sit. Ownership
     * / colony / trade handling is Phase D.
     *
     * Parameters:
     *   planets — galaxy (bounds check only).
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void arrivals(list planets, list fleets, list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.departed and not fleet.stranded and fleet.eta <= 0) {
                if (fleet.destPlanetId >= 0
                    and fleet.destPlanetId < planets.length) {
                    fleet.locationPlanetId = fleet.destPlanetId
                }
                fleet.departed = false
                fleet.pendingDeparture = false
                fleet.becomeSitting()
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "arrive",
                        fleet.id,
                        fleet.locationPlanetId,
                        fleet.ownerId,
                        0))
            }
            index = index + 1
        }
    }

    /*
     * Tick down stranded countdowns; clear when zero.
     *
     * Purpose: after N ticks a stranded fleet can move again
     * (RULES §6 / §7.8). Pirate idle is not handled here.
     *
     * Parameters:
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void strandedCountdown(list fleets, list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.stranded) {
                if (fleet.strandedLeft > 0) {
                    fleet.strandedLeft = fleet.strandedLeft - 1
                }
                if (fleet.strandedLeft <= 0) {
                    fleet.stranded = false
                    fleet.strandedLeft = 0
                    events.append(
                        TickEvent(
                            "unstuck",
                            fleet.id,
                            fleet.locationPlanetId,
                            fleet.ownerId,
                            0))
                }
                fleets[index] = fleet
            }
            index = index + 1
        }
    }
}
