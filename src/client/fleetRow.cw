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
 *   2026-11-06  TUNING B: pendingDeparture / recallRequested /
 *               orderLocked for dispatch chrome.
 */

/*
 * FleetRow is one visibility-limited fleet summary.
 */
class FleetRow {
    int64 id
    bool visible
    bool sitting
    bool departed
    bool pendingDeparture
    bool recallRequested
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
        pendingDeparture = false
        recallRequested = false
        ownerId = -1
        destPlanetId = -1
        locationPlanetId = -1
        eta = 0
        hullCount = 0
        order = "sit"
    }

    /*
     * True when this fleet's order is mid-dispatch locked.
     *
     * Purpose: dispatch chrome disables rewrite; recall remains
     * the unlock path (RULES §5).
     *
     * Parameters: none.
     *
     * Returns: true when pending departure or departed.
     */
    bool orderLocked() {
        if (departed) {
            return(true)
        }
        return(pendingDeparture)
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
        String lock = ""
        if (orderLocked()) {
            lock.append(" LOCKED")
        }
        if (recallRequested) {
            lock.append(" recall-req")
        }
        return(format(
            "Fleet {} owner={} order={} hulls={} eta={} loc={} dest={}{}",
            id, ownerId, order, hullCount, eta,
            locationPlanetId, destPlanetId, lock))
    }
}
