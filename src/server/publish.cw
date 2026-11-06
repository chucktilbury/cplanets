/*
 * src/server/publish.cw — opaque state / digest blob codecs (F).
 *
 * Builds the published blobs returned by GET /state and
 * GET /digest after each cadence fire. Compact WireBytes layout;
 * not a full State object graph on the wire yet.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial publish blob encoders.
 */

include "../lib/event.cw"
include "../lib/state.cw"
include "../lib/wireBytes.cw"
include "policyTable.cw"

/*
 * PublishCodec packs published state and digest blobs.
 *
 * State blob: tick u32, ended u8, winner i32, playerCount u32,
 * then per player: id u32, wealth bits as i64 millicents, then
 * policyCount u32 and each policy length+bytes.
 *
 * Digest blob: tick u32, eventCount u32, then each event kind
 * string + fleet/planet/player/value u32s (value as i32 cast).
 */
class PublishCodec {
    /*
     * Construct a codec shell.
     *
     * Purpose: no retained state; methods are pure encoders.
     *
     * Parameters: none.
     *
     * Returns: PublishCodec instance.
     */
    PublishCodec() {
    }

    /*
     * Encode a published state blob from State + policies.
     *
     * Purpose: GET /state body after tick (PLAN §4.F item 2).
     *
     * Parameters:
     *   game — current State after tick.
     *   policies — last-policy table snapshot source.
     *
     * Returns: opaque buffer; empty on pack failure.
     */
    buffer encodeState(State game, PolicyTable policies) {
        WireBytes w = WireBytes()
        w.writeU32(game.tickCount)
        if (game.ended) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(game.winnerId + 1)
        w.writeU32(game.players.length)
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            w.writeU32(seat.id)
            int64 milli = int64(seat.wealth * 1000.0)
            if (milli < 0) {
                milli = 0
            }
            w.writeU32(milli)
            if (seat.quit) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            if (seat.dropped) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            if (seat.human) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            index = index + 1
        }
        w.writeU32(policies.slots.length)
        index = 0
        while (index < policies.slots.length) {
            buffer blob = policies.get(index)
            w.writeU32(blob.length)
            w.writeBytes(blob)
            index = index + 1
        }
        if (not w.ok()) {
            return(buffer[])
        }
        return(w.bytes)
    }

    /*
     * Encode a published digest blob from tick events.
     *
     * Purpose: GET /digest and GET /events body after tick.
     *
     * Parameters:
     *   tick — published tick count.
     *   events — TickEvent list from State.tick().
     *
     * Returns: opaque buffer; empty on pack failure.
     */
    buffer encodeDigest(int64 tick, list events) {
        WireBytes w = WireBytes()
        w.writeU32(tick)
        w.writeU32(events.length)
        int64 index = 0
        while (index < events.length) {
            TickEvent ev = events[index]
            w.writeString(ev.kind)
            w.writeU32(ev.fleetId + 1)
            w.writeU32(ev.planetId + 1)
            w.writeU32(ev.playerId + 1)
            w.writeU32(ev.value)
            index = index + 1
        }
        if (not w.ok()) {
            return(buffer[])
        }
        return(w.bytes)
    }
}
