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
 *   2026-11-08  playerId -1 = unassigned; TCP seat from handshake.
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
     * Construct localhost defaults with an unassigned seat.
     *
     * Purpose: give loaders and --once tests a known baseline.
     * TCP play lets the server assign playerId on handshake;
     * offline --once / port 0 may still pin a local seat.
     *
     * Parameters: none.
     *
     * Returns: HumanConfig host 127.0.0.1, port 0, seat -1.
     */
    HumanConfig() {
        playerId = -1
        host = "127.0.0.1"
        port = 0
        once = false
        pull = false
        gui = false
        test = false
    }

    /*
     * Clamp seat and port into legal bands.
     *
     * Purpose: harden after text load. Seat -1 means unassigned
     * (server allocates on TCP handshake). Offline paths that need
     * a concrete seat call ensureOfflineSeat().
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void clampAll() {
        if (playerId < -1) {
            playerId = -1
        }
        if (port < 0) {
            port = 0
        }
    }

    /*
     * Pin seat 0 when still unassigned for offline play.
     *
     * Purpose: --once / port-0 GUI need a local empire index; TCP
     * clients leave -1 until handshake returns the assigned id.
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void ensureOfflineSeat() {
        if (playerId < 0) {
            playerId = 0
        }
    }
}
