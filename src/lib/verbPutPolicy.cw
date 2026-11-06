/*
 * src/lib/verbPutPolicy.cw — PUT /policy message (Phase E).
 *
 * Primary client write: update a seat's current policy anytime
 * (RULES §2). Opaque policy blob for Phase E byte round-trips.
 * No all-players-ready / POST turn barrier. No listen socket.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial PUT /policy request and response codecs.
 */

include "envelope.cw"
include "wireBytes.cw"

/*
 * PutPolicyRequest is the client policy write.
 *
 * playerId names the seat; policyBlob is opaque binary for Phase E
 * (structured Policy wire lands with the server driver).
 */
class PutPolicyRequest {
    int64 playerId
    buffer policyBlob

    /*
     * Construct a PUT /policy request body.
     *
     * Purpose: carry one seat's policy update for framing.
     *
     * Parameters:
     *   player — empire id (>= 0).
     *   blob — opaque policy bytes (may be empty).
     *
     * Returns: PutPolicyRequest ready to encode.
     */
    PutPolicyRequest(int64 player, buffer blob) {
        playerId = player
        policyBlob = blob
    }
}

/*
 * PutPolicyResponse acknowledges a policy write.
 *
 * accepted is true when the server stored the policy; tick is the
 * current published tick (not advanced by the PUT itself).
 */
class PutPolicyResponse {
    bool accepted
    int64 tick

    /*
     * Construct a PUT /policy response body.
     *
     * Purpose: tell the client whether the write stuck and which
     * published tick is current.
     *
     * Parameters:
     *   ok — true when the server accepted the policy.
     *   publishedTick — current published tick count.
     *
     * Returns: PutPolicyResponse ready to encode.
     */
    PutPolicyResponse(bool ok, int64 publishedTick) {
        accepted = ok
        tick = publishedTick
    }
}

/*
 * VerbPutPolicy builds and parses PUT /policy envelopes.
 *
 * Path is always "/policy". Verb is Envelope.VERB_PUT.
 */
class VerbPutPolicy {
    EnvelopeCodec codec
    String path

    /*
     * Construct the PUT /policy verb helper.
     *
     * Purpose: pin the path constant and share one EnvelopeCodec.
     *
     * Parameters: none.
     *
     * Returns: VerbPutPolicy ready for encode/decode.
     */
    VerbPutPolicy() {
        codec = EnvelopeCodec()
        path = "/policy"
    }

    /*
     * Encode a PUT /policy request frame.
     *
     * Purpose: client → server policy write bytes.
     *
     * Parameters:
     *   request — playerId + opaque policy blob.
     *
     * Returns: envelope bytes, or empty on pack failure.
     */
    buffer encodeRequest(PutPolicyRequest request) {
        WireBytes w = WireBytes()
        w.writeU32(request.playerId)
        w.writeU32(request.policyBlob.length)
        w.writeBytes(request.policyBlob)
        if (not w.ok()) {
            return(buffer[])
        }
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Decode a PUT /policy request frame.
     *
     * Purpose: server-side parse of a policy write.
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: PutPolicyRequest; playerId is -1 on failure.
     */
    PutPolicyRequest decodeRequest(buffer frame) {
        PutPolicyRequest bad = PutPolicyRequest(-1, buffer[])
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_PUT
            or (not env.path.equals(path))) {
            return(bad)
        }
        WireBytes r = WireBytes()
        r.setRead(env.body)
        int64 player = r.readU32()
        int64 blobLen = r.readU32()
        buffer blob = r.readBytes(blobLen)
        if (not r.ok() or r.offset != env.body.length) {
            return(bad)
        }
        return(PutPolicyRequest(player, blob))
    }

    /*
     * Encode a PUT /policy response frame.
     *
     * Purpose: server → client ack bytes.
     *
     * Parameters:
     *   response — accepted flag + published tick.
     *
     * Returns: envelope bytes, or empty on pack failure.
     */
    buffer encodeResponse(PutPolicyResponse response) {
        WireBytes w = WireBytes()
        if (response.accepted) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(response.tick)
        if (not w.ok()) {
            return(buffer[])
        }
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Decode a PUT /policy response frame.
     *
     * Purpose: client-side parse of a policy ack.
     *
     * Parameters:
     *   frame — complete envelope bytes.
     *
     * Returns: PutPolicyResponse; tick is -1 on failure.
     */
    PutPolicyResponse decodeResponse(buffer frame) {
        PutPolicyResponse bad = PutPolicyResponse(false, -1)
        Envelope env = codec.decode(frame)
        if (not env.ok) {
            return(bad)
        }
        if (env.verb != Envelope.VERB_PUT
            or (not env.path.equals(path))) {
            return(bad)
        }
        WireBytes r = WireBytes()
        r.setRead(env.body)
        int64 flag = r.readU8()
        int64 tick = r.readU32()
        if (not r.ok() or r.offset != env.body.length) {
            return(bad)
        }
        return(PutPolicyResponse(flag == 1, tick))
    }
}
