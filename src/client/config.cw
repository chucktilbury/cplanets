/*
 * src/client/config.cw — human client connection settings (G).
 *
 * Own settings file, not the AI config (RULES §2 / PLAN §4.G).
 * Host/port/playerId only for v1 list debugger; UI prefs later.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial HumanConfig.
 *   2026-11-07  CLI mirror mode flags: once, pull, gui, test.
 */

/*
 * HumanConfig holds dial and seat knobs for the GTK client.
 *
 * No tick period, no DB path — clients never tick and never open
 * the universe DB (RULES §2). Mode flags mirror CLI switches so
 * a settings file can select once / pull / gui / test; argv
 * still overrides silently when the flag is present.
 */
class HumanConfig {
    int64 playerId
    String host
    int64 port
    bool once
    bool pull
    bool gui
    bool test

    /*
     * Construct localhost defaults for seat 0.
     *
     * Purpose: give loaders and --once tests a known baseline.
     *
     * Parameters: none.
     *
     * Returns: HumanConfig host 127.0.0.1, port 0, seat 0.
     */
    HumanConfig() {
        playerId = 0
        host = "127.0.0.1"
        port = 0
        once = false
        pull = false
        gui = false
        test = false
    }

    /*
     * Clamp seat and port into non-negative bands.
     *
     * Purpose: harden after text load.
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void clampAll() {
        if (playerId < 0) {
            playerId = 0
        }
        if (port < 0) {
            port = 0
        }
    }
}
