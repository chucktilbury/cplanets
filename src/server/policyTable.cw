/*
 * src/server/policyTable.cw — last policy per seat (Phase F).
 *
 * Clients PUT policy anytime; the driver snapshots these blobs at
 * tick fire. Missing updates leave the last blob (AFK = last
 * policy). No ready barrier (RULES §2 / PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial last-policy table.
 */

/*
 * PolicySlot holds one seat's last opaque policy blob.
 *
 * hasPolicy is false until the first PUT; AFK still holds the last
 * blob once set. tickUses counts how many cadence fires saw this
 * slot after the last PUT (idle metric for tests).
 */
class PolicySlot {
    int64 playerId
    buffer blob
    bool hasPolicy
    int64 tickUses

    /*
     * Construct an empty seat slot.
     *
     * Purpose: pre-size the table so PUT/snapshot index by
     * playerId without dictionary support gaps.
     *
     * Parameters:
     *   seat — empire id for this slot.
     *
     * Returns: PolicySlot with empty blob and hasPolicy false.
     */
    PolicySlot(int64 seat) {
        playerId = seat
        blob = buffer[]
        hasPolicy = false
        tickUses = 0
    }
}

/*
 * PolicyTable is the server-side last-policy map.
 *
 * Snapshot copies blobs for the tick; PUT updates one seat. Stays
 * out of lib (PLAN §2 — scheduling lives on the server).
 */
class PolicyTable {
    list slots

    /*
     * Construct an empty policy table.
     *
     * Purpose: fill later via ensureSeats after State start.
     *
     * Parameters: none.
     *
     * Returns: PolicyTable with no seats.
     */
    PolicyTable() {
        slots = []
    }

    /*
     * Grow the table to cover player ids 0..count-1.
     *
     * Purpose: match State.players length at game start. Existing
     * slots are kept; new seats get empty PolicySlot values.
     *
     * Parameters:
     *   count — number of empire seats.
     *
     * Returns: nothing.
     */
    void ensureSeats(int64 count) {
        while (slots.length < count) {
            slots.append(PolicySlot(slots.length))
        }
    }

    /*
     * Store a policy PUT for one seat.
     *
     * Purpose: primary client write; applies on the *next* tick
     * snapshot, not immediately as a barrier (RULES §2).
     *
     * Parameters:
     *   playerId — empire id.
     *   policyBlob — opaque policy bytes (may be empty).
     *
     * Returns: true when the seat exists and was updated.
     */
    bool put(int64 playerId, buffer policyBlob) {
        if (playerId < 0 or playerId >= slots.length) {
            return(false)
        }
        PolicySlot slot = slots[playerId]
        slot.blob = policyBlob
        slot.hasPolicy = true
        slot.tickUses = 0
        slots[playerId] = slot
        return(true)
    }

    /*
     * Read the last policy blob for a seat.
     *
     * Purpose: tick snapshot and GET helpers share one lookup.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: last blob, or empty buffer when missing / unknown.
     */
    buffer get(int64 playerId) {
        if (playerId < 0 or playerId >= slots.length) {
            return(buffer[])
        }
        PolicySlot slot = slots[playerId]
        return(slot.blob)
    }

    /*
     * True when the seat has ever received a PUT.
     *
     * Purpose: tests distinguish "no policy yet" from empty blob.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: hasPolicy flag, or false when out of range.
     */
    bool has(int64 playerId) {
        if (playerId < 0 or playerId >= slots.length) {
            return(false)
        }
        PolicySlot slot = slots[playerId]
        return(slot.hasPolicy)
    }

    /*
     * Snapshot every seat's current policy into a parallel list.
     *
     * Purpose: cadence fire captures AFK last-policy without a
     * ready barrier (PLAN §4.F item 2).
     *
     * Parameters: none.
     *
     * Returns: list of buffers, one per seat (may be empty).
     */
    list snapshot() {
        list out = []
        int64 index = 0
        while (index < slots.length) {
            PolicySlot slot = slots[index]
            out.append(slot.blob)
            slot.tickUses = slot.tickUses + 1
            slots[index] = slot
            index = index + 1
        }
        return(out)
    }
}
