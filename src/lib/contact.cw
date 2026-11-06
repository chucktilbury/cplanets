/*
 * src/lib/contact.cw — partitions, explore, known competitors (D5).
 *
 * Contact (explore and/or conquest of another partition) couples
 * sandboxes and adds empires to known competitors (RULES §2 / §13
 * / §7.9). Empire pools stay on the player; this file does not
 * invent per-planet stocks.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial contact / partition coupling for Phase D5.
 */

include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"

/*
 * Contact resolves explore arrivals and couples partitions.
 *
 * Runs late in the tick (§7.9) after take/combat so conquest
 * ownership is already visible when scanning for cross-partition
 * contact.
 */
class Contact {
    /*
     * Construct a stateless contact helper.
     *
     * Purpose: match other tick phase objects owned by TickDriver.
     *
     * Parameters: none.
     *
     * Returns: Contact ready for run.
     */
    Contact() {
    }

    /*
     * Process explore arrivals and couple foreign partitions.
     *
     * Purpose: reveal quality on explore; couple sandboxes when a
     * player explores or owns a rock in another partition; emit
     * contact events (RULES §7.9 / §13).
     *
     * Parameters:
     *   planets — galaxy rocks (partitionId / qualityKnown).
     *   players — empire seats (partitionId / knownCompetitors).
     *   fleets — mutable fleet list (explore pendingArrivalOrder).
     *   events — tick log.
     *
     * Returns: nothing.
     */
    void run(
        list planets,
        list players,
        list fleets,
        list events) {
        handleExploreArrivals(planets, players, fleets, events)
        coupleOwnedForeignPartitions(planets, players, events)
    }

    /*
     * Reveal quality for arriving explore fleets and couple.
     *
     * Purpose: explore makes quality known without a take; contact
     * still couples the rock's partition (RULES §13).
     *
     * Parameters:
     *   planets — mutable planet list.
     *   players — mutable seats.
     *   fleets — mutable fleets.
     *   events — log.
     *
     * Returns: nothing.
     */
    void handleExploreArrivals(
        list planets,
        list players,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingArrivalOrder.equals("explore")) {
                if (fleet.locationPlanetId >= 0
                    and fleet.locationPlanetId < planets.length) {
                    Planet rock = planets[fleet.locationPlanetId]
                    rock.qualityKnown = true
                    planets[fleet.locationPlanetId] = rock
                    events.append(
                        TickEvent(
                            "explore",
                            fleet.id,
                            rock.id,
                            fleet.ownerId,
                            0))
                    couplePlayerToPartition(
                        planets,
                        players,
                        events,
                        fleet.ownerId,
                        rock.partitionId)
                }
                fleet.pendingArrivalOrder = ""
                fleets[index] = fleet
            }
            index = index + 1
        }
    }

    /*
     * Couple when a player owns a rock outside their partition.
     *
     * Purpose: conquest contact — take already set ownerId; scan
     * possessions for foreign partitionIds (RULES §2 / §13).
     *
     * Parameters:
     *   planets — galaxy.
     *   players — seats.
     *   events — log.
     *
     * Returns: nothing.
     */
    void coupleOwnedForeignPartitions(
        list planets,
        list players,
        list events) {
        int64 p = 0
        while (p < planets.length) {
            Planet rock = planets[p]
            if (rock.ownerId >= 0 and rock.ownerId < players.length) {
                Player seat = players[rock.ownerId]
                if (rock.partitionId != seat.partitionId) {
                    couplePlayerToPartition(
                        planets,
                        players,
                        events,
                        rock.ownerId,
                        rock.partitionId)
                }
            }
            p = p + 1
        }
    }

    /*
     * Merge one player's partition with a foreign partition id.
     *
     * Purpose: remap planets/players onto the surviving partition
     * (lower id) and mark every pair across the old groups as
     * known competitors.
     *
     * Parameters:
     *   planets — mutable rocks.
     *   players — mutable seats.
     *   events — log.
     *   playerId — empire making contact.
     *   foreignPartition — partition id being contacted.
     *
     * Returns: nothing.
     */
    void couplePlayerToPartition(
        list planets,
        list players,
        list events,
        int64 playerId,
        int64 foreignPartition) {
        if (playerId < 0 or playerId >= players.length) {
            return()
        }
        Player seat = players[playerId]
        int64 homePart = seat.partitionId
        if (foreignPartition < 0 or foreignPartition == homePart) {
            return()
        }
        int64 keep = homePart
        int64 drop = foreignPartition
        if (drop < keep) {
            keep = foreignPartition
            drop = homePart
        }
        remapPartition(planets, players, drop, keep)
        introducePartitions(players, events, keep, playerId)
    }

    /*
     * Remap every planet/player on dropPartition onto keepPartition.
     *
     * Purpose: couple sandboxes into one partition id after contact.
     *
     * Parameters:
     *   planets — mutable rocks.
     *   players — mutable seats.
     *   dropPartition — id being retired.
     *   keepPartition — surviving id.
     *
     * Returns: nothing.
     */
    void remapPartition(
        list planets,
        list players,
        int64 dropPartition,
        int64 keepPartition) {
        int64 i = 0
        while (i < planets.length) {
            Planet rock = planets[i]
            if (rock.partitionId == dropPartition) {
                rock.partitionId = keepPartition
                planets[i] = rock
            }
            i = i + 1
        }
        int64 j = 0
        while (j < players.length) {
            Player seat = players[j]
            if (seat.partitionId == dropPartition) {
                seat.partitionId = keepPartition
                players[j] = seat
            }
            j = j + 1
        }
    }

    /*
     * Add known-competitor links for everyone now in keepPartition.
     *
     * Purpose: after a merge, every pair of living seats that share
     * the partition know each other (RULES §13). Emits one contact
     * event for the player who triggered the merge.
     *
     * Parameters:
     *   players — mutable seats.
     *   events — log.
     *   keepPartition — coupled partition id.
     *   triggerPlayerId — seat that caused contact.
     *
     * Returns: nothing.
     */
    void introducePartitions(
        list players,
        list events,
        int64 keepPartition,
        int64 triggerPlayerId) {
        int64 a = 0
        while (a < players.length) {
            Player left = players[a]
            if (left.partitionId == keepPartition
                and not left.eliminated) {
                int64 b = a + 1
                while (b < players.length) {
                    Player right = players[b]
                    if (right.partitionId == keepPartition
                        and not right.eliminated) {
                        bool grew = false
                        if (left.addCompetitor(right.id)) {
                            grew = true
                        }
                        if (right.addCompetitor(left.id)) {
                            grew = true
                        }
                        players[a] = left
                        players[b] = right
                        if (grew) {
                            events.append(
                                TickEvent(
                                    "contact",
                                    -1,
                                    -1,
                                    triggerPlayerId,
                                    right.id))
                        }
                        left = players[a]
                    }
                    b = b + 1
                }
            }
            a = a + 1
        }
    }
}
