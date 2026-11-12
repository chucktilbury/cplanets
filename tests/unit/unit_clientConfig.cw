/*
 * tests/unit/unit_clientConfig.cw — human settings parse (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-07  Assert once / pull / gui / test mode keys.
 *   2026-11-08  Default playerId -1 (server assigns on handshake).
 *   2026-11-09  Assert refresh_ms default / parse / clamp.
 *   2026-11-10  Assert display_name (CPL-106).
 *   2026-11-12  Assert ctor / sparse-parse gui=true (operator default).
 */

include "client/configParse.cw"

start {
    bool ok = true
    HumanConfig baseline = HumanConfig()
    if (baseline.playerId != -1) {
        ok = false
    }
    if (ok and not baseline.gui) {
        ok = false
    }
    if (ok and baseline.test) {
        ok = false
    }
    if (ok and baseline.refreshMs != 1000) {
        ok = false
    }
    if (ok and not baseline.resolvedDisplayName().equals("Human")) {
        ok = false
    }
    baseline.refreshMs = -5
    baseline.clampAll()
    if (ok and baseline.refreshMs != 0) {
        ok = false
    }
    baseline.ensureOfflineSeat()
    if (ok and baseline.playerId != 0) {
        ok = false
    }
    # Sparse file (no gui key) must keep ctor gui=true — not smoke.
    HumanConfigParse sparseParser = HumanConfigParse()
    HumanConfig sparse = sparseParser.parseText(
        "host = 127.0.0.1\nport = 0\n")
    if (ok and not sparse.gui) {
        ok = false
    }
    if (ok and sparse.test) {
        ok = false
    }
    String text = ""
    text.append("player_id = 2\n")
    text.append("host = 10.0.0.1\n")
    text.append("port = 9999\n")
    text.append("once = true\n")
    text.append("pull = true\n")
    text.append("gui = false\n")
    text.append("test = 1\n")
    text.append("refresh_ms = 250\n")
    text.append("display_name = Jordan\n")
    HumanConfigParse parser = HumanConfigParse()
    HumanConfig cfg = parser.parseText(text)
    if (cfg.playerId != 2) {
        ok = false
    }
    if (ok and not cfg.displayName.equals("Jordan")) {
        ok = false
    }
    if (ok and not cfg.host.equals("10.0.0.1")) {
        ok = false
    }
    if (ok and cfg.port != 9999) {
        ok = false
    }
    if (ok and not cfg.once) {
        ok = false
    }
    if (ok and not cfg.pull) {
        ok = false
    }
    if (ok and cfg.gui) {
        ok = false
    }
    if (ok and not cfg.test) {
        ok = false
    }
    if (ok and cfg.refreshMs != 250) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
