/*
 * src/fn_server.cw — Phase F driver cluster (in-process).
 *
 * Injectable clock: PUT policies, advance N ticks, GET-shaped
 * publish blobs, pause one-human only, handshake≠drop, quit ends
 * when all humans gone. No TCP here (Python smoke covers listen).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial server function program.
 */

include "lib/envelope.cw"
include "lib/verbGetDigest.cw"
include "lib/verbGetState.cw"
include "lib/verbPutPolicy.cw"
include "lib/wireBytes.cw"
include "server/driver.cw"
include "server/handler.cw"

start {
    bool ok = true

    # --- injectable advance + policy anytime (no ready barrier) ---
    State game = State()
    game.startClosed(11u, 2)
    GameDriver driver = GameDriver(
        game, true, "", true, 10000u)
    if (not driver.store.openOk) {
        ok = false
    }
    buffer pol = buffer[]
    pol.append(7)
    pol.append(8)
    if (ok and not driver.putPolicy(0, pol)) {
        ok = false
    }
    if (ok and driver.game.tickCount != 0) {
        ok = false
    }
    int64 fired = driver.advanceTicks(3)
    if (ok and fired != 3) {
        ok = false
    }
    if (ok and driver.game.tickCount != 3) {
        ok = false
    }
    if (ok and driver.store.latestTick() != 3) {
        ok = false
    }
    if (ok and not driver.policies.has(0)) {
        ok = false
    }
    if (ok and driver.game.locked != true) {
        ok = false
    }

    # --- handler verbs round-trip without a second tick ---
    ServerHandler handler = ServerHandler(driver)
    VerbPutPolicy putV = VerbPutPolicy()
    buffer pol2 = buffer[]
    pol2.append(3)
    buffer putFrame = putV.encodeRequest(
        PutPolicyRequest(1, pol2))
    buffer putResp = handler.handleFrame(putFrame)
    PutPolicyResponse putAck = putV.decodeResponse(putResp)
    if (ok and not putAck.accepted) {
        ok = false
    }
    if (ok and putAck.tick != 3) {
        ok = false
    }
    VerbGetState getV = VerbGetState()
    buffer getFrame = getV.encodeRequest(GetStateRequest(0, 0))
    buffer getResp = handler.handleFrame(getFrame)
    GetStateResponse stateAck = getV.decodeResponse(getResp)
    if (ok and stateAck.tick != 3) {
        ok = false
    }
    if (ok and stateAck.stateBlob.length < 1) {
        ok = false
    }
    VerbGetDigest digV = VerbGetDigest()
    buffer digFrame = digV.encodeRequest(
        "/digest", GetDigestRequest(0, 0))
    buffer digResp = handler.handleFrame(digFrame)
    GetDigestResponse digAck = digV.decodeResponse(digResp)
    if (ok and digAck.tick != 3) {
        ok = false
    }

    # --- advance via admin path ---
    WireBytes adv = WireBytes()
    adv.writeU32(2)
    Envelope advEnv = Envelope().make(
        Envelope.VERB_PUT, "/admin/advance", adv.bytes)
    buffer advFrame = EnvelopeCodec().encode(advEnv)
    buffer advResp = handler.handleFrame(advFrame)
    Envelope advOut = EnvelopeCodec().decode(advResp)
    if (ok and not advOut.ok) {
        ok = false
    }
    if (ok and driver.game.tickCount != 5) {
        ok = false
    }

    # --- pause: two humans → not offered; one human → offered ---
    if (ok and driver.pauseOffered()) {
        ok = false
    }
    if (ok and driver.setPaused(true)) {
        ok = false
    }
    State solo = State()
    solo.startClosed(13u, 1)
    GameDriver soloDrv = GameDriver(
        solo, true, "", false, 10000u)
    if (ok and not soloDrv.pauseOffered()) {
        ok = false
    }
    if (ok and not soloDrv.setPaused(true)) {
        ok = false
    }
    if (ok and soloDrv.advanceTicks(1) != 0) {
        ok = false
    }
    if (ok and not soloDrv.setPaused(false)) {
        ok = false
    }
    if (ok and soloDrv.advanceTicks(1) != 1) {
        ok = false
    }
    soloDrv.close()

    # --- handshake vs drop ---
    if (ok and not driver.handshake(0)) {
        ok = false
    }
    if (ok and not driver.presence.isConnected(0)) {
        ok = false
    }
    driver.clock.advanceMs(20000u)
    driver.scanPresenceDrops()
    if (ok and driver.presence.isConnected(0)) {
        ok = false
    }
    Player dropped = driver.game.players[0]
    if (ok and not dropped.dropped) {
        ok = false
    }

    # --- all humans quit ends game ---
    State endGame = State()
    endGame.startClosed(17u, 2)
    endGame.markPlayerAi(1)
    GameDriver endDrv = GameDriver(
        endGame, true, "", false, 10000u)
    if (ok and not endDrv.quitPlayer(0)) {
        ok = false
    }
    if (ok and not endDrv.game.ended) {
        ok = false
    }
    if (ok and not endDrv.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    endDrv.close()

    driver.close()
    print(ok)
    print("\n")
}
