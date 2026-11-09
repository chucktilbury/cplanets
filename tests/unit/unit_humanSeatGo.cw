/*
 * tests/unit/unit_humanSeatGo.cw — human seat + go must not quit.
 *
 * Regression: a human that miss-drops in lobby (token cleared) left
 * human=true / dropped=true. Operator go then enabled end-status and
 * all_humans_quit ended the server even when AI seats were still
 * connected. go() must retire lobby-abandoned seats first; a live
 * human keep-alive path must still all_humans_quit after go on miss.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial human-seat / go-quit regression unit.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- AI still connected + lobby-abandoned human; go must not end ---
    State both = State()
    both.startClosed(41u, 0)
    GameDriver bothDrv = GameDriver(both, true, "", false, 500u)
    bothDrv.softMaxPlayers = 0
    if (bothDrv.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and bothDrv.handshakeAllocate() != 1) {
        ok = false
    }
    Player hum = bothDrv.game.players[1]
    if (ok and not hum.human) {
        ok = false
    }
    # Drop only the human in lobby (token cleared); AI stays connected.
    if (ok and not bothDrv.dropPlayer(1)) {
        ok = false
    }
    Player dropped = bothDrv.game.players[1]
    if (ok and not dropped.dropped) {
        ok = false
    }
    if (ok and bothDrv.presence.hasReconnectToken(1)) {
        ok = false
    }
    if (ok and not bothDrv.presence.isConnected(0)) {
        ok = false
    }
    if (ok and bothDrv.game.ended) {
        ok = false
    }
    if (ok and not bothDrv.go()) {
        ok = false
    }
    if (ok and bothDrv.game.ended) {
        ok = false
    }
    if (ok and bothDrv.inLobby()) {
        ok = false
    }
    Player retired = bothDrv.game.players[1]
    if (ok and retired.human) {
        ok = false
    }
    if (ok and not retired.quit) {
        ok = false
    }
    # Cadence / end-status after go must still leave AI playable.
    bothDrv.maybeTick()
    if (ok and bothDrv.game.ended) {
        ok = false
    }
    bothDrv.close()

    # --- sole human miss-drop in lobby + go: retire, do not end ---
    State solo = State()
    solo.startClosed(43u, 0)
    GameDriver soloDrv = GameDriver(solo, true, "", false, 500u)
    if (soloDrv.handshakeAllocate() != 0) {
        ok = false
    }
    soloDrv.clock.advanceMs(2000u)
    soloDrv.maybeTick()
    Player soloDropped = soloDrv.game.players[0]
    if (ok and not soloDropped.dropped) {
        ok = false
    }
    if (ok and not soloDrv.go()) {
        ok = false
    }
    if (ok and soloDrv.game.ended) {
        ok = false
    }
    Player soloRetired = soloDrv.game.players[0]
    if (ok and soloRetired.human) {
        ok = false
    }
    soloDrv.maybeTick()
    if (ok and soloDrv.game.ended) {
        ok = false
    }
    soloDrv.close()

    # --- live human through go, then miss: still all_humans_quit ---
    State live = State()
    live.startClosed(45u, 0)
    GameDriver liveDrv = GameDriver(live, true, "", false, 500u)
    if (liveDrv.handshakeAllocate() != 0) {
        ok = false
    }
    if (ok and not liveDrv.go()) {
        ok = false
    }
    if (ok and liveDrv.game.ended) {
        ok = false
    }
    liveDrv.clock.advanceMs(2000u)
    liveDrv.maybeTick()
    if (ok and not liveDrv.game.ended) {
        ok = false
    }
    if (ok and not liveDrv.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    liveDrv.close()

    # --- connected human at go is not retired ---
    State keep = State()
    keep.startClosed(47u, 0)
    GameDriver keepDrv = GameDriver(keep, true, "", false, 5000u)
    if (keepDrv.handshakeAllocate() != 0) {
        ok = false
    }
    if (ok and not keepDrv.go()) {
        ok = false
    }
    Player kept = keepDrv.game.players[0]
    if (ok and not kept.human) {
        ok = false
    }
    if (ok and kept.quit) {
        ok = false
    }
    if (ok and keepDrv.game.ended) {
        ok = false
    }
    keepDrv.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
