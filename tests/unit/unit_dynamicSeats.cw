/*
 * tests/unit/unit_dynamicSeats.cw — grow-on-connect + soft max.
 *
 * Live serve starts with zero seats. Empty handshake grows seats
 * when soft max is 0 / unset (former hard players=2 no longer
 * aborts a third client). Soft max rejects only when set and full.
 * Operator go starts with whatever is seated.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial dynamic seat / soft max unit.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- three allocates with soft max 0 (former hard default 2) ---
    State open = State()
    open.startClosed(7u, 0)
    if (open.players.length != 0) {
        ok = false
    }
    GameDriver grow = GameDriver(open, true, "", false, 5000u)
    grow.softMaxPlayers = 0
    int64 a0 = grow.handshakeAllocate()
    int64 a1 = grow.handshakeAllocate()
    int64 a2 = grow.handshakeAllocate()
    if (a0 != 0 or a1 != 1 or a2 != 2) {
        ok = false
    }
    if (grow.seatedCount() != 3) {
        ok = false
    }
    if (grow.game.players.length != 3) {
        ok = false
    }
    Player p2 = grow.game.players[2]
    if (not p2.homeGranted) {
        ok = false
    }
    # Go with three seated (does not wait for any soft max).
    if (not grow.go()) {
        ok = false
    }
    if (grow.inLobby()) {
        ok = false
    }
    grow.close()

    # --- soft max 2: third allocate rejects ---
    State capped = State()
    capped.startClosed(11u, 0)
    GameDriver soft = GameDriver(capped, true, "", false, 5000u)
    soft.softMaxPlayers = 2
    if (soft.handshakeAllocate() != 0) {
        ok = false
    }
    if (soft.handshakeAllocate() != 1) {
        ok = false
    }
    if (soft.handshakeAllocate() >= 0) {
        ok = false
    }
    if (soft.seatedCount() != 2) {
        ok = false
    }
    if (soft.canGrowSeat()) {
        ok = false
    }
    soft.close()

    # --- pre-created fixture seats still work; grow past them ---
    State fixture = State()
    fixture.startClosed(13u, 2)
    GameDriver past = GameDriver(fixture, true, "", false, 5000u)
    past.softMaxPlayers = 0
    if (past.handshakeAllocate() != 0) {
        ok = false
    }
    if (past.handshakeAllocate() != 1) {
        ok = false
    }
    if (past.handshakeAllocate() != 2) {
        ok = false
    }
    past.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
