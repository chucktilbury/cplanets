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
 *   2026-11-08  reconnectToken from handshake ack for reclaim.
 *   2026-11-09  refresh_ms: GUI GET /state+/digest poll period.
 *   2026-11-10  display_name seat label (CPL-106).
 */

/*
 * HumanConfig holds dial and seat knobs for the GTK client.
 *
 * No tick period, no DB path — clients never tick and never open
 * the universe DB (RULES §2). Mode flags mirror CLI switches so
 * a settings file can select once / pull / gui / test; argv
 * still overrides silently when the flag is present.
 * reconnectToken is opaque TOKEN_BYTES from the server handshake
 * ack; process-local only (not a config-file key).
 * refreshMs drives live GUI pull of GET /state + GET /digest
 * (distinct from presence keep-alive handshake).
 */
class HumanConfig {
    int64 playerId
    buffer reconnectToken
    # Seat display name sent via PUT /name after handshake.
    # Empty → client sends "Human" so chrome is never blank.
    String displayName
    String host
    int64 port
    bool once
    bool pull
    bool gui
    bool test
    # Live GUI pull period (ms) for GET /state + GET /digest.
    # 0 = off (File→Refresh only). Default 1000 ≈ near-tick feel.
    # CLI --refresh-ms overlays after load. Not presence keep-alive.
    int64 refreshMs

    /*
     * Construct localhost defaults with an unassigned seat.
     *
     * Purpose: give loaders and --once tests a known baseline.
     * TCP play lets the server assign playerId on handshake;
     * offline --once / port 0 may still pin a local seat.
     *
     * Parameters: none.
     *
     * Returns: HumanConfig host 127.0.0.1, port 0, seat -1,
     * empty reconnect token, refreshMs 1000.
     */
    HumanConfig() {
        playerId = -1
        reconnectToken = buffer[]
        displayName = ""
        host = "127.0.0.1"
        port = 0
        once = false
        pull = false
        gui = false
        test = false
        refreshMs = 1000
    }

    /*
     * Effective display name for PUT /name.
     *
     * Purpose: config may omit display_name; chrome still needs a
     * non-empty label. Empty → "Human".
     *
     * Parameters: none.
     *
     * Returns: non-empty name string.
     */
    String resolvedDisplayName() {
        String trimmed = displayName.trim()
        if (trimmed.length > 0) {
            return(trimmed)
        }
        return("Human")
    }

    /*
     * Clamp seat, port, and refresh period into legal bands.
     *
     * Purpose: harden after text load. Seat -1 means unassigned
     * (server allocates on TCP handshake). Offline paths that need
     * a concrete seat call ensureOfflineSeat(). refreshMs < 0
     * becomes 0 (off).
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
        if (refreshMs < 0) {
            refreshMs = 0
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
