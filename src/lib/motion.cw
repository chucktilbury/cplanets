/*
 * src/lib/motion.cw — ETA decrement, arrivals, sit, stranded-N.
 *
 * RULES §7 steps 4, 6 (land/sit), and 8 (stranded countdown).
 * Take/occupy and trade cycle run after arrivals (D1 / D2).
 * Ambush fleets in position do not land; loot credits on return
 * to sender (Phase D3 / RULES §10).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial motion/arrive/stranded for tick core.
 *   2026-11-05  Phase D1: landAndSit preserves arrival order.
 *   2026-11-05  Phase D2: tradeArrive consumes trade landings.
 *   2026-11-05  Phase D3: skip ambush wait; credit loot on return.
 *   2026-11-05  Phase D4: engaged fleets stay until fight ends.
 */

include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"

/*
 * Motion advances in-flight fleets and stranded countdowns.
 *
 * Arrivals land and sit, recording pendingArrivalOrder so Take
 * (and later trade) can resolve the order that arrived.
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
            if (fleet.departed
                and not fleet.stranded
                and fleet.engagementId < 0) {
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
     * Purpose: land at dest, sit, and stash the arrival order for
     * Take/trade handlers in the same tick (RULES §7.6). Ambush
     * fleets waiting in position never land here (§6 / §10).
     * Pirate loot credits when landing at the sender.
     *
     * Parameters:
     *   planets — galaxy (bounds check only).
     *   players — empire pools for loot credit.
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void arrivals(
        list planets,
        list players,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.departed
                and not fleet.stranded
                and not fleet.ambushInPosition
                and not fleet.order.equals("ambush")
                and fleet.eta <= 0) {
                int64 landAt = fleet.destPlanetId
                int64 sender = fleet.senderPlanetId
                if (landAt >= 0 and landAt < planets.length) {
                    fleet.landAndSit()
                } else {
                    fleet.departed = false
                    fleet.pendingDeparture = false
                    fleet.becomeSitting()
                }
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "arrive",
                        fleet.id,
                        fleet.locationPlanetId,
                        fleet.ownerId,
                        0))
                if (landAt == sender and fleet.hasLoot()) {
                    creditLoot(players, fleets, events, index)
                }
            }
            index = index + 1
        }
    }

    /*
     * Credit riding loot into the owner's empire pools.
     *
     * Purpose: RULES §10 — loot collected when the pirate (or
     * non-pirate carrier) returns to sender.
     *
     * Parameters:
     *   players — mutable seats.
     *   fleets — mutable list.
     *   events — log.
     *   index — fleet index with loot.
     *
     * Returns: nothing.
     */
    void creditLoot(
        list players,
        list fleets,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            fleet.lootWealth = 0.0
            fleet.lootResources = 0.0
            fleets[index] = fleet
            return()
        }
        Player seat = players[fleet.ownerId]
        seat.wealth = seat.wealth + fleet.lootWealth
        seat.resources = seat.resources + fleet.lootResources
        players[fleet.ownerId] = seat
        int64 credited = int64(fleet.lootWealth)
        events.append(
            TickEvent(
                "loot_credit",
                fleet.id,
                fleet.locationPlanetId,
                fleet.ownerId,
                credited))
        fleet.lootWealth = 0.0
        fleet.lootResources = 0.0
        fleets[index] = fleet
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
