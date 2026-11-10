/*
 * src/client/stockRow.cw — one unassigned hull stock summary.
 *
 * CPL-101 inventory chrome: type staged at a yard planet with an
 * available count (not a fleet).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial StockRow view model.
 */

/*
 * StockRow is one unassigned type-count at a planet for the seat.
 */
class StockRow {
    int64 designId
    int64 planetId
    int64 count

    /*
     * Construct an empty stock row.
     *
     * Purpose: decode target and list chrome.
     *
     * Parameters: none.
     *
     * Returns: StockRow with ids -1 and count 0.
     */
    StockRow() {
        designId = -1
        planetId = -1
        count = 0
    }

    /*
     * One-line inventory label for Ships/Fleets lists.
     *
     * Purpose: show type id, stage planet, and available count.
     *
     * Parameters: none.
     *
     * Returns: short label string.
     */
    String listLabel() {
        return(
            format(
                "type {} @ planet {} — {} available",
                designId, planetId, count))
    }
}
