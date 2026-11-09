/*
 * tests/unit/unit_homeOnConnect.cw — homes deferred until seat connect.
 *
 * Scenario start leaves seats without owned yards. Handshake (or
 * ensureHomeForSeat) grants the home once; drop leaves it in place.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial home-on-connect unit program.
 *   2026-11-08  Server allocate: first free seat; drop frees seat.
 *   2026-11-08  Drop keeps token; reclaim by token (no steal).
 *   2026-11-08  Soft max 2 for full-reject; grow covered elsewhere.
 *   2026-11-09  Sandbox seats also receive a starter scout fleet.
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # --- start: no owned homes / no fleets ---
    State bare = State()
    bare.startClosed(7u, 2)
    Planet slot = bare.galaxy.planets[0]
    if (slot.ownerId >= 0) {
        ok = false
    }
    Player p0 = bare.players[0]
    Player p1 = bare.players[1]
    if (p0.homeGranted or p1.homeGranted) {
        ok = false
    }
    if (bare.fleets.length != 0) {
        ok = false
    }
    # Tick must not eliminate unseated seats / end the game.
    bare.tick()
    if (bare.ended) {
        ok = false
    }
    p0 = bare.players[0]
    p1 = bare.players[1]
    if (p0.eliminated or p1.eliminated) {
        ok = false
    }

    # --- seat 0 connect grants primary home + starter fleet ---
    if (not bare.ensureHomeForSeat(0)) {
        ok = false
    }
    slot = bare.galaxy.planets[0]
    p0 = bare.players[0]
    if (not p0.homeGranted or slot.ownerId != 0) {
        ok = false
    }
    if (not slot.productive or not slot.shipyard) {
        ok = false
    }
    if (bare.fleets.length < 1) {
        ok = false
    }
    # Idempotent: second grant does not duplicate fleet/home.
    int64 fleetsAfter = bare.fleets.length
    if (not bare.ensureHomeForSeat(0)) {
        ok = false
    }
    if (bare.fleets.length != fleetsAfter) {
        ok = false
    }

    # --- seat 1 connect claims a sandbox home + starter fleet ---
    int64 fleetsBeforeSandbox = bare.fleets.length
    if (not bare.ensureHomeForSeat(1)) {
        ok = false
    }
    p1 = bare.players[1]
    if (not p1.homeGranted) {
        ok = false
    }
    int64 owned1 = 0
    int64 ownedFleets1 = 0
    int64 index = 0
    while (index < bare.galaxy.planets.length) {
        Planet rock = bare.galaxy.planets[index]
        if (rock.ownerId == 1) {
            owned1 = owned1 + 1
        }
        index = index + 1
    }
    if (owned1 != 1) {
        ok = false
    }
    index = 0
    while (index < bare.fleets.length) {
        Fleet ship = bare.fleets[index]
        if (ship.ownerId == 1 and ship.hullCount > 0) {
            ownedFleets1 = ownedFleets1 + 1
        }
        index = index + 1
    }
    if (ownedFleets1 < 1) {
        ok = false
    }
    if (bare.fleets.length <= fleetsBeforeSandbox) {
        ok = false
    }

    # --- GameDriver handshake seats a home ---
    State live = State()
    live.startClosed(11u, 2)
    Planet before = live.galaxy.planets[0]
    if (before.ownerId >= 0) {
        ok = false
    }
    GameDriver drv = GameDriver(live, true, "", false, 5000u)
    # Soft max 2: third allocate must reject (no grow past soft max).
    drv.softMaxPlayers = 2
    int64 seat0 = drv.handshakeAllocate()
    if (seat0 != 0) {
        ok = false
    }
    Planet after = drv.game.galaxy.planets[0]
    Player seated = drv.game.players[0]
    if (not seated.homeGranted or after.ownerId != 0) {
        ok = false
    }
    if (drv.game.fleets.length < 1) {
        ok = false
    }
    # Second allocate takes the next free seat.
    int64 seat1 = drv.handshakeAllocate()
    if (seat1 != 1) {
        ok = false
    }
    if (drv.handshakeAllocate() >= 0) {
        ok = false
    }
    # Keep-alive works only while connected.
    if (drv.handshakeKeepAlive(0) != 0) {
        ok = false
    }
    # Drop leaves the home in place; token still held (no steal).
    buffer token0 = drv.presence.reconnectToken(0)
    if (token0.length != PresenceBook.TOKEN_BYTES) {
        ok = false
    }
    if (not drv.dropPlayer(0)) {
        ok = false
    }
    Planet kept = drv.game.galaxy.planets[0]
    Player dropped = drv.game.players[0]
    if (kept.ownerId != 0 or not dropped.homeGranted) {
        ok = false
    }
    if (not dropped.dropped) {
        ok = false
    }
    if (drv.handshakeKeepAlive(0) >= 0) {
        ok = false
    }
    # Empty allocate cannot steal the token-held dropped seat.
    if (drv.handshakeAllocate() >= 0) {
        ok = false
    }
    # Reclaim with the opaque token restores the same seat.
    int64 reseat = drv.handshakeReclaim(token0)
    if (reseat != 0) {
        ok = false
    }
    Player reseated = drv.game.players[0]
    if (reseated.dropped or not reseated.present) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
