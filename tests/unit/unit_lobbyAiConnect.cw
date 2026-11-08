/*
 * tests/unit/unit_lobbyAiConnect.cw — lobby AI connect must not end.
 *
 * Regression for post-#60/#61: connecting an AI in lobby must not
 * advance ticks without go, and must not trip all-humans-quit /
 * eliminate-all when presence ages or the sole seat is AI-marked.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial lobby AI-connect regression unit.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- AI allocate in lobby: seat + token, no ticks, not ended ---
    State game = State()
    game.startClosed(29u, 0)
    GameDriver drv = GameDriver(game, true, "", false, 1000u)
    drv.softMaxPlayers = 0
    if (not drv.inLobby()) {
        ok = false
    }
    int64 seat = drv.handshakeAllocateAs(true)
    if (seat != 0) {
        ok = false
    }
    Player ai = drv.game.players[0]
    if (ok and ai.human) {
        ok = false
    }
    if (ok and not ai.homeGranted) {
        ok = false
    }
    buffer token = drv.presence.reconnectToken(0)
    if (ok and token.length != PresenceBook.TOKEN_BYTES) {
        ok = false
    }
    if (ok and drv.game.tickCount != 0) {
        ok = false
    }
    if (ok and drv.game.ended) {
        ok = false
    }

    # --- many maybeTick cycles in lobby: still tick 0 / not ended ---
    int64 step = 0
    while (step < 20) {
        if (drv.maybeTick()) {
            ok = false
        }
        step = step + 1
    }
    if (ok and drv.game.tickCount != 0) {
        ok = false
    }
    if (ok and drv.advanceTicks(3) != 0) {
        ok = false
    }
    if (ok and drv.game.ended) {
        ok = false
    }
    if (ok and not drv.inLobby()) {
        ok = false
    }

    # --- miss-drop in lobby (even mis-marked human) does not end ---
    State humanish = State()
    humanish.startClosed(31u, 0)
    GameDriver hum = GameDriver(humanish, true, "", false, 500u)
    if (hum.handshakeAllocate() != 0) {
        ok = false
    }
    Player h0 = hum.game.players[0]
    if (ok and not h0.human) {
        ok = false
    }
    hum.clock.advanceMs(2000u)
    hum.maybeTick()
    Player droppedLobby = hum.game.players[0]
    if (ok and not droppedLobby.dropped) {
        ok = false
    }
    if (ok and hum.game.ended) {
        ok = false
    }
    if (ok and hum.game.tickCount != 0) {
        ok = false
    }
    if (ok and not hum.inLobby()) {
        ok = false
    }

    # --- after go, sole human drop ends; sole AI drop does not ---
    State runH = State()
    runH.startClosed(33u, 0)
    GameDriver runHum = GameDriver(runH, true, "", false, 500u)
    if (runHum.handshakeAllocate() != 0) {
        ok = false
    }
    if (ok and not runHum.go()) {
        ok = false
    }
    runHum.clock.advanceMs(2000u)
    runHum.maybeTick()
    if (ok and not runHum.game.ended) {
        ok = false
    }
    if (ok and not runHum.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    runHum.close()

    State runA = State()
    runA.startClosed(35u, 0)
    GameDriver runAi = GameDriver(runA, true, "", false, 500u)
    if (runAi.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and not runAi.go()) {
        ok = false
    }
    runAi.clock.advanceMs(2000u)
    # First maybeTick may fire a cadence tick (everFired bootstrap)
    # and/or apply the miss-drop; AI-only must not all-humans-quit.
    runAi.maybeTick()
    if (ok and runAi.game.ended) {
        ok = false
    }
    if (ok and runAi.inLobby()) {
        ok = false
    }
    runAi.close()

    drv.close()
    hum.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
