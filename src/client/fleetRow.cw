/*
 * src/client/fleetRow.cw — one fleet list row (G).
 *
 * Visibility is a server flag. Phase I publishes outboundEta so
 * the map can draw dotted hop progress (PLAN §4.I).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial FleetRow view model.
 *   2026-11-06  TUNING B: pendingDeparture / recallRequested /
 *               orderLocked for dispatch chrome.
 *   2026-11-07  Phase I: outboundEta for map hop progress.
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
    int64 outboundEta
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
        outboundEta = 0
        hullCount = 0
        order = "sit"
    }

    /*
     * True when the map should stroke an in-flight hop path.
     *
     * Purpose: gate dotted ETA lines (README / RULES §16).
     *
     * Parameters: none.
     *
     * Returns: true when departed or pending with a real dest.
     */
    bool mapPathActive() {
        if (destPlanetId < 0) {
            return(false)
        }
        if (destPlanetId == locationPlanetId) {
            return(false)
        }
        if (departed) {
            return(true)
        }
        return(pendingDeparture)
    }

    /*
     * Hop progress fraction along location→dest for the map.
     *
     * Purpose: place the in-transit marker; 0 at origin, 1 at dest.
     * Uses remaining eta vs outboundEta when both are published.
     *
     * Parameters: none.
     *
     * Returns: 0..1 progress; 0 when outbound unknown.
     */
    fp64 mapHopProgress() {
        if (not mapPathActive()) {
            return(0.0)
        }
        if (outboundEta <= 0) {
            return(0.0)
        }
        int64 traveled = outboundEta - eta
        if (traveled < 0) {
            traveled = 0
        }
        if (traveled > outboundEta) {
            traveled = outboundEta
        }
        return(fp64(traveled) / fp64(outboundEta))
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
