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
 *   2026-11-06  One-shot TCP: redial per exchange (server closes).
 *   2026-11-07  Verbosity: seat / policy / cycle decision logs.
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
include "verboseLog.cw"
include "view.cw"

/*
 * AiClient talks to a live server over one TCP connection.
 *
 * Brain + ReactionLag decide when to PUT. State blobs from GET
 * stay opaque in Phase H except for tick count in the response
 * header — view fill is for in-process / test callers.
 * verbose mirrors AiConfig.verbosity (CLI may overlay).
 */
class AiClient {
    AiConfig config
    AiBrain brain
    ReactionLag lag
    AiVerboseLog verbose
    Networking.Socket sock
    VerbPutPolicy putVerb
    VerbGetState getStateVerb
    VerbGetDigest getDigestVerb
    bool connected

    /*
     * Construct a client around a config.
     *
     * Purpose: wire brain/lag/verbs; delay connect until dial().
     * Copies cfg.verbosity onto the logger (tests may call
     * setVerbosity afterward).
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
        verbose = AiVerboseLog()
        verbose.setLevel(cfg.verbosity)
        sock = Networking.Socket()
        putVerb = VerbPutPolicy()
        getStateVerb = VerbGetState()
        getDigestVerb = VerbGetDigest()
        connected = false
    }

    /*
     * Overlay the active verbosity level (CLI / tests).
     *
     * Purpose: --verbosity after config load, or unit programs that
     * assert quiet vs decision emits. Also updates config.verbosity.
     *
     * Parameters:
     *   value — 0–10 on the provisional ladder (clamped).
     *
     * Returns: nothing.
     */
    void setVerbosity(int64 value) {
        verbose.setLevel(value)
        config.verbosity = verbose.level
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
     * Purpose: match ServerListen — one envelope per TCP
     * connection; the server closes after the reply, so each
     * verb must dial fresh (same contract as HumanSession).
     *
     * Parameters:
     *   request — full envelope bytes.
     *
     * Returns: response buffer, or empty on failure.
     */
    buffer exchange(buffer request) {
        # Socket.close() drops the fd to -1; construct a new Socket
        # so connect() gets a fresh OS handle each verb.
        sock.close()
        sock = Networking.Socket()
        connected = false
        if (not sock.connect(config.host, config.port)) {
            return(buffer[])
        }
        connected = true
        int64 sent = sock.send(request)
        if (sent < 1) {
            sock.close()
            connected = false
            return(buffer[])
        }
        buffer resp = sock.recv(65536)
        sock.close()
        connected = false
        return(resp)
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
        bool ok = resp.length > 0
        verbose.logSeat(config.playerId, ok)
        return(ok)
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
        return(maybePutPolicyAt(view, nowMs, -1))
    }

    /*
     * Build a policy and PUT it when lag allows; log cycle action.
     *
     * Purpose: same as maybePutPolicy, plus an optional zero-based
     * cycle index for verbosity: cycle lines under --serve-loop.
     * Pass cycleIndex < 0 to omit the cycle line (handshake-only
     * callers / tests).
     *
     * Parameters:
     *   view — visibility-limited snapshot.
     *   nowMs — wall or injectable clock.
     *   cycleIndex — serve-loop attempt index, or -1 to skip cycle log.
     *
     * Returns: true when lag skipped or PUT accepted; false on
     * transport / reject failure when an update was attempted.
     */
    bool maybePutPolicyAt(AiView view, uint64 nowMs, int64 cycleIndex) {
        if (not lag.shouldUpdate(
            config, view.publishedTick, nowMs)) {
            if (cycleIndex >= 0) {
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "skip")
            }
            return(true)
        }
        AiPolicyShape shape = brain.generate(view)
        verbose.logPolicy(config.playerId, shape, "put")
        buffer blob = shape.encode()
        buffer req = putVerb.encodeRequest(
            PutPolicyRequest(config.playerId, blob))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            if (cycleIndex >= 0) {
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "fail")
            }
            return(false)
        }
        PutPolicyResponse ack = putVerb.decodeResponse(resp)
        if (not ack.accepted) {
            if (cycleIndex >= 0) {
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "fail")
            }
            return(false)
        }
        lag.markUpdated(view.publishedTick, nowMs)
        if (cycleIndex >= 0) {
            verbose.logCycle(
                cycleIndex,
                view.publishedTick,
                config.playerId,
                "put")
        }
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
        verbose.logPolicy(config.playerId, shape, "local")
        lag.markUpdated(view.publishedTick, nowMs)
        return(shape)
    }
}
