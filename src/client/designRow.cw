/*
 * src/client/designRow.cw — one published hull design summary.
 *
 * List stand-in for design editor / yard inspect chrome. Filled
 * from the chrome trailer catalog (RULES §5.3 / DIALOGS §6).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial DesignRow for ship create / yard GUI.
 */

/*
 * DesignRow is one design the seat can inspect or queue to build.
 *
 * Stats are display milli-units (value * 1000) from the wire.
 * ready means developTicksLeft == 0 and not closed.
 */
class DesignRow {
    int64 id
    String name
    int64 developTicksLeft
    bool closed
    bool scout
    bool colony
    bool defense
    bool ready
    int64 speedMilli
    int64 hopMilli
    int64 sizeMilli
    int64 cargoMilli

    /*
     * Construct an empty design row.
     *
     * Purpose: decode target and missing-id sentinel.
     *
     * Parameters: none.
     *
     * Returns: DesignRow with id -1 and empty name.
     */
    DesignRow() {
        id = -1
        name = ""
        developTicksLeft = 0
        closed = false
        scout = false
        colony = false
        defense = false
        ready = false
        speedMilli = 0
        hopMilli = 0
        sizeMilli = 0
        cargoMilli = 0
    }

    /*
     * One-line label for the Ships / Yard design list.
     *
     * Purpose: inspect developing and ready templates without a
     * map or Scale widgets.
     *
     * Parameters: none.
     *
     * Returns: short summary string.
     */
    String listLabel() {
        String kind = "war"
        if (scout) {
            kind = "scout"
        } else (colony) {
            kind = "colony"
        } else (defense) {
            kind = "defense"
        }
        String status = "ready"
        if (closed) {
            status = "closed"
        } else (developTicksLeft > 0) {
            status = format(
                "developing ticksLeft={}", developTicksLeft)
        } else (not ready) {
            status = "not-ready"
        }
        return(format(
            "Design {} '{}' kind={} sizeMilli={} {}",
            id, name, kind, sizeMilli, status))
    }
}
