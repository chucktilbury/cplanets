/*
 * tests/unit/unit_clientPublishDecode.cw — state list decode (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-07  Assert design catalog on chrome trailer.
 *   2026-11-07  Phase I: assert published home x/y milli round-trip.
 */

include "client/publishDecode.cw"
include "lib/state.cw"
include "server/policyTable.cw"
include "server/publish.cw"

start {
    bool ok = true
    State game = State()
    game.startClosed(11u, 2)
    PolicyTable policies = PolicyTable()
    policies.ensureSeats(game.players.length)
    PublishCodec codec = PublishCodec()
    buffer blob = codec.encodeStateView(game, policies, 0, false)
    if (blob.length < 1) {
        ok = false
    }
    PublishDecode decoder = PublishDecode()
    ClientStateView view = decoder.decodeState(blob, 0)
    if (ok and view.visiblePlanetCount() < 1) {
        ok = false
    }
    PlanetRow home = view.findPlanet(0)
    if (ok and home.id != 0) {
        ok = false
    }
    if (ok and not home.qualityKnown) {
        ok = false
    }
    if (ok and home.livabilityDisplay < 1) {
        ok = false
    }
    if (ok and home.livabilityDisplay > 10) {
        ok = false
    }
    if (ok and home.x != 0.0) {
        ok = false
    }
    if (ok and home.y != 0.0) {
        ok = false
    }
    PlanetRow remote = view.findPlanet(1)
    if (ok and remote.id == 1) {
        fp64 ax = remote.x
        if (ax < 0.0) {
            ax = -ax
        }
        fp64 ay = remote.y
        if (ay < 0.0) {
            ay = -ay
        }
        if (ax + ay < 0.001) {
            ok = false
        }
    }
    if (ok and view.designs.length < 1) {
        ok = false
    }
    DesignRow design = view.findDesign(0)
    if (ok and design.id != 0) {
        ok = false
    }
    if (ok and not design.ready) {
        ok = false
    }
    if (ok and view.designDevelopTicks < 1) {
        ok = false
    }
    buffer digest = codec.encodeDigest(0, [])
    if (ok and not decoder.decodeDigest(digest, view)) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
