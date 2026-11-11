/*
 * tests/unit/unit_lobbyHoldGhosts.cw — lobby hold + no ghost seats.
 *
 * First (and later) clients must not leave lobby or advance ticks,
 * with or without a loaded scenario. Lobby miss-drop / explicit drop
 * clears reconnect tokens so the next allocate reuses the seat
 * instead of growing a ghost. After go, tokens stay on drop.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial lobby-hold / no-ghost regression unit.
 *   2026-11-09  Reject order/build in lobby; publishPausedFlag.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- builtin (no scenario): multi-seat lobby, no ticks ---
    State bare = State()
    bare.startClosed(41u, 0)
    GameDriver lobby = GameDriver(bare, true, "", false, 500u)
    lobby.softMaxPlayers = 0
    if (not lobby.inLobby()) {
        ok = false
    }
    if (lobby.handshakeAllocate() != 0) {
        ok = false
    }
    if (lobby.handshakeAllocate() != 1) {
        ok = false
    }
    if (lobby.handshakeAllocateAs(true) != 2) {
        ok = false
    }
    int64 step = 0
    while (step < 30) {
        if (lobby.maybeTick()) {
            ok = false
        }
        step = step + 1
    }
    if (ok and lobby.game.tickCount != 0) {
        ok = false
    }
    if (ok and lobby.advanceTicks(2) != 0) {
        ok = false
    }
    if (ok and not lobby.inLobby()) {
        ok = false
    }
    if (ok and lobby.seatedCount() != 3) {
        ok = false
    }
    # Play verbs must wait for go — connect alone is not serve-start.
    if (ok and not lobby.publishPausedFlag()) {
        ok = false
    }
    if (ok and lobby.issueOwnedOrder(0, 1, "explore", 1, 0)) {
        ok = false
    }
    if (ok and lobby.lastOrderError.find("lobby") < 0) {
        ok = false
    }
    if (ok and lobby.queueOwnedBuild(0, 0, 0, 1)) {
        ok = false
    }
    if (ok and lobby.game.builds.length != 0) {
        ok = false
    }

    # --- lobby drop frees seat (no ghost grow) ---
    if (ok and not lobby.dropPlayer(1)) {
        ok = false
    }
    if (ok and lobby.presence.hasReconnectToken(1)) {
        ok = false
    }
    if (ok and lobby.handshakeAllocate() != 1) {
        ok = false
    }
    if (ok and lobby.seatedCount() != 3) {
        ok = false
    }

    # --- lobby miss-scan also frees the token ---
    if (ok and not lobby.presence.handshake(0, lobby.clock.now())) {
        ok = false
    }
    lobby.clock.advanceMs(2000u)
    lobby.maybeTick()
    Player missed = lobby.game.players[0]
    if (ok and not missed.dropped) {
        ok = false
    }
    if (ok and lobby.presence.hasReconnectToken(0)) {
        ok = false
    }
    if (ok and lobby.handshakeAllocate() != 0) {
        ok = false
    }
    if (ok and not lobby.inLobby()) {
        ok = false
    }
    if (ok and lobby.game.tickCount != 0) {
        ok = false
    }
    lobby.close()

    # --- scenario path (explicit Scenario): still lobby until go ---
    Scenario loaded = Scenario()
    loaded.worldCount = 8
    loaded.galaxyRadius = 10.0
    loaded.clampTickPeriod()
    State scen = State()
    scen.startFromScenario(loaded, 43u, 0)
    # Miss window above one tick period so advance after go does
    # not handshake_miss-drop seats mid-fire.
    GameDriver withSetup = GameDriver(
        scen, true, "", false, 60000u)
    # Soft max 2 so a running drop cannot grow a third seat when
    # testing that empty allocate cannot steal a token-held seat.
    withSetup.softMaxPlayers = 2
    if (ok and not withSetup.inLobby()) {
        ok = false
    }
    if (ok and withSetup.handshakeAllocateAs(true) != 0) {
        ok = false
    }
    if (ok and withSetup.handshakeAllocate() != 1) {
        ok = false
    }
    step = 0
    while (step < 20) {
        if (withSetup.maybeTick()) {
            ok = false
        }
        step = step + 1
    }
    if (ok and withSetup.game.tickCount != 0) {
        ok = false
    }
    if (ok and withSetup.advanceTicks(1) != 0) {
        ok = false
    }
    if (ok and not withSetup.inLobby()) {
        ok = false
    }
    # Go unlocks ticks; drop then keeps token (running reclaim).
    if (ok and not withSetup.go()) {
        ok = false
    }
    if (ok and withSetup.inLobby()) {
        ok = false
    }
    # Refresh presence so the injectable advance does not age-drop.
    if (ok and withSetup.handshakeKeepAlive(0) != 0) {
        ok = false
    }
    if (ok and withSetup.handshakeKeepAlive(1) != 1) {
        ok = false
    }
    if (ok and withSetup.advanceTicks(1) != 1) {
        ok = false
    }
    buffer tok = withSetup.presence.reconnectToken(0)
    if (ok and tok.length != PresenceBook.TOKEN_BYTES) {
        ok = false
    }
    if (ok and not withSetup.dropPlayer(0)) {
        ok = false
    }
    if (ok and not withSetup.presence.hasReconnectToken(0)) {
        ok = false
    }
    if (ok and withSetup.handshakeAllocate() >= 0) {
        ok = false
    }
    if (ok and withSetup.handshakeReclaim(tok) != 0) {
        ok = false
    }
    withSetup.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
