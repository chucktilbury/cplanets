/*
 * src/server/handler.cw — verb + admin dispatch (Phase F).
 *
 * Decodes one envelope request and returns one envelope response
 * against a GameDriver. Paths: GET /state, PUT /policy, GET
 * /digest|/events, PUT /handshake, PUT /quit, PUT /pause,
 * PUT /admin/advance. No ready-barrier verb (PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial server message handler.
 *   2026-11-05  Phase G: GET /state uses seat-scoped list view.
 */

include "driver.cw"
include "../lib/envelope.cw"
include "../lib/verbGetDigest.cw"
include "../lib/verbGetState.cw"
include "../lib/verbPutPolicy.cw"
include "../lib/wireBytes.cw"

/*
 * ServerHandler maps one request frame to one response frame.
 *
 * Owns verb codecs and routes admin/presence paths that Phase E
 * left out of lib. One writer: the GameDriver behind it.
 */
class ServerHandler {
    GameDriver driver
    VerbGetState getState
    VerbPutPolicy putPolicy
    VerbGetDigest getDigest
    EnvelopeCodec codec

    /*
     * Construct a handler bound to a driver.
     *
     * Purpose: share verb codecs across request handling.
     *
     * Parameters:
     *   gameDriver — sole-writer GameDriver.
     *
     * Returns: ServerHandler ready for handleFrame.
     */
    ServerHandler(GameDriver gameDriver) {
        driver = gameDriver
        getState = VerbGetState()
        putPolicy = VerbPutPolicy()
        getDigest = VerbGetDigest()
        codec = EnvelopeCodec()
    }

    /*
     * Handle one complete envelope request buffer.
     *
     * Purpose: TCP / in-process entry; never ticks except via
     * /admin/advance or the caller's maybeTick loop.
     *
     * Parameters:
     *   request — complete envelope bytes.
     *
     * Returns: response envelope bytes, or empty on hard failure.
     */
    buffer handleFrame(buffer request) {
        Envelope env = codec.decode(request)
        if (not env.ok) {
            return(errorFrame("bad_envelope"))
        }
        if (env.verb == Envelope.VERB_GET
            and env.path.equals("/state")) {
            return(handleGetState(request))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/policy")) {
            return(handlePutPolicy(request))
        }
        if (env.verb == Envelope.VERB_GET
            and (env.path.equals("/digest")
                or env.path.equals("/events"))) {
            return(handleGetDigest(request))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/handshake")) {
            return(handleHandshake(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/quit")) {
            return(handleQuit(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/pause")) {
            return(handlePause(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/admin/advance")) {
            return(handleAdvance(env.body))
        }
        return(errorFrame("unknown_path"))
    }

    /*
     * Serve GET /state from the published blob.
     *
     * Purpose: clients read published snapshot; never tick.
     *
     * Parameters:
     *   request — full GET /state envelope.
     *
     * Returns: GET /state response envelope bytes.
     */
    buffer handleGetState(buffer request) {
        GetStateRequest req = getState.decodeRequest(request)
        if (req.playerId < 0) {
            return(errorFrame("bad_get_state"))
        }
        PublishCodec codec = PublishCodec()
        buffer blob = codec.encodeStateView(
            driver.game, driver.policies, req.playerId)
        GetStateResponse resp = GetStateResponse(
            driver.game.tickCount, blob)
        return(getState.encodeResponse(resp))
    }

    /*
     * Serve PUT /policy into the last-policy table.
     *
     * Purpose: anytime write; next tick snapshots it.
     *
     * Parameters:
     *   request — full PUT /policy envelope.
     *
     * Returns: PUT /policy response envelope bytes.
     */
    buffer handlePutPolicy(buffer request) {
        PutPolicyRequest req = putPolicy.decodeRequest(request)
        if (req.playerId < 0) {
            return(errorFrame("bad_put_policy"))
        }
        bool ok = driver.putPolicy(req.playerId, req.policyBlob)
        PutPolicyResponse resp = PutPolicyResponse(
            ok, driver.game.tickCount)
        return(putPolicy.encodeResponse(resp))
    }

    /*
     * Serve GET /digest or GET /events.
     *
     * Purpose: newspaper published with each tick.
     *
     * Parameters:
     *   request — full GET digest/events envelope.
     *
     * Returns: matching response envelope bytes.
     */
    buffer handleGetDigest(buffer request) {
        GetDigestRequest req = getDigest.decodeRequest(request)
        if (req.playerId < 0) {
            return(errorFrame("bad_get_digest"))
        }
        GetDigestResponse resp = GetDigestResponse(
            driver.game.tickCount,
            driver.publishedDigest)
        Envelope env = codec.decode(request)
        return(getDigest.encodeResponse(env.path, resp))
    }

    /*
     * Serve PUT /handshake body (playerId u32).
     *
     * Purpose: presence keep-alive distinct from policy PUT.
     *
     * Parameters:
     *   body — uncompressed request body.
     *
     * Returns: ack envelope on /handshake.
     */
    buffer handleHandshake(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_handshake"))
        }
        bool ok = driver.handshake(player)
        return(flagAck("/handshake", ok))
    }

    /*
     * Serve PUT /quit body (playerId u32).
     *
     * Purpose: voluntary leave; may end the game when all humans
     * are gone.
     *
     * Parameters:
     *   body — uncompressed request body.
     *
     * Returns: ack envelope on /quit.
     */
    buffer handleQuit(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_quit"))
        }
        bool ok = driver.quitPlayer(player)
        return(flagAck("/quit", ok))
    }

    /*
     * Serve PUT /pause body (flag u8).
     *
     * Purpose: pause only with exactly one human.
     *
     * Parameters:
     *   body — uncompressed request body.
     *
     * Returns: ack envelope on /pause.
     */
    buffer handlePause(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 flag = r.readU8()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_pause"))
        }
        bool ok = driver.setPaused(flag == 1)
        return(flagAck("/pause", ok))
    }

    /*
     * Serve PUT /admin/advance body (count u32).
     *
     * Purpose: injectable-clock test / CI advance N ticks.
     *
     * Parameters:
     *   body — uncompressed request body.
     *
     * Returns: advance result envelope (accepted + fired count).
     */
    buffer handleAdvance(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 count = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_advance"))
        }
        int64 fired = driver.advanceTicks(count)
        WireBytes w = WireBytes()
        if (driver.clock.injectable) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(fired)
        w.writeU32(driver.game.tickCount)
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, "/admin/advance", w.bytes)
        return(codec.encode(env))
    }

    /*
     * Build a simple flag ack on an arbitrary path.
     *
     * Purpose: handshake / quit / pause responses share one shape
     * (u8 accepted, u32 tick).
     *
     * Parameters:
     *   path — response path echo.
     *   accepted — success flag.
     *
     * Returns: envelope bytes.
     */
    buffer flagAck(String path, bool accepted) {
        WireBytes w = WireBytes()
        if (accepted) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(driver.game.tickCount)
        if (driver.game.ended) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        Envelope env = Envelope().make(
            Envelope.VERB_PUT, path, w.bytes)
        return(codec.encode(env))
    }

    /*
     * Build a GET /error-style failure envelope.
     *
     * Purpose: tell the client the request was rejected without
     * crashing the accept loop.
     *
     * Parameters:
     *   reason — short ASCII reason string as body.
     *
     * Returns: envelope bytes on path /error.
     */
    buffer errorFrame(String reason) {
        WireBytes w = WireBytes()
        w.writeString(reason)
        Envelope env = Envelope().make(
            Envelope.VERB_GET, "/error", w.bytes)
        return(codec.encode(env))
    }
}
