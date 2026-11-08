/*
 * src/server/handler.cw — verb + admin dispatch (Phase F).
 *
 * Decodes one envelope request and returns one envelope response
 * against a GameDriver. Paths: GET /state, PUT /policy, GET
 * /digest|/events, PUT /handshake, PUT /quit, PUT /pause,
 * PUT /order, PUT /recall, PUT /design, PUT /build,
 * PUT /reclaim-hulls, PUT /budget, PUT /message,
 * PUT /admin/advance. No ready-barrier verb (PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial server message handler.
 *   2026-11-05  Phase G: GET /state uses seat-scoped list view.
 *   2026-11-06  TUNING B: PUT /order, PUT /recall; pause in state.
 *   2026-11-07  Ship create: PUT /design, /build, /reclaim-hulls.
 *   2026-11-07  Planet budget + private/broadcast compose.
 *   2026-11-07  PUT /order optional trailing hulls peel count.
 *   2026-11-07  Rejected /order ack carries lastOrderError string.
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
            and env.path.equals("/order")) {
            return(handleOrder(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/recall")) {
            return(handleRecall(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/design")) {
            return(handleDesign(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/build")) {
            return(handleBuild(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/reclaim-hulls")) {
            return(handleReclaimHulls(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/budget")) {
            return(handleBudget(env.body))
        }
        if (env.verb == Envelope.VERB_PUT
            and env.path.equals("/message")) {
            return(handleMessage(env.body))
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
            driver.game,
            driver.policies,
            req.playerId,
            driver.paused)
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
        buffer blob = driver.digestForSeat(req.playerId)
        GetDigestResponse resp = GetDigestResponse(
            driver.game.tickCount, blob)
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
     * Serve PUT /order body (player, fleet, dest, order [, hulls]).
     *
     * Purpose: list-client dispatch for explore/take/trade/…
     * (TUNING-PLAYABLE B2). Ownership checked in the driver.
     * Optional trailing hulls peels a subset from a sitting stack
     * (0 or omitted = whole fleet).
     *
     * Parameters:
     *   body — playerId u32, fleetId u32, destPlanetId u32,
     *          order string, optional hulls u32.
     *
     * Returns: ack envelope on /order.
     */
    buffer handleOrder(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 fleet = r.readU32()
        int64 dest = r.readU32()
        String order = r.readString()
        int64 hulls = 0
        if (r.ok() and r.offset < body.length) {
            hulls = r.readU32()
        }
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_order"))
        }
        bool ok = driver.issueOwnedOrder(
            player, fleet, order, dest, hulls)
        return(flagAckReason("/order", ok, driver.lastOrderError))
    }

    /*
     * Serve PUT /recall body (playerId u32, fleetId u32).
     *
     * Purpose: same-tick cancel or in-flight recall (RULES §5.2).
     *
     * Parameters:
     *   body — uncompressed request body.
     *
     * Returns: ack envelope on /recall.
     */
    buffer handleRecall(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 fleet = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_recall"))
        }
        bool ok = driver.recallOwnedFleet(player, fleet)
        return(flagAck("/recall", ok))
    }

    /*
     * Serve PUT /design body (player + draft fields as strings).
     *
     * Purpose: start non-instant design development from list
     * Entries (DIALOGS §6). Kind selects scout/colony/defense/
     * war flags; weapons/shields wait on Design fields.
     *
     * Parameters:
     *   body — playerId u32, name/speed/hop/size/cargo/kind
     *          strings.
     *
     * Returns: ack on /design with accepted when id >= 0.
     */
    buffer handleDesign(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        String name = r.readString()
        String speedText = r.readString()
        String hopText = r.readString()
        String sizeText = r.readString()
        String cargoText = r.readString()
        String kind = r.readString()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_design"))
        }
        Design draft = Design(-1)
        draft.name = name
        draft.speed = speedText.toFp64()
        draft.hopReach = hopText.toFp64()
        draft.size = sizeText.toFp64()
        draft.cargoHold = cargoText.toFp64()
        draft.scout = kind.equals("scout")
        draft.colony = kind.equals("colony")
        draft.defense = kind.equals("defense")
        int64 id = driver.queueOwnedDesign(player, draft)
        return(flagAck("/design", id >= 0))
    }

    /*
     * Serve PUT /build body (player, planet, design).
     *
     * Purpose: queue a yard hull at a productive shipyard.
     *
     * Parameters:
     *   body — playerId u32, planetId u32, designId u32.
     *
     * Returns: ack envelope on /build.
     */
    buffer handleBuild(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 planet = r.readU32()
        int64 design = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_build"))
        }
        bool ok = driver.queueOwnedBuild(player, planet, design)
        return(flagAck("/build", ok))
    }

    /*
     * Serve PUT /reclaim-hulls body (player, fleet, hulls).
     *
     * Purpose: yard reclaim path for sitting hulls (RULES §5.2).
     *
     * Parameters:
     *   body — playerId u32, fleetId u32, hulls u32.
     *
     * Returns: ack envelope on /reclaim-hulls.
     */
    buffer handleReclaimHulls(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 fleet = r.readU32()
        int64 hulls = r.readU32()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_reclaim_hulls"))
        }
        bool ok = driver.queueOwnedReclaim(player, fleet, hulls)
        return(flagAck("/reclaim-hulls", ok))
    }

    /*
     * Serve PUT /budget body (player, planet, allocationPct).
     *
     * Purpose: per-owned-planet allocation Scale stand-in
     * (DIALOGS §4.2). Ownership checked in the driver.
     *
     * Parameters:
     *   body — playerId u32, planetId u32, allocationPct u8.
     *
     * Returns: ack envelope on /budget.
     */
    buffer handleBudget(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 planet = r.readU32()
        int64 pct = r.readU8()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_budget"))
        }
        bool ok = driver.setOwnedBudget(player, planet, pct)
        return(flagAck("/budget", ok))
    }

    /*
     * Serve PUT /message body (player, to, flags, text).
     *
     * Purpose: known-competitor private compose + broadcast
     * (RULES §13). flags bit0 = broadcast.
     *
     * Parameters:
     *   body — playerId u32, toPlayerId u32, flags u8, text.
     *
     * Returns: ack envelope on /message.
     */
    buffer handleMessage(buffer body) {
        WireBytes r = WireBytes()
        r.setRead(body)
        int64 player = r.readU32()
        int64 toPlayer = r.readU32()
        int64 flags = r.readU8()
        String text = r.readString()
        if (not r.ok() or r.offset != body.length) {
            return(errorFrame("bad_message"))
        }
        bool broadcast = ((flags % 2) == 1)
        bool ok = driver.postOwnedMessage(
            player, toPlayer, text, broadcast)
        return(flagAck("/message", ok))
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
     * (u8 accepted, u32 tick, u8 ended). No reject reason trailer.
     *
     * Parameters:
     *   path — response path echo.
     *   accepted — success flag.
     *
     * Returns: envelope bytes.
     */
    buffer flagAck(String path, bool accepted) {
        return(flagAckReason(path, accepted, ""))
    }

    /*
     * Build an ack body with an optional reject reason string.
     *
     * Purpose: PUT /order surfaces why a dispatch failed (missing
     * fleet, lock, bad dest, peel). Older clients that only read
     * the accepted u8 still work; trailing reason is ignored.
     *
     * Parameters:
     *   path — response path echo.
     *   accepted — success flag.
     *   reason — reject detail when accepted is false (may be "").
     *
     * Returns: envelope bytes.
     */
    buffer flagAckReason(String path, bool accepted, String reason) {
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
        if (not accepted and reason.length > 0) {
            w.writeString(reason)
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
