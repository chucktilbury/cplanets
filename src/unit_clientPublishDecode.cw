/*
 * src/unit_clientPublishDecode.cw — state list decode (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
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
    buffer blob = codec.encodeStateView(game, policies, 0)
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
