/*
 * tests/unit/unit_humanSeatGo.cw — human seat + go / last-human exit.
 *
 * Lobby-abandoned humans must not block go when another live human
 * remains, but when the last human is gone (quit/drop/retire) the
 * server must all_humans_quit — including when AI seats remain
 * (RULES §2: no AI-only zombie match). Human allocate must restore
 * human=true when reusing a free former AI seat (CPL-108).
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial human-seat / go-quit regression unit.
 *   2026-11-10  CPL-108: last human gone → all_humans_quit on go;
 *               human reuse of former AI seat stays human.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- AI + lobby-abandoned human, no live human: go ends ---
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
    # Last human already gone → all_humans_quit even with AI live.
    if (ok and not bothDrv.game.ended) {
        ok = false
    }
    if (ok and not bothDrv.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    Player retired = bothDrv.game.players[1]
    if (ok and not retired.human) {
        ok = false
    }
    if (ok and not retired.quit) {
        ok = false
    }
    bothDrv.close()

    # --- AI + live human + abandoned other: go must not end ---
    State keepLive = State()
    keepLive.startClosed(42u, 0)
    GameDriver keepLiveDrv = GameDriver(
        keepLive, true, "", false, 5000u)
    keepLiveDrv.softMaxPlayers = 0
    if (keepLiveDrv.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and keepLiveDrv.handshakeAllocate() != 1) {
        ok = false
    }
    if (ok and keepLiveDrv.handshakeAllocate() != 2) {
        ok = false
    }
    if (ok and not keepLiveDrv.dropPlayer(2)) {
        ok = false
    }
    if (ok and not keepLiveDrv.go()) {
        ok = false
    }
    if (ok and keepLiveDrv.game.ended) {
        ok = false
    }
    Player liveKept = keepLiveDrv.game.players[1]
    if (ok and not liveKept.human) {
        ok = false
    }
    if (ok and liveKept.quit) {
        ok = false
    }
    Player abandoned = keepLiveDrv.game.players[2]
    if (ok and not abandoned.quit) {
        ok = false
    }
    if (ok and not abandoned.human) {
        ok = false
    }
    keepLiveDrv.close()

    # --- sole human miss-drop in lobby + go: all_humans_quit ---
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
    if (ok and not soloDrv.game.ended) {
        ok = false
    }
    if (ok and not soloDrv.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    Player soloRetired = soloDrv.game.players[0]
    if (ok and not soloRetired.human) {
        ok = false
    }
    if (ok and not soloRetired.quit) {
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

    # --- human reuses free former AI seat: human=true + quit ends ---
    State reuse = State()
    reuse.startClosed(49u, 0)
    GameDriver reuseDrv = GameDriver(reuse, true, "", false, 5000u)
    reuseDrv.softMaxPlayers = 0
    if (reuseDrv.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and not reuseDrv.dropPlayer(0)) {
        ok = false
    }
    if (ok and reuseDrv.presence.hasReconnectToken(0)) {
        ok = false
    }
    if (ok and reuseDrv.handshakeAllocate() != 0) {
        ok = false
    }
    Player reused = reuseDrv.game.players[0]
    if (ok and not reused.human) {
        ok = false
    }
    if (ok and not reuseDrv.go()) {
        ok = false
    }
    if (ok and reuseDrv.game.ended) {
        ok = false
    }
    if (ok and not reuseDrv.quitPlayer(0)) {
        ok = false
    }
    if (ok and not reuseDrv.game.ended) {
        ok = false
    }
    if (ok and not reuseDrv.game.endReason.equals("all_humans_quit")) {
        ok = false
    }
    reuseDrv.close()

    # --- pure AI (never a human): go must not all_humans_quit ---
    State pureAi = State()
    pureAi.startClosed(51u, 0)
    GameDriver pureAiDrv = GameDriver(
        pureAi, true, "", false, 5000u)
    if (pureAiDrv.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and not pureAiDrv.go()) {
        ok = false
    }
    if (ok and pureAiDrv.game.ended) {
        ok = false
    }
    pureAiDrv.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
