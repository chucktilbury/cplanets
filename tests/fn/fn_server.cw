/*
 * tests/fn/fn_server.cw — Phase F driver cluster (in-process).
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
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-08  Suspended hold past handshake_miss; clear resumes.
 *   2026-11-08  Lobby: go() before injectable advance.
 *   2026-11-08  Quit end-status requires go() (lobby gate).
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
    game.ensureAllSeatHomes()
    GameDriver driver = GameDriver(
        game, true, "", true, 10000u)
    if (not driver.store.openOk) {
        ok = false
    }
    if (ok and not driver.inLobby()) {
        ok = false
    }
    # Lobby blocks injectable advance until go.
    if (ok and driver.advanceTicks(1) != 0) {
        ok = false
    }
    if (ok and not driver.go()) {
        ok = false
    }
    if (ok and driver.inLobby()) {
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
    solo.ensureAllSeatHomes()
    GameDriver soloDrv = GameDriver(
        solo, true, "", false, 10000u)
    if (ok and not soloDrv.go()) {
        ok = false
    }
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

    # --- suspended holds past handshake_miss; clear resumes drop ---
    if (ok and not driver.handshake(0)) {
        ok = false
    }
    if (ok and not driver.presence.isConnected(0)) {
        ok = false
    }
    if (ok and not driver.setSuspended(0, true)) {
        ok = false
    }
    if (ok and not driver.presence.isSuspended(0)) {
        ok = false
    }
    driver.clock.advanceMs(20000u)
    driver.scanPresenceDrops()
    if (ok and not driver.presence.isConnected(0)) {
        ok = false
    }
    if (ok and not driver.presence.isSuspended(0)) {
        ok = false
    }
    if (ok and not driver.setSuspended(0, false)) {
        ok = false
    }
    if (ok and driver.presence.isSuspended(0)) {
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

    # --- all humans quit ends game (only after go / running) ---
    State endGame = State()
    endGame.startClosed(17u, 2)
    endGame.ensureAllSeatHomes()
    endGame.markPlayerAi(1)
    GameDriver endDrv = GameDriver(
        endGame, true, "", false, 10000u)
    # Lobby suppresses end-status; quit before go must not end.
    if (ok and not endDrv.quitPlayer(0)) {
        ok = false
    }
    if (ok and endDrv.game.ended) {
        ok = false
    }
    # Fresh session: go, then quit the sole human while AI remains.
    State endRun = State()
    endRun.startClosed(19u, 2)
    endRun.ensureAllSeatHomes()
    endRun.markPlayerAi(1)
    GameDriver endRunDrv = GameDriver(
        endRun, true, "", false, 10000u)
    if (ok and not endRunDrv.go()) {
        ok = false
    }
    if (ok and not endRunDrv.quitPlayer(0)) {
        ok = false
    }
    if (ok and not endRunDrv.game.ended) {
        ok = false
    }
    if (ok and not endRunDrv.game.endReason.equals(
        "all_humans_quit")) {
        ok = false
    }
    endDrv.close()
    endRunDrv.close()

    driver.close()
    print(ok)
    print("\n")
}
