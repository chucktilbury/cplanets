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
 *   2026-11-08  Decode GET /state into explore bag for status menu.
 *   2026-11-08  putSuspended for menu-open AFK hold.
 *   2026-11-08  Handshake empty-body allocate; adopt returned
 *               playerId for all subsequent traffic.
 *   2026-11-08  Store/send reconnect token; reclaim after drop.
 */

import networking as Networking

include "../client/publishDecode.cw"
include "../client/stateView.cw"
include "../lib/envelope.cw"
include "../lib/verbGetDigest.cw"
include "../lib/verbGetState.cw"
include "../lib/verbPutPolicy.cw"
include "../lib/wireBytes.cw"
include "brain.cw"
include "config.cw"
include "exploreState.cw"
include "policyShape.cw"
include "reaction.cw"
include "verboseLog.cw"
include "view.cw"

/*
 * AiClient talks to a live server over one TCP connection.
 *
 * Brain + ReactionLag decide when to PUT. GET /state is decoded
 * into ClientStateView (same visibility as a human client) and
 * mirrored into AiExploreState for the on-demand status menu.
 * verbose mirrors AiConfig.verbosity (CLI may overlay).
 */
class AiClient {
    AiConfig config
    AiBrain brain
    ReactionLag lag
    AiVerboseLog verbose
    AiExploreState explore
    PublishDecode decoder
    Networking.Socket sock
    VerbPutPolicy putVerb
    VerbGetState getStateVerb
    VerbGetDigest getDigestVerb
    bool connected

    /*
     * Construct a client around a config.
     *
     * Purpose: wire brain/lag/verbs/explore; delay connect until
     * dial(). Copies cfg.verbosity onto the logger (tests may call
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
        explore = AiExploreState(cfg, lag, verbose)
        decoder = PublishDecode()
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
        explore.noteDial(connected)
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
     * PUT /handshake; adopt the server-assigned seat + token.
     *
     * Purpose: presence keep-alive (AFK ≠ drop) and reconnect.
     * Prefer the stored reconnect token; else playerId keep-alive;
     * else empty allocate. On success, store playerId + token.
     *
     * Parameters: none.
     *
     * Returns: true when accepted and a seat id was returned.
     */
    bool handshake() {
        bool ok = false
        if (config.reconnectToken.length == 16) {
            WireBytes tok = WireBytes()
            tok.writeBytes(config.reconnectToken)
            Envelope env = Envelope().make(
                Envelope.VERB_PUT, "/handshake", tok.bytes)
            buffer resp = exchange(EnvelopeCodec().encode(env))
            ok = adoptHandshakeSeat(resp)
            if (not ok) {
                config.reconnectToken = buffer[]
            }
        }
        if (not ok and config.playerId >= 0) {
            WireBytes keep = WireBytes()
            keep.writeU32(config.playerId)
            Envelope keepEnv = Envelope().make(
                Envelope.VERB_PUT, "/handshake", keep.bytes)
            buffer keepResp = exchange(
                EnvelopeCodec().encode(keepEnv))
            ok = adoptHandshakeSeat(keepResp)
            if (not ok) {
                config.playerId = -1
            }
        }
        if (not ok) {
            Envelope alloc = Envelope().make(
                Envelope.VERB_PUT, "/handshake", buffer[])
            buffer resp = exchange(EnvelopeCodec().encode(alloc))
            ok = adoptHandshakeSeat(resp)
        }
        explore.noteHandshake(ok)
        verbose.logSeat(config.playerId, ok)
        return(ok)
    }

    /*
     * Decode a handshake ack and store seat + reconnect token.
     *
     * Purpose: server seating is authoritative — body shape is
     * u8 accepted, u32 tick, u8 ended, u32 playerId,
     * TOKEN_BYTES (16) opaque token.
     *
     * Parameters:
     *   resp — raw response envelope bytes.
     *
     * Returns: true when accepted == 1 and playerId is in range.
     */
    bool adoptHandshakeSeat(buffer resp) {
        if (resp.length < 1) {
            return(false)
        }
        Envelope out = EnvelopeCodec().decode(resp)
        if (not out.ok or not out.path.equals("/handshake")) {
            return(false)
        }
        WireBytes r = WireBytes()
        r.setRead(out.body)
        int64 accepted = r.readU8()
        r.readU32()
        r.readU8()
        int64 seat = r.readU32()
        buffer token = r.readBytes(16)
        if (not r.ok() or accepted != 1 or seat == 0xffffffff) {
            return(false)
        }
        if (token.length != 16) {
            return(false)
        }
        config.playerId = seat
        config.reconnectToken = token
        explore.config.playerId = seat
        explore.view.playerId = seat
        return(true)
    }

    /*
     * PUT /suspended for this seat.
     *
     * Purpose: intentional AFK hold while the status menu is open
     * (or any client pause) so handshake_miss does not drop the
     * seat. Clear on resume so normal miss drop applies again.
     *
     * Parameters:
     *   wantSuspended — true to hold; false to clear.
     *
     * Returns: true when a non-empty ack returns.
     */
    bool putSuspended(bool wantSuspended) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        if (wantSuspended) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/suspended", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        bool ok = resp.length > 0
        explore.noteSuspended(wantSuspended, ok)
        return(ok)
    }

    /*
     * GET /state, decode into explore, and return the tick.
     *
     * Purpose: read published tick for lag gating and fill the
     * client-visible snapshot the status menu explores.
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
            explore.noteError("pull_state_failed")
            return(-1)
        }
        GetStateResponse ack = getStateVerb.decodeResponse(resp)
        ClientStateView decoded = decoder.decodeState(
            ack.stateBlob, config.playerId)
        if (ack.tick >= 0) {
            decoded.tick = ack.tick
        }
        explore.noteSnapshot(decoded, ack.tick)
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
        if (explore.decisionPaused) {
            if (cycleIndex >= 0) {
                explore.noteCycle(cycleIndex, "skip")
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "skip")
            }
            return(true)
        }
        if (not lag.shouldUpdate(
            config, view.publishedTick, nowMs)) {
            if (cycleIndex >= 0) {
                explore.noteCycle(cycleIndex, "skip")
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "skip")
            }
            return(true)
        }
        AiPolicyShape shape = brain.generate(view)
        explore.notePolicy(shape, "put")
        verbose.logPolicy(config.playerId, shape, "put")
        buffer blob = shape.encode()
        buffer req = putVerb.encodeRequest(
            PutPolicyRequest(config.playerId, blob))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            if (cycleIndex >= 0) {
                explore.noteCycle(cycleIndex, "fail")
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "fail")
            }
            explore.noteError("put_transport_failed")
            return(false)
        }
        PutPolicyResponse ack = putVerb.decodeResponse(resp)
        if (not ack.accepted) {
            if (cycleIndex >= 0) {
                explore.noteCycle(cycleIndex, "fail")
                verbose.logCycle(
                    cycleIndex,
                    view.publishedTick,
                    config.playerId,
                    "fail")
            }
            explore.noteError("put_rejected")
            return(false)
        }
        lag.markUpdated(view.publishedTick, nowMs)
        if (cycleIndex >= 0) {
            explore.noteCycle(cycleIndex, "put")
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
