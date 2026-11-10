/*
 * src/client/playerSeatRow.cw — one published seat identity row.
 *
 * Decoded from the GET /state player loop so chrome can show
 * display names instead of bare ids (CPL-106).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial PlayerSeatRow (id / name / human).
 */

/*
 * PlayerSeatRow is one empire identity from the published state.
 *
 * Holds the seat id, display label, and human flag. Wealth and
 * quit/drop flags stay server-side for status menus; the human
 * chrome only needs identity for owner/competitor text.
 */
class PlayerSeatRow {
    int64 id
    String displayName
    bool human

    /*
     * Construct an empty seat identity row.
     *
     * Purpose: decode target before reading wire fields.
     *
     * Parameters: none.
     *
     * Returns: PlayerSeatRow with id -1 and empty name.
     */
    PlayerSeatRow() {
        id = -1
        displayName = ""
        human = false
    }

    /*
     * Effective label for chrome (non-empty).
     *
     * Purpose: mirror Player.label() on the client when the wire
     * name is still blank.
     *
     * Parameters: none.
     *
     * Returns: displayName, or "Player {id}".
     */
    String label() {
        if (displayName.length > 0) {
            return(displayName)
        }
        return(format("Player {}", id))
    }
}
