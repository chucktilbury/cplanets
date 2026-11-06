/*
 * src/lib/verbGetState.cw — GET /state message (Phase E).
 *
 * Client reads the published snapshot. Body is a compact binary
 * request/response; full State object graphs stay in lib tick
 * (PLAN §4.E / RULES §2). No listen socket.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GET /state request and response codecs.
 */

include "envelope.cw"
include "wireBytes.cw"

/*
 * GetStateRequest asks for a published state view.
 *
 * playerId selects the seat's fog/view later; sinceTick lets the
 * client skip unchanged ticks (0 = full snapshot).
 */
class GetStateRequest {
    int64 playerId
    int64 sinceTick

    /*
     * Construct a GET /state request body.
     *
     * Purpose: name which seat is asking and which tick they last
     * held so the server can answer with a delta or full blob.
     *
     * Parameters:
     *   player — empire id (>= 0).
     *   since — last known tick; 0 means full state.
     *
     * Returns: GetStateRequest ready to encode.
     */
    GetStateRequest(int64 player, int64 since) {
        playerId = player
        sinceTick = since
    }
}

/*
 * GetStateResponse carries a published state blob.
 *
 * tick is the published tick count; stateBlob is opaque binary for
 * Phase E round-trips (structured State wire comes with F).
 */
class GetStateResponse {
    int64 tick
    buffer stateBlob

    /*
     * Construct a GET /state response body.
     *
     * Purpose: return the published tick and opaque state bytes.
     *
     * Parameters:
     *   publishedTick — server tick count after last tick().
     *   blob — opaque state bytes (may be empty).
     *
     * Returns: GetStateResponse ready to encode.
     */
    GetStateResponse(int64 publishedTick, buffer blob) {
        tick = publishedTick
        stateBlob = blob
    }
}

/*
 * VerbGetState builds and parses GET /state envelopes.
 *
 * Path is always "/state". Verb is Envelope.VERB_GET. Rejects
 * mismatched path/verb on decode.
 */
class VerbGetState {
    EnvelopeCodec codec
    String path

    /*
     * Construct the GET /state verb helper.
     *
     * Purpose: pin the path constant and share one EnvelopeCodec.
     *
     * Parameters: none.
     *
     * Returns: VerbGetState ready for encode/decode.
     */
    VerbGetState() {
        codec = EnvelopeCodec()
        path = "/state"
    }

    /*
     * Encode a GET /state request frame.
     *
     * Purpose: client → server bytes for a state fetch.
     *
     * Parameters:
     *   request — playerId + sinceTick.
     *
     * Returns: envelope bytes, or empty on pack failure.
     */
    buffer encodeRequest(GetStateRequest request) {
        WireBytes w = WireBytes()
        w.writeU32(request.playerId)
        w.writeU32(request.sinceTick)
        if (not w.ok()) {
            return(buffer[])
        }
        Envelope env = Envelope().make(
            Envelope.VERB_GET, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Decode a GET /state request frame.
     *
     * Purpose: server-side parse of a client fetch. Sets ok false
     * style via sentinel playerId -1 on failure (check via
     * decodeRequestOk).
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: GetStateRequest; playerId is -1 on failure.
     */
    GetStateRequest decodeRequest(buffer frame) {
        GetStateRequest bad = GetStateRequest(-1, 0)
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_GET
            or (not env.path.equals(path))) {
            return(bad)
        }
        WireBytes r = WireBytes()
        r.setRead(env.body)
        int64 player = r.readU32()
        int64 since = r.readU32()
        if (not r.ok() or r.offset != env.body.length) {
            return(bad)
        }
        return(GetStateRequest(player, since))
    }

    /*
     * Encode a GET /state response frame.
     *
     * Purpose: server → client published snapshot bytes.
     *
     * Parameters:
     *   response — tick + opaque state blob.
     *
     * Returns: envelope bytes, or empty on pack failure.
     */
    buffer encodeResponse(GetStateResponse response) {
        WireBytes w = WireBytes()
        w.writeU32(response.tick)
        w.writeU32(response.stateBlob.length)
        w.writeBytes(response.stateBlob)
        if (not w.ok()) {
            return(buffer[])
        }
        Envelope env = Envelope().make(
            Envelope.VERB_GET, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Decode a GET /state response frame.
     *
     * Purpose: client-side parse of a published snapshot.
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: GetStateResponse; tick is -1 on failure.
     */
    GetStateResponse decodeResponse(buffer frame) {
        GetStateResponse bad = GetStateResponse(-1, buffer[])
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_GET
            or (not env.path.equals(path))) {
            return(bad)
        }
        WireBytes r = WireBytes()
        r.setRead(env.body)
        int64 tick = r.readU32()
        int64 blobLen = r.readU32()
        buffer blob = r.readBytes(blobLen)
        if (not r.ok() or r.offset != env.body.length) {
            return(bad)
        }
        return(GetStateResponse(tick, blob))
    }
}
