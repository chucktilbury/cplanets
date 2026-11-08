/*
 * tests/unit/unit_lobbyReconnect.cw — lobby gate + reconnect tokens.
 *
 * Starts in lobby (no ticks until go). Allocate issues a token;
 * drop cannot be stolen by empty handshake; reclaim restores the
 * seat; quit clears the token.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial lobby + reconnect token unit.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    State game = State()
    game.startClosed(23u, 2)
    # Miss window must exceed one tick period (default 5s) so a
    # single injectable advance does not handshake_miss-drop seats.
    GameDriver drv = GameDriver(game, true, "", false, 60000u)

    # --- lobby blocks injectable advance ---
    if (not drv.inLobby()) {
        ok = false
    }
    if (ok and drv.advanceTicks(2) != 0) {
        ok = false
    }
    if (ok and drv.game.tickCount != 0) {
        ok = false
    }

    # --- allocate issues token; second seat next ---
    int64 seat0 = drv.handshakeAllocate()
    if (seat0 != 0) {
        ok = false
    }
    buffer token0 = drv.presence.reconnectToken(0)
    if (ok and token0.length != PresenceBook.TOKEN_BYTES) {
        ok = false
    }
    int64 seat1 = drv.handshakeAllocate()
    if (ok and seat1 != 1) {
        ok = false
    }
    buffer token1 = drv.presence.reconnectToken(1)
    if (ok and token1.length != PresenceBook.TOKEN_BYTES) {
        ok = false
    }
    if (ok and drv.presence.tokensEqual(token0, token1)) {
        ok = false
    }

    # --- go unlocks ticks ---
    if (ok and not drv.go()) {
        ok = false
    }
    if (ok and drv.inLobby()) {
        ok = false
    }
    if (ok and drv.advanceTicks(1) != 1) {
        ok = false
    }
    if (ok and drv.game.tickCount != 1) {
        ok = false
    }
    # Idempotent go.
    if (ok and drv.go()) {
        ok = false
    }

    # --- drop + no steal + reclaim ---
    if (ok and not drv.dropPlayer(0)) {
        ok = false
    }
    if (ok and drv.handshakeAllocate() >= 0) {
        ok = false
    }
    if (ok and drv.handshakeKeepAlive(0) >= 0) {
        ok = false
    }
    buffer junk = buffer[]
    while (junk.length < PresenceBook.TOKEN_BYTES) {
        junk.append(9)
    }
    if (ok and drv.handshakeReclaim(junk) >= 0) {
        ok = false
    }
    if (ok and drv.handshakeReclaim(token0) != 0) {
        ok = false
    }
    if (ok and not drv.presence.isConnected(0)) {
        ok = false
    }

    # --- quit clears token ---
    if (ok and not drv.quitPlayer(1)) {
        ok = false
    }
    if (ok and drv.presence.hasReconnectToken(1)) {
        ok = false
    }
    if (ok and drv.handshakeReclaim(token1) >= 0) {
        ok = false
    }

    # Stub never auto-goes.
    if (ok and drv.tryAutoGoAllHumansReady()) {
        ok = false
    }

    drv.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
