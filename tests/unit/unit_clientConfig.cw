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
 */

include "client/configParse.cw"

start {
    bool ok = true
    String text = ""
    text.append("player_id = 2\n")
    text.append("host = 10.0.0.1\n")
    text.append("port = 9999\n")
    text.append("once = true\n")
    text.append("pull = true\n")
    text.append("gui = false\n")
    text.append("test = 1\n")
    HumanConfigParse parser = HumanConfigParse()
    HumanConfig cfg = parser.parseText(text)
    if (cfg.playerId != 2) {
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
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
