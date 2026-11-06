/*
 * src/unit_serverPresence.cw — handshake drop + pause gate unit.
 *
 * AFK≠drop: connected idle stays; miss window drops. Pause only
 * with exactly one live human (PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial presence unit.
 */

include "lib/player.cw"
include "server/presence.cw"

start {
    bool ok = true
    PresenceBook book = PresenceBook(1000u)
    book.ensureSeats(2)
    if (not book.handshake(0, 100u)) {
        ok = false
    }
    if (ok and not book.isConnected(0)) {
        ok = false
    }
    list dropped = []
    int64 n = book.scanDrops(500u, dropped)
    if (ok and n != 0) {
        ok = false
    }
    dropped = []
    n = book.scanDrops(1200u, dropped)
    if (ok and n != 1) {
        ok = false
    }
    if (ok and book.isConnected(0)) {
        ok = false
    }

    list players = []
    players.append(Player(0))
    players.append(Player(1))
    Player ai = players[1]
    ai.markAi()
    players[1] = ai
    if (ok and not book.pauseAllowed(players)) {
        ok = false
    }
    players.append(Player(2))
    if (ok and book.pauseAllowed(players)) {
        ok = false
    }
    print(ok)
    print("\n")
}
