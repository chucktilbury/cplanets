/*
 * tests/unit/unit_planetFog.cw — foreign homes stay fog-hidden.
 *
 * CPL-107: other seats' qualityKnown homes must not appear on a
 * seat view until in range or discovered. Seat-scoped qualityKnown
 * and discovery persistence are covered here (no TCP).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial fog visibility unit.
 */

include "client/planetRow.cw"
include "client/publishDecode.cw"
include "lib/event.cw"
include "lib/state.cw"
include "server/policyTable.cw"
include "server/publish.cw"

start {
    bool ok = true
    State game = State()
    game.startClosed(41u, 2)
    game.ensureAllSeatHomes()
    PolicyTable policies = PolicyTable()
    policies.ensureSeats(game.players.length)
    PublishCodec codec = PublishCodec()

    int64 foreignHome = -1
    int64 index = 0
    while (index < game.galaxy.planets.length) {
        Planet rock = game.galaxy.planets[index]
        if (rock.ownerId == 1) {
            foreignHome = rock.id
        }
        index = index + 1
    }
    if (foreignHome < 0) {
        ok = false
    }

    Planet foreignRock = game.galaxy.planets[0]
    Planet homeRock = game.galaxy.planets[0]
    if (ok) {
        foreignRock = game.galaxy.planets[foreignHome]
    }
    Player seat0 = game.players[0]
    bool foreignInReach = false
    if (ok) {
        foreignInReach = foreignRock.inRangeOf(
            homeRock.x,
            homeRock.y,
            seat0.detectionRange)
    }

    # Digest: foreign take is hidden from seat 0 when rock is fogged.
    TickEvent hidden = TickEvent("take", 9, foreignHome, 1, 0)
    if (ok and not foreignInReach) {
        if (codec.eventVisibleToSeat(game, hidden, 0)) {
            ok = false
        }
    }
    if (ok and not codec.eventVisibleToSeat(game, hidden, 1)) {
        ok = false
    }

    buffer blob = codec.encodeStateView(game, policies, 0, false)
    if (blob.length < 1) {
        ok = false
    }
    PublishDecode decoder = PublishDecode()
    ClientStateView view0 = decoder.decodeState(blob, 0)
    PlanetRow own = view0.findPlanet(0)
    if (ok and (own.id != 0 or not own.visible or not own.qualityKnown)) {
        ok = false
    }
    PlanetRow foreign = view0.findPlanet(foreignHome)
    if (ok and foreign.id != foreignHome) {
        ok = false
    }
    if (ok and not foreignInReach) {
        if (foreign.visible) {
            ok = false
        }
        if (foreign.ownerId >= 0 or foreign.qualityKnown) {
            ok = false
        }
        fp64 ax = foreign.x
        if (ax < 0.0) {
            ax = -ax
        }
        fp64 ay = foreign.y
        if (ay < 0.0) {
            ay = -ay
        }
        if (ax + ay > 0.001) {
            ok = false
        }
    }
    if (ok and foreignInReach and foreign.visible) {
        # In-range stranger home: visible, quality unknown to seat 0.
        if (foreign.qualityKnown) {
            ok = false
        }
    }

    # Discovery persists out of range.
    seat0 = game.players[0]
    seat0.markExploredPlanet(foreignHome)
    game.players[0] = seat0
    blob = codec.encodeStateView(game, policies, 0, false)
    view0 = decoder.decodeState(blob, 0)
    foreign = view0.findPlanet(foreignHome)
    if (ok and (not foreign.visible or not foreign.qualityKnown)) {
        ok = false
    }
    if (ok and foreign.ownerId != 1) {
        ok = false
    }
    if (ok and not codec.eventVisibleToSeat(game, hidden, 0)) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
