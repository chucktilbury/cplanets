/*
 * src/unit_clientConfig.cw — human settings parse (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 */

include "client/configParse.cw"

start {
    bool ok = true
    String text = "player_id = 2\nhost = 10.0.0.1\nport = 9999\n"
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
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
