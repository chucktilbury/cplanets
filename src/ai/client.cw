/*
 * src/ai/client.cw — stand-alone AI TCP client (Phase H).
 *
 * Same protocol as the human client: handshake, GET /state,
 * PUT /policy, GET /digest. Never calls tick; never opens the
 * universe DB (RULES §2 / PLAN §4.H).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AiClient request helpers.
 */

import networking as Networking

include "../lib/envelope.cw"
include "../lib/verbGetDigest.cw"
include "../lib/verbGetState.cw"
include "../lib/verbPutPolicy.cw"
include "../lib/wireBytes.cw"
include "brain.cw"
include "config.cw"
include "policyShape.cw"
include "reaction.cw"
include "view.cw"

/*
 * AiClient talks to a live server over one TCP connection.
 *
 * Brain + ReactionLag decide when to PUT. State blobs from GET
 * stay opaque in Phase H except for tick count in the response
 * header — view fill is for in-process / test callers.
 */
class AiClient {
    AiConfig config
    AiBrain brain
    ReactionLag lag
    Networking.Socket sock
    VerbPutPolicy putVerb
    VerbGetState getStateVerb
    VerbGetDigest getDigestVerb
    bool connected

    /*
     * Construct a client around a config.
     *
     * Purpose: wire brain/lag/verbs; delay connect until dial().
     *
     * Parameters:
     *   cfg — clamped AI config (host/port/playerId/seed/axes).
     *
     * Returns: AiClient not yet connected.
     */
    AiClient(AiConfig cfg) {
        config = cfg
        brain = AiBrain(cfg)
        lag = ReactionLag()
        sock = Networking.Socket()
        putVerb = VerbPutPolicy()
        getStateVerb = VerbGetState()
        getDigestVerb = VerbGetDigest()
        connected = false
    }

    /*
     * Connect to config.host:config.port.
     *
     * Purpose: open the TCP session for handshake / verbs.
     *
     * Parameters: none (uses config host/port).
     *
     * Returns: true when the socket reports connected.
     */
    bool dial() {
        connected = sock.connect(config.host, config.port)
        return(connected)
    }

    /*
     * Close the TCP session.
     *
     * Purpose: clean shutdown without a quit verb (caller may
     * quit first).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void close() {
        sock.close()
        connected = false
    }

    /*
     * Send one framed request and read one response envelope.
     *
     * Purpose: share the request/response burst used by listen
     * (one complete envelope per recv on localhost).
     *
     * Parameters:
     *   request — full envelope bytes.
     *
     * Returns: response buffer, or empty on failure.
     */
    buffer exchange(buffer request) {
        if (not connected) {
            return(buffer[])
        }
        int64 sent = sock.send(request)
        if (sent < 1) {
            return(buffer[])
        }
        return(sock.recv(65536))
    }

    /*
     * PUT /handshake for this seat.
     *
     * Purpose: presence keep-alive (AFK ≠ drop).
     *
     * Parameters: none.
     *
     * Returns: true when a non-empty response returns.
     */
    bool handshake() {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/handshake", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(resp.length > 0)
    }

    /*
     * GET /state and return the response tick.
     *
     * Purpose: read published tick for lag gating. State blob
     * stays opaque here.
     *
     * Parameters: none.
     *
     * Returns: published tick, or -1 on failure.
     */
    int64 pullStateTick() {
        buffer req = getStateVerb.encodeRequest(
            GetStateRequest(config.playerId, 0))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            return(-1)
        }
        GetStateResponse ack = getStateVerb.decodeResponse(resp)
        return(ack.tick)
    }

    /*
     * Build a policy from view and PUT it when lag allows.
     *
     * Purpose: one reaction step — core of the AI loop. Same
     * visibility: caller supplies the view.
     *
     * Parameters:
     *   view — visibility-limited snapshot.
     *   nowMs — wall or injectable clock.
     *
     * Returns: true when a policy was generated and PUT accepted
     * (or skipped because lag not ready — still true); false on
     * transport / reject failure when an update was attempted.
     */
    bool maybePutPolicy(AiView view, uint64 nowMs) {
        if (not lag.shouldUpdate(
            config, view.publishedTick, nowMs)) {
            return(true)
        }
        AiPolicyShape shape = brain.generate(view)
        buffer blob = shape.encode()
        buffer req = putVerb.encodeRequest(
            PutPolicyRequest(config.playerId, blob))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            return(false)
        }
        PutPolicyResponse ack = putVerb.decodeResponse(resp)
        if (not ack.accepted) {
            return(false)
        }
        lag.markUpdated(view.publishedTick, nowMs)
        return(true)
    }

    /*
     * Generate a policy without TCP (in-process / tests).
     *
     * Purpose: fn tests assert shape without a listen socket.
     *
     * Parameters:
     *   view — visibility-limited snapshot.
     *   nowMs — clock for lag.
     *
     * Returns: AiPolicyShape when lag allows; empty neutral shape
     * with version 0 when skipped (caller checks version).
     */
    AiPolicyShape generateLocal(AiView view, uint64 nowMs) {
        AiPolicyShape skipped = AiPolicyShape()
        skipped.version = 0
        if (not lag.shouldUpdate(
            config, view.publishedTick, nowMs)) {
            return(skipped)
        }
        AiPolicyShape shape = brain.generate(view)
        lag.markUpdated(view.publishedTick, nowMs)
        return(shape)
    }
}
