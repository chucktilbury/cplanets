/*
 * src/client/session.cw — human TCP session (Phase G).
 *
 * Same protocol as the AI client: handshake, GET /state,
 * PUT /policy, GET /digest. Never calls tick; never opens the
 * universe DB (RULES §2 / PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial HumanSession request helpers.
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
}
