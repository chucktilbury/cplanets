/*
 * tests/unit/unit_agreement.cw — player–player agreement accept / open.
 *
 * Fixed seed; both must accept before the pact is live; close
 * clears open (PLAN D2 / RULES §8.1 / §8.4).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial agreement unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(41u, 2)
    bool ok = true
    int64 id = game.proposeAgreement(0, 1, 100.0)
    if (id < 0) {
        ok = false
    }
    Agreement pact = game.findAgreement(id)
    if (pact.isLive()) {
        ok = false
    }
    if (not game.acceptAgreement(id, 0)) {
        ok = false
    }
    pact = game.findAgreement(id)
    if (pact.isLive()) {
        ok = false
    }
    if (not game.acceptAgreement(id, 1)) {
        ok = false
    }
    pact = game.findAgreement(id)
    if (not pact.isLive() or pact.sizeS != 100.0) {
        ok = false
    }
    if (not game.closeAgreement(id)) {
        ok = false
    }
    pact = game.findAgreement(id)
    if (pact.isLive()) {
        ok = false
    }
    # Same player cannot propose.
    if (game.proposeAgreement(0, 0, 10.0) >= 0) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
