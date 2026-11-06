/*
 * src/client/fleetRow.cw — one fleet list row (G).
 *
 * Visibility is a server flag. No ETA map canvas — list text only
 * (PLAN §4.G / §4.I deferred).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial FleetRow view model.
 */

/*
 * FleetRow is one visibility-limited fleet summary.
 */
class FleetRow {
    int64 id
    bool visible
    bool sitting
    bool departed
    int64 ownerId
    int64 destPlanetId
    int64 locationPlanetId
    int64 eta
    int64 hullCount
    String order

    /*
     * Construct an empty invisible fleet row.
     *
     * Purpose: decode target and unit fixtures.
     *
     * Parameters: none.
     *
     * Returns: FleetRow with id -1 and order "sit".
     */
    FleetRow() {
        id = -1
        visible = false
        sitting = false
        departed = false
        ownerId = -1
        destPlanetId = -1
        locationPlanetId = -1
        eta = 0
        hullCount = 0
        order = "sit"
    }

    /*
     * One-line label for the fleet list pane.
     *
     * Purpose: Tree / Label row text for the debugger.
     *
     * Parameters: none.
     *
     * Returns: short summary string.
     */
    String listLabel() {
        if (not visible) {
            return(format("Fleet {} (hidden)", id))
        }
        return(format(
            "Fleet {} owner={} order={} hulls={} eta={} loc={} dest={}",
            id, ownerId, order, hullCount, eta,
            locationPlanetId, destPlanetId))
    }
}
