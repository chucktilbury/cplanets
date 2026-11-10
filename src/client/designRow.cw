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
 *   2026-11-09  examineDialogText for design TransientWindow.
 *   2026-11-10  choiceLabel for name-based DropDown chrome.
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
     * Stable DropDown label for this design / ship type.
     *
     * Purpose: select by type name across refresh_ms polls. Falls
     * back to the decimal id string when name is empty.
     *
     * Parameters: none.
     *
     * Returns: non-empty choice string when id is valid.
     */
    String choiceLabel() {
        if (name.length > 0) {
            return(name)
        }
        if (id < 0) {
            return("")
        }
        return(format("{}", id))
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

    /*
     * Build the design / ship examine dialog body text.
     *
     * Purpose: human TransientWindow inspect for a catalog row
     * (Section C Ships tab). Shows develop status and milli stats
     * from the published chrome trailer.
     *
     * Parameters: none.
     *
     * Returns: multi-line dialog body, or empty when id is invalid.
     */
    String examineDialogText() {
        if (id < 0) {
            return("")
        }
        String kind = "war"
        if (scout) {
            kind = "scout"
        } else (colony) {
            kind = "colony"
        } else (defense) {
            kind = "defense"
        }
        String text = format(
            "Design {}\nName: {}\nKind: {}\n", id, name, kind)
        if (closed) {
            text.append("Status: closed\n")
        } else (developTicksLeft > 0) {
            text.append(format(
                "Status: developing (ticks left {})\n",
                developTicksLeft))
        } else (ready) {
            text.append("Status: ready to build\n")
        } else {
            text.append("Status: not ready\n")
        }
        text.append(format(
            "Speed milli: {}\nHop milli: {}\n",
            speedMilli, hopMilli))
        text.append(format(
            "Size milli: {}\nCargo milli: {}\n",
            sizeMilli, cargoMilli))
        return(text)
    }
}
