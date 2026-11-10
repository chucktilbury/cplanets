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
 *   2026-11-08  Allocate with 1-byte kind=1 so server marks AI.
 *   2026-11-09  Keep token on empty/network handshake failure;
 *               only clear after an explicit reject ack.
 *   2026-11-09  PUT /order + PUT /build from AiOrderPlan so AI
 *               fleets explore / take / yard-build after go.
 *   2026-11-09  Skip order/build while published paused (lobby
 *               hold until operator go, or explicit pause).
 *   2026-11-10  CPL-101: PUT /fleet + PUT /assign when stock needs
 *               createNamed + assign before dispatch.
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
include "orderPlan.cw"
include "policyShape.cw"
include "reaction.cw"
include "verboseLog.cw"
include "view.cw"

/*
 * AiClient talks to a live server over one TCP connection.
 *
 * Brain + ReactionLag decide when to PUT policy. AiOrderPlan turns
 * the same GET snapshot into PUT /order, /build, /fleet, and
 * /assign so fleets actually move (CPL-101 stock→create→assign).
 * GET /state is decoded into ClientStateView (same visibility as a
 * human client) and mirrored into AiExploreState for the on-demand
 * status menu. verbose mirrors AiConfig.verbosity (CLI may overlay).
 */
class AiClient {
    AiConfig config
    AiBrain brain
    AiOrderPlan orders
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
     * Purpose: wire brain/lag/verbs/explore/order planner; delay
     * connect until dial(). Copies cfg.verbosity onto the logger
     * (tests may call setVerbosity afterward).
     *
     * Parameters:
     *   cfg — clamped AI config (host/port/playerId/seed/axes).
     *
     * Returns: AiClient not yet connected.
     */
    AiClient(AiConfig cfg) {
        config = cfg
        brain = AiBrain(cfg)
        orders = AiOrderPlan()
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
     * else allocate with kind=1 (AI) so the server marks the seat
     * non-human and all-humans-quit ignores it. On success, store
     * playerId + token. Empty / truncated responses keep the token
     * and skip allocate so a transient TCP miss cannot grow a
     * ghost seat; only an explicit rejected ack clears the token.
     *
     * Parameters: none.
     *
     * Returns: true when accepted and a seat id was returned.
     */
    bool handshake() {
        bool ok = false
        bool allowAllocate = true
        if (config.reconnectToken.length == 16) {
            WireBytes tok = WireBytes()
            tok.writeBytes(config.reconnectToken)
            Envelope env = Envelope().make(
                Envelope.VERB_PUT, "/handshake", tok.bytes)
            buffer resp = exchange(EnvelopeCodec().encode(env))
            ok = adoptHandshakeSeat(resp)
            if (not ok) {
                if (resp.length < 1) {
                    # Network / empty — keep token; do not allocate.
                    allowAllocate = false
                } else {
                    config.reconnectToken = buffer[]
                }
            }
        }
        if (not ok and allowAllocate and config.playerId >= 0) {
            WireBytes keep = WireBytes()
            keep.writeU32(config.playerId)
            Envelope keepEnv = Envelope().make(
                Envelope.VERB_PUT, "/handshake", keep.bytes)
            buffer keepResp = exchange(
                EnvelopeCodec().encode(keepEnv))
            ok = adoptHandshakeSeat(keepResp)
            if (not ok) {
                if (keepResp.length < 1) {
                    allowAllocate = false
                } else {
                    config.playerId = -1
                }
            }
        }
        if (not ok and allowAllocate) {
            # 1-byte kind=1 → AI allocate (empty would be human).
            WireBytes kind = WireBytes()
            kind.writeU8(1)
            Envelope alloc = Envelope().make(
                Envelope.VERB_PUT, "/handshake", kind.bytes)
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
     * Issue one order / build / fleet-create / assign from snapshot.
     *
     * Purpose: after policy PUT (or when lag skips a PUT), make
     * fleets leave home so quality gets explored. CPL-101: when
     * only unassigned stock remains, create "ai-N" and assign
     * before dispatch. Uses the last decoded GET snapshot and the
     * last / freshly generated policy shape for expansion bias.
     * Skips while the status menu pauses decisions, and while the
     * published snapshot is paused (lobby hold until operator go,
     * or explicit pause). Failures are logged; a rejected verb does
     * not abort the serve-loop.
     *
     * Parameters:
     *   cycleIndex — serve-loop index, or −1 to omit cycle logs.
     *
     * Returns: true when no action was needed or the verb was
     * accepted; false on transport failure of an attempted verb.
     */
    bool maybeIssueOrdersAt(int64 cycleIndex) {
        if (explore.decisionPaused) {
            return(true)
        }
        if (not explore.hasSnapshot) {
            return(true)
        }
        # Server publishes lobby hold as paused until operator go;
        # do not queue explore/build against a held clock.
        if (explore.snapshot.paused) {
            return(true)
        }
        AiPolicyShape shape = explore.lastPolicy
        if (not explore.hasPolicy) {
            shape = brain.generate(explore.view)
        }
        AiOrderIntent intent = orders.plan(explore.snapshot, shape)
        if (intent.kind.equals("none")) {
            return(true)
        }
        if (intent.kind.equals("fleet")) {
            bool created = putFleetCreate(
                intent.buildPlanetId, intent.fleetName)
            verbose.logFleet(
                config.playerId,
                intent.buildPlanetId,
                intent.fleetName,
                created)
            if (cycleIndex >= 0 and created) {
                explore.noteCycle(cycleIndex, "fleet")
            }
            return(created)
        }
        if (intent.kind.equals("assign")) {
            bool assigned = putAssign(
                intent.fleetId, intent.typeName, intent.qty)
            verbose.logAssign(
                config.playerId,
                intent.fleetId,
                intent.typeName,
                intent.qty,
                assigned)
            if (cycleIndex >= 0 and assigned) {
                explore.noteCycle(cycleIndex, "assign")
            }
            return(assigned)
        }
        if (intent.kind.equals("build")) {
            bool built = putBuild(
                intent.buildPlanetId, intent.buildDesignId)
            verbose.logBuild(
                config.playerId,
                intent.buildPlanetId,
                intent.buildDesignId,
                built)
            if (cycleIndex >= 0 and built) {
                explore.noteCycle(cycleIndex, "build")
            }
            return(built)
        }
        if (intent.kind.equals("order")) {
            bool ok = putOrder(
                intent.fleetId,
                intent.order,
                intent.destPlanetId,
                intent.hulls)
            verbose.logOrder(
                config.playerId,
                intent.fleetId,
                intent.order,
                intent.destPlanetId,
                intent.hulls,
                ok)
            if (cycleIndex >= 0 and ok) {
                explore.noteCycle(cycleIndex, "order")
            }
            return(ok)
        }
        return(true)
    }

    /*
     * PUT /order for explore / take / trade / move / ambush.
     *
     * Purpose: same wire as HumanSession.putOrder so the server
     * queues travel on a sitting owned fleet.
     *
     * Parameters:
     *   fleetId — owned sitting fleet id.
     *   order — order string (explore / take / …).
     *   destPlanetId — destination rock.
     *   hulls — peel count; 0 means the whole stack.
     *
     * Returns: true when the server accepted the order.
     */
    bool putOrder(
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(fleetId)
        w.writeU32(destPlanetId)
        w.writeString(order)
        w.writeU32(hulls)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/order", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/order"))
    }

    /*
     * PUT /build to queue a yard hull.
     *
     * Purpose: recreate fleets when the starter stack is gone /
     * locked, matching HumanSession.putBuild.
     *
     * Parameters:
     *   planetId — owned productive shipyard.
     *   designId — ready design id.
     *
     * Returns: true when the server queued the build.
     */
    bool putBuild(int64 planetId, int64 designId) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(planetId)
        w.writeU32(designId)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/build", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/build"))
    }

    /*
     * PUT /fleet to create a named empty sitting fleet.
     *
     * Purpose: CPL-101 — create "ai-N" at home yard when only
     * unassigned stock remains, matching HumanSession.putFleetCreate.
     *
     * Parameters:
     *   planetId — owned planet for the empty fleet.
     *   fleetName — unique per-seat label.
     *
     * Returns: true when the server created the fleet.
     */
    bool putFleetCreate(int64 planetId, String fleetName) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(planetId)
        w.writeString(fleetName)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/fleet", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/fleet"))
    }

    /*
     * PUT /assign to move type+qty from unassigned stock.
     *
     * Purpose: fill a newly created empty fleet before dispatch.
     *
     * Parameters:
     *   fleetId — sitting owned fleet at the stock planet.
     *   typeName — design name to assign.
     *   qty — hulls to move.
     *
     * Returns: true when the server assigned the hulls.
     */
    bool putAssign(int64 fleetId, String typeName, int64 qty) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(fleetId)
        w.writeString(typeName)
        w.writeU32(qty)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/assign", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/assign"))
    }

    /*
     * Decode a flag-ack body for a PUT path.
     *
     * Purpose: shared accept check for /order, /build, /fleet, and
     * /assign (same shape as HumanSession.flagAccepted).
     *
     * Parameters:
     *   resp — raw response envelope bytes.
     *   path — expected response path.
     *
     * Returns: true when accepted == 1.
     */
    bool flagAccepted(buffer resp, String path) {
        if (resp.length < 1) {
            explore.noteError("put_transport_failed")
            return(false)
        }
        Envelope out = EnvelopeCodec().decode(resp)
        if (not out.ok or not out.path.equals(path)) {
            explore.noteError("put_rejected")
            return(false)
        }
        WireBytes r = WireBytes()
        r.setRead(out.body)
        int64 accepted = r.readU8()
        if (not r.ok() or accepted != 1) {
            explore.noteError("put_rejected")
            return(false)
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
