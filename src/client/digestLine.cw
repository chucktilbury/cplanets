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
 *   2026-11-07  Optional compose text on private/broadcast lines.
 *   2026-11-10  playerName for seat display labels (CPL-106).
 */

/*
 * DigestLine is one published tick event for the newspaper pane.
 */
class DigestLine {
    String kind
    int64 fleetId
    int64 planetId
    int64 playerId
    # Resolved seat display name for player= chrome.
    String playerName
    int64 value
    String text

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
        playerName = ""
        value = 0
        text = ""
    }

    /*
     * Player label for digest chrome.
     *
     * Purpose: prefer display name; fall back to decimal id.
     *
     * Parameters: none.
     *
     * Returns: player text.
     */
    String playerLabel() {
        if (playerName.length > 0) {
            return(playerName)
        }
        return(format("{}", playerId))
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
        if (text.length > 0) {
            return(format(
                "{} fleet={} planet={} player={} value={} text={}",
                kind, fleetId, planetId, playerLabel(), value, text))
        }
        return(format(
            "{} fleet={} planet={} player={} value={}",
            kind, fleetId, planetId, playerLabel(), value))
    }
}
