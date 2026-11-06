/*
 * src/lib/verbGetDigest.cw — GET /events and GET /digest (Phase E).
 *
 * Clients read the newspaper / event digest published with each
 * tick (RULES §2 / §13). /events and /digest share one body shape.
 * No listen socket; no POST turn barrier (PLAN §4.E).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GET events/digest request and response.
 */

include "envelope.cw"
include "wireBytes.cw"

/*
 * GetDigestRequest asks for events since a tick.
 *
 * playerId selects the seat's audience later; sinceTick is the
 * last digest the client applied (0 = full digest).
 */
class GetDigestRequest {
    int64 playerId
    int64 sinceTick

    /*
     * Construct a GET digest/events request body.
     *
     * Purpose: name the seat and how far back events are needed.
     *
     * Parameters:
     *   player — empire id (>= 0).
     *   since — last applied digest tick; 0 means full.
     *
     * Returns: GetDigestRequest ready to encode.
     */
    GetDigestRequest(int64 player, int64 since) {
        playerId = player
        sinceTick = since
    }
}

/*
 * GetDigestResponse carries published newspaper bytes.
 *
 * tick is the published tick; eventsBlob is opaque binary for
 * Phase E round-trips (structured TickEvent wire comes with F).
 */
class GetDigestResponse {
    int64 tick
    buffer eventsBlob

    /*
     * Construct a GET digest/events response body.
     *
     * Purpose: return the published tick and opaque event bytes.
     *
     * Parameters:
     *   publishedTick — server tick after last tick().
     *   blob — opaque events/newspaper bytes.
     *
     * Returns: GetDigestResponse ready to encode.
     */
    GetDigestResponse(int64 publishedTick, buffer blob) {
        tick = publishedTick
        eventsBlob = blob
    }
}

/*
 * VerbGetDigest builds and parses GET /events and GET /digest.
 *
 * Both paths use Envelope.VERB_GET and the same body layout.
 * encodeRequest/encodeResponse take an explicit path so callers
 * pick "/events" or "/digest"; decode accepts either.
 */
class VerbGetDigest {
    EnvelopeCodec codec
    String pathEvents
    String pathDigest

    /*
     * Construct the GET events/digest verb helper.
     *
     * Purpose: pin both path constants and share one codec.
     *
     * Parameters: none.
     *
     * Returns: VerbGetDigest ready for encode/decode.
     */
    VerbGetDigest() {
        codec = EnvelopeCodec()
        pathEvents = "/events"
        pathDigest = "/digest"
    }

    /*
     * True when path is /events or /digest.
     *
     * Purpose: accept both aliases on decode.
     *
     * Parameters:
     *   path — envelope path string.
     *
     * Returns: true when the path is a digest GET target.
     */
    bool isDigestPath(String path) {
        if (path.equals(pathEvents)) {
            return(true)
        }
        if (path.equals(pathDigest)) {
            return(true)
        }
        return(false)
    }

    /*
     * Encode a GET digest/events request frame.
     *
     * Purpose: client → server bytes for a newspaper fetch.
     *
     * Parameters:
     *   path — "/events" or "/digest".
     *   request — playerId + sinceTick.
     *
     * Returns: envelope bytes, or empty on bad path / pack failure.
     */
    buffer encodeRequest(String path, GetDigestRequest request) {
        if (not isDigestPath(path)) {
            return(buffer[])
        }
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
     * Decode a GET digest/events request frame.
     *
     * Purpose: server-side parse; accepts /events or /digest.
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: GetDigestRequest; playerId is -1 on failure.
     */
    GetDigestRequest decodeRequest(buffer frame) {
        GetDigestRequest bad = GetDigestRequest(-1, 0)
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_GET
            or (not isDigestPath(env.path))) {
            return(bad)
        }
        WireBytes r = WireBytes()
        r.setRead(env.body)
        int64 player = r.readU32()
        int64 since = r.readU32()
        if (not r.ok() or r.offset != env.body.length) {
            return(bad)
        }
        return(GetDigestRequest(player, since))
    }

    /*
     * Encode a GET digest/events response frame.
     *
     * Purpose: server → client newspaper bytes.
     *
     * Parameters:
     *   path — "/events" or "/digest" (echo the request path).
     *   response — tick + opaque events blob.
     *
     * Returns: envelope bytes, or empty on bad path / pack failure.
     */
    buffer encodeResponse(
        String path, GetDigestResponse response) {
        if (not isDigestPath(path)) {
            return(buffer[])
        }
        WireBytes w = WireBytes()
        w.writeU32(response.tick)
        w.writeU32(response.eventsBlob.length)
        w.writeBytes(response.eventsBlob)
        if (not w.ok()) {
            return(buffer[])
        }
        Envelope env = Envelope().make(
            Envelope.VERB_GET, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Decode a GET digest/events response frame.
     *
     * Purpose: client-side parse of a newspaper payload.
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: GetDigestResponse; tick is -1 on failure.
     */
    GetDigestResponse decodeResponse(buffer frame) {
        GetDigestResponse bad = GetDigestResponse(-1, buffer[])
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_GET
            or (not isDigestPath(env.path))) {
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
        return(GetDigestResponse(tick, blob))
    }
}
