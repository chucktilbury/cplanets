/*
 * src/client/digestLine.cw — one newspaper / digest line (G).
 *
 * Decoded from the published GET /digest blob. Clients never tick
 * to invent events (RULES §2).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial DigestLine view model.
 */

/*
 * DigestLine is one published tick event for the newspaper pane.
 */
class DigestLine {
    String kind
    int64 fleetId
    int64 planetId
    int64 playerId
    int64 value

    /*
     * Construct an empty digest line.
     *
     * Purpose: decode target.
     *
     * Parameters: none.
     *
     * Returns: DigestLine with empty kind and -1 ids.
     */
    DigestLine() {
        kind = ""
        fleetId = -1
        planetId = -1
        playerId = -1
        value = 0
    }

    /*
     * One-line newspaper text.
     *
     * Purpose: digest pane / --pull printout.
     *
     * Parameters: none.
     *
     * Returns: short event summary.
     */
    String listLabel() {
        return(format(
            "{} fleet={} planet={} player={} value={}",
            kind, fleetId, planetId, playerId, value))
    }
}
