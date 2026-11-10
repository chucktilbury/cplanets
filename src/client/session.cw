/*
 * src/client/session.cw — human TCP session (Phase G).
 *
 * Same protocol as the AI client: handshake, GET /state,
 * PUT /policy, GET /digest, plus TUNING-B PUT /pause, /order,
 * /recall, ship-create PUT /design, /build, /reclaim-hulls, and
 * list-chrome PUT /budget, /message. Never calls tick; never
 * opens the universe DB (RULES §2 / PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial HumanSession request helpers.
 *   2026-11-06  TUNING B: putPause / putOrder / putRecall.
 *   2026-11-08  putSuspended intentional AFK presence flag.
 *   2026-11-06  One-shot TCP: redial per exchange (server closes).
 *   2026-11-07  Ship create: putDesign / putBuild / putReclaimHulls.
 *   2026-11-07  putBudget / putMessage for list chrome.
 *   2026-11-07  putOrder trailing hulls peel count.
 *   2026-11-07  lastRejectReason from optional /order ack trailer.
 *   2026-11-08  Handshake empty-body allocate; adopt returned
 *               playerId for all subsequent traffic.
 *   2026-11-08  Store/send reconnect token; reclaim after drop.
 *   2026-11-09  Keep token on empty/network handshake failure;
 *               only clear after an explicit reject ack (no ghost
 *               allocate from a transient miss).
 *   2026-11-10  CPL-101: putFleetCreate / putAssign /
 *               putReclaimStock (flag ack + reject reason).
 *   2026-11-10  putDisplayName after handshake (CPL-106).
 */

import networking as Networking

include "../lib/envelope.cw"
include "../lib/verbGetDigest.cw"
include "../lib/verbGetState.cw"
include "../lib/verbPutPolicy.cw"
include "../lib/wireBytes.cw"
include "config.cw"
include "policyShape.cw"
include "publishDecode.cw"
include "stateView.cw"

/*
 * HumanSession talks to a live server over one TCP connection.
 *
 * Decodes seat-scoped list views for the GTK debugger. No dumb-
 * order warnings — PUT always sends standing policy.
 */
class HumanSession {
    HumanConfig config
    Networking.Socket sock
    VerbPutPolicy putVerb
    VerbGetState getStateVerb
    VerbGetDigest getDigestVerb
    PublishDecode decoder
    bool connected
    String lastRejectReason
    # True after a successful PUT /name for the current seat.
    bool namePublished

    /*
     * Construct a session around a config.
     *
     * Purpose: wire verbs/decoder; delay connect until dial().
     *
     * Parameters:
     *   cfg — clamped human config (host/port/playerId).
     *
     * Returns: HumanSession not yet connected.
     */
    HumanSession(HumanConfig cfg) {
        config = cfg
        sock = Networking.Socket()
        putVerb = VerbPutPolicy()
        getStateVerb = VerbGetState()
        getDigestVerb = VerbGetDigest()
        decoder = PublishDecode()
        connected = false
        lastRejectReason = ""
        namePublished = false
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
     * Purpose: clean shutdown.
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
     * Purpose: match ServerListen — one complete envelope per
     * TCP connection; the server closes after the reply, so each
     * verb must dial fresh (handshake then GET on one socket
     * always saw an empty second response).
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
     * Prefer sending the stored reconnect token (reclaim or
     * keep-alive). Else when playerId is assigned, send that id
     * as keep-alive. Else empty body for a new allocate. On
     * success, store returned playerId and TOKEN_BYTES token.
     * Empty / truncated responses keep the token and do **not**
     * fall through to allocate (avoids ghost seats on transient
     * TCP misses). Only an explicit rejected ack clears the token.
     *
     * Parameters: none.
     *
     * Returns: true when accepted and a seat id was returned.
     */
    bool handshake() {
        if (config.reconnectToken.length == 16) {
            WireBytes tok = WireBytes()
            tok.writeBytes(config.reconnectToken)
            Envelope env = Envelope().make(
                Envelope.VERB_PUT, "/handshake", tok.bytes)
            buffer resp = exchange(EnvelopeCodec().encode(env))
            if (adoptHandshakeSeat(resp)) {
                ensureDisplayName()
                return(true)
            }
            if (resp.length < 1) {
                # Network / empty — keep token; do not allocate.
                return(false)
            }
            # Explicit reject — token no longer valid.
            config.reconnectToken = buffer[]
            namePublished = false
        }
        if (config.playerId >= 0) {
            WireBytes keep = WireBytes()
            keep.writeU32(config.playerId)
            Envelope keepEnv = Envelope().make(
                Envelope.VERB_PUT, "/handshake", keep.bytes)
            buffer keepResp = exchange(
                EnvelopeCodec().encode(keepEnv))
            if (adoptHandshakeSeat(keepResp)) {
                ensureDisplayName()
                return(true)
            }
            if (keepResp.length < 1) {
                return(false)
            }
            # Not connected / stale config id — allocate fresh.
            config.playerId = -1
            namePublished = false
        }
        Envelope alloc = Envelope().make(
            Envelope.VERB_PUT, "/handshake", buffer[])
        buffer resp = exchange(EnvelopeCodec().encode(alloc))
        if (adoptHandshakeSeat(resp)) {
            namePublished = false
            ensureDisplayName()
            return(true)
        }
        return(false)
    }

    /*
     * PUT /name once per seat with the human config label.
     *
     * Purpose: publish display_name so chrome/digest show the
     * configured identity (CPL-106). Skips when already sent for
     * this seat so keep-alive handshakes stay cheap.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void ensureDisplayName() {
        if (namePublished) {
            return()
        }
        if (config.playerId < 0) {
            return()
        }
        if (putDisplayName(config.resolvedDisplayName())) {
            namePublished = true
        }
    }

    /*
     * PUT /name with playerId + display string.
     *
     * Purpose: store the seat label on the server Player.
     *
     * Parameters:
     *   name — non-empty display name.
     *
     * Returns: true when the server accepted the change.
     */
    bool putDisplayName(String name) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeString(name)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/name", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/name"))
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
        return(true)
    }

    /*
     * GET /state and decode into a ClientStateView.
     *
     * Purpose: refresh planet/fleet lists from published flags.
     *
     * Parameters: none.
     *
     * Returns: filled view; tick -1 style via empty planets and
     * tick 0 with viewer unset on hard failure — check ok via
     * pullState's companion bool... returns view with tick from
     * response header when decode works.
     */
    ClientStateView pullState() {
        ClientStateView bad = ClientStateView(config.playerId)
        # tick -1 marks transport / decode failure for pullRemote.
        bad.tick = -1
        buffer req = getStateVerb.encodeRequest(
            GetStateRequest(config.playerId, 0))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            return(bad)
        }
        GetStateResponse ack = getStateVerb.decodeResponse(resp)
        if (ack.tick < 0) {
            return(bad)
        }
        ClientStateView view = decoder.decodeState(
            ack.stateBlob, config.playerId)
        view.tick = ack.tick
        return(view)
    }

    /*
     * GET /digest and attach newspaper lines to a view.
     *
     * Purpose: refresh the digest pane.
     *
     * Parameters:
     *   view — mutable view to receive digest lines.
     *
     * Returns: true when a digest response decoded.
     */
    bool pullDigest(ClientStateView view) {
        buffer req = getDigestVerb.encodeRequest(
            "/digest", GetDigestRequest(config.playerId, 0))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            return(false)
        }
        GetDigestResponse ack = getDigestVerb.decodeResponse(resp)
        if (ack.tick < 0) {
            return(false)
        }
        return(decoder.decodeDigest(ack.eventsBlob, view))
    }

    /*
     * PUT /policy from an editor shape.
     *
     * Purpose: anytime standing-policy write; no warnings for
     * legal orders (PLAN §4.G).
     *
     * Parameters:
     *   shape — human policy editor contents.
     *
     * Returns: true when the server accepted the PUT.
     */
    bool putPolicy(HumanPolicyShape shape) {
        buffer blob = shape.encode()
        buffer req = putVerb.encodeRequest(
            PutPolicyRequest(config.playerId, blob))
        buffer resp = exchange(req)
        if (resp.length < 1) {
            return(false)
        }
        PutPolicyResponse ack = putVerb.decodeResponse(resp)
        return(ack.accepted)
    }

    /*
     * PUT /pause with a 0/1 flag body.
     *
     * Purpose: one-human pause control (server still gates).
     *
     * Parameters:
     *   wantPaused — desired pause state.
     *
     * Returns: true when the server accepted the change.
     */
    bool putPause(bool wantPaused) {
        WireBytes w = WireBytes()
        if (wantPaused) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/pause", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/pause"))
    }

    /*
     * PUT /suspended with playerId + 0/1 flag.
     *
     * Purpose: intentional AFK so handshake_miss does not drop the
     * seat while the human marks AFK or pauses interaction.
     *
     * Parameters:
     *   wantSuspended — true to hold past handshake_miss.
     *
     * Returns: true when the server accepted the change.
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
        return(flagAccepted(resp, "/suspended"))
    }

    /*
     * PUT /order for explore / take / trade / move / ambush.
     *
     * Purpose: list-client fleet dispatch (TUNING-PLAYABLE B2).
     * Trailing hulls peels a subset from a multi-hull sit stack
     * (0 = whole fleet).
     *
     * Parameters:
     *   fleetId — owned fleet id.
     *   order — order string.
     *   destPlanetId — destination rock.
     *   hulls — subset size; 0 means the whole stack.
     *
     * Returns: true when the server queued the order.
     */
    bool putOrder(
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls) {
        lastRejectReason = ""
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
     * PUT /recall for a seat-owned fleet.
     *
     * Purpose: same-tick cancel or in-flight recall.
     *
     * Parameters:
     *   fleetId — owned fleet id.
     *
     * Returns: true when the server recorded the recall.
     */
    bool putRecall(int64 fleetId) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(fleetId)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/recall", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/recall"))
    }

    /*
     * PUT /design to start non-instant development.
     *
     * Purpose: Ships tab Start develop (RULES §5.3).
     *
     * Parameters:
     *   name — design name.
     *   speed — speed Entry text (fp64 parse on server).
     *   hop — hop reach Entry text.
     *   size — size Entry text (also cost basis).
     *   cargo — cargo hold Entry text.
     *   kind — scout / colony / defense / war.
     *
     * Returns: true when the server queued development.
     */
    bool putDesign(
        String name,
        String speed,
        String hop,
        String size,
        String cargo,
        String kind) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeString(name)
        w.writeString(speed)
        w.writeString(hop)
        w.writeString(size)
        w.writeString(cargo)
        w.writeString(kind)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/design", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/design"))
    }

    /*
     * PUT /build to queue a yard hull.
     *
     * Purpose: Ships tab Queue build.
     *
     * Parameters:
     *   planetId — owned productive shipyard.
     *   designId — ready design id.
     *
     * Returns: true when the BuildJob was queued.
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
     * PUT /reclaim-hulls for sitting hulls at a yard.
     *
     * Purpose: Ships tab Reclaim hulls (RULES §5.2).
     *
     * Parameters:
     *   fleetId — sitting fleet at a shipyard.
     *   hulls — hull count to reclaim.
     *
     * Returns: true when a ReclaimJob was queued.
     */
    bool putReclaimHulls(int64 fleetId, int64 hulls) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(fleetId)
        w.writeU32(hulls)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/reclaim-hulls", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/reclaim-hulls"))
    }

    /*
     * PUT /fleet to create a named empty sitting fleet.
     *
     * Purpose: CPL-101 Fleets create chrome — empty container at an
     * owned planet; assign fills it from unassigned stock.
     *
     * Parameters:
     *   planetId — owned planet where the empty fleet sits.
     *   fleetName — unique per-seat label (non-empty).
     *
     * Returns: true when the server created the fleet. Reject
     * reason lands in lastRejectReason when present.
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
     * PUT /assign to move type+qty from unassigned stock into a fleet.
     *
     * Purpose: CPL-101 assign chrome. Over-assign rejects with a
     * reason string for the human error dialog.
     *
     * Parameters:
     *   fleetId — sitting owned fleet at a planet.
     *   typeName — design name to assign.
     *   qty — hulls to move (> 0).
     *
     * Returns: true when assigned. lastRejectReason set on reject.
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
     * PUT /reclaim-stock for unassigned hulls at a yard.
     *
     * Purpose: Ships inventory reclaim path (CPL-101) — design +
     * planet + qty, not a fleet id.
     *
     * Parameters:
     *   planetId — owned shipyard planet staging the stock.
     *   designId — type to reclaim.
     *   hulls — count to reclaim.
     *
     * Returns: true when a ReclaimJob was queued.
     */
    bool putReclaimStock(
        int64 planetId, int64 designId, int64 hulls) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(planetId)
        w.writeU32(designId)
        w.writeU32(hulls)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/reclaim-stock", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/reclaim-stock"))
    }

    /*
     * PUT /budget for an owned planet allocation %.
     *
     * Purpose: Planets-tab budget Scale (DIALOGS §4.2).
     *
     * Parameters:
     *   planetId — owned rock.
     *   allocationPct — 0..100 production spend fraction.
     *
     * Returns: true when the server stored the value.
     */
    bool putBudget(int64 planetId, int64 allocationPct) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(planetId)
        int64 pct = allocationPct
        if (pct < 0) {
            pct = 0
        }
        if (pct > 100) {
            pct = 100
        }
        w.writeU8(pct)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/budget", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/budget"))
    }

    /*
     * PUT /message private or broadcast compose.
     *
     * Purpose: Digest-tab compose-to-pick (RULES §13).
     *
     * Parameters:
     *   toPlayerId — known competitor (ignored when broadcast).
     *   text — non-empty body.
     *   broadcast — true for send-to-all-known.
     *
     * Returns: true when the server queued the message.
     */
    bool putMessage(
        int64 toPlayerId, String text, bool broadcast) {
        WireBytes w = WireBytes()
        w.writeU32(config.playerId)
        w.writeU32(toPlayerId)
        if (broadcast) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeString(text)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/message", w.bytes)
        buffer resp = exchange(EnvelopeCodec().encode(env))
        return(flagAccepted(resp, "/message"))
    }

    /*
     * Decode a flag-ack response (accepted u8 + tick + ended).
     *
     * Purpose: share pause / order / recall / handshake ack shape.
     * When accepted is 0 and a trailing reason string is present
     * (PUT /order, /assign, /fleet, …), store it in lastRejectReason
     * for the GUI.
     *
     * Parameters:
     *   resp — raw response envelope bytes.
     *   expectPath — path that must match.
     *
     * Returns: true when path matches and accepted == 1.
     */
    bool flagAccepted(buffer resp, String expectPath) {
        lastRejectReason = ""
        if (resp.length < 1) {
            return(false)
        }
        Envelope out = EnvelopeCodec().decode(resp)
        if (not out.ok or not out.path.equals(expectPath)) {
            return(false)
        }
        WireBytes r = WireBytes()
        r.setRead(out.body)
        int64 accepted = r.readU8()
        if (not r.ok()) {
            return(false)
        }
        if (accepted == 1) {
            return(true)
        }
        if (r.offset + 5 <= out.body.length) {
            r.readU32()
            r.readU8()
            if (r.ok() and r.offset < out.body.length) {
                lastRejectReason = r.readString()
            }
        }
        return(false)
    }
}
