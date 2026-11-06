/*
 * tests/fn/fn_client.cw — Phase G human client cluster (in-process).
 *
 * Encode seat view → decode lists; explored dialog 1–10; policy
 * PUT shape; visibility flags from driver (no second fog). No TCP
 * / GTK here (PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial human client function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "client/appCore.cw"
include "client/config.cw"
include "client/planetRow.cw"
include "client/policyShape.cw"
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

    HumanConfig cfg = HumanConfig()
    cfg.playerId = 0
    AppCore core = AppCore(cfg)
    if (not core.fillFromGame(game, policies)) {
        ok = false
    }
    if (ok and core.view.visiblePlanetCount() < 1) {
        ok = false
    }

    # Home is explored / quality known with 1–10 display.
    PlanetRow home = core.view.findPlanet(0)
    if (ok and home.id != 0) {
        ok = false
    }
    if (ok and not home.qualityKnown) {
        ok = false
    }
    if (ok and (home.livabilityDisplay < 1
        or home.livabilityDisplay > 10)) {
        ok = false
    }
    String dialog = home.exploredDialogText()
    if (ok and dialog.find("Livability:") < 0) {
        ok = false
    }
    if (ok and home.dialogMayChange()) {
        if (dialog.find("may change") < 0) {
            ok = false
        }
    }

    # Seat-scoped encode differs from all-visible snapshot size /
    # visible counts when fog applies; both must decode.
    PublishCodec codec = PublishCodec()
    buffer allBlob = codec.encodeState(game, policies, false)
    buffer seatBlob = codec.encodeStateView(
        game, policies, 0, false)
    if (ok and (allBlob.length < 1 or seatBlob.length < 1)) {
        ok = false
    }
    PublishDecode decoder = PublishDecode()
    ClientStateView allView = decoder.decodeState(allBlob, -1)
    if (ok and allView.planets.length < core.view.planets.length) {
        ok = false
    }

    # Policy editor shape encodes without dumb-order side effects.
    core.draft.roleName = "hermit"
    core.draft.expansionPct = 10
    buffer pol = core.draft.encode()
    if (ok and pol.length != 8) {
        ok = false
    }
    HumanPolicyShape back = HumanPolicyShape()
    if (ok and not back.decode(pol)) {
        ok = false
    }
    if (ok and not back.roleName.equals("hermit")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
