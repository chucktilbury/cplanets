/*
 * src/lib/fleet.cw — fleet orders and transit state (Phase C / D1).
 *
 * Holds hull mix, sender/destination, order, ETA, stranded
 * countdown, and mid-dispatch lock flags (RULES §5 / §6). D1
 * records pendingArrivalOrder so take can run after sit landing.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Fleet for tick core.
 *   2026-11-05  Phase D1: pendingArrivalOrder for take/occupy.
 */

/*
 * Fleet is one ordered group of hulls.
 *
 * pendingDeparture means the order was issued this tick and has
 * not yet paid dispatch. departed means the fleet is in flight.
 * recallRequested is cleared when cancel or recall is applied.
 * Sitting fleets keep locationPlanetId and order "sit".
 */
class Fleet {
    int64 id
    int64 ownerId
    int64 senderPlanetId
    int64 destPlanetId
    int64 locationPlanetId
    int64 designId
    int64 hullCount
    String order
    int64 eta
    int64 ticksTraveled
    int64 outboundEta
    int64 strandedLeft
    bool pendingDeparture
    bool departed
    bool recallRequested
    bool sitting
    bool stranded
    fp64 cargoWealth
    fp64 cargoResources
    String pendingArrivalOrder

    /*
     * Construct a sitting fleet at a planet.
     *
     * Purpose: park hulls on a possession before an order is
     * issued (home yard stock, post-arrival sit).
     *
     * Parameters:
     *   fleetId — stable id in the state fleet list.
     *   owner — empire id.
     *   planet — current location / sender.
     *   design — hull design id.
     *   hulls — number of hulls in this fleet.
     *
     * Returns: Fleet with order "sit" and no transit flags.
     */
    Fleet(
        int64 fleetId,
        int64 owner,
        int64 planet,
        int64 design,
        int64 hulls) {
        id = fleetId
        ownerId = owner
        senderPlanetId = planet
        destPlanetId = planet
        locationPlanetId = planet
        designId = design
        hullCount = hulls
        order = "sit"
        eta = 0
        ticksTraveled = 0
        outboundEta = 0
        strandedLeft = 0
        pendingDeparture = false
        departed = false
        recallRequested = false
        sitting = true
        stranded = false
        cargoWealth = 0.0
        cargoResources = 0.0
        pendingArrivalOrder = ""
    }

    /*
     * True when this fleet's in-flight order is locked.
     *
     * Purpose: mid-dispatch rule — other policy OK, this fleet's
     * order rewrites only via recall (RULES §5).
     *
     * Parameters: none.
     *
     * Returns: true when departed or still pending departure.
     */
    bool orderLocked() {
        if (departed) {
            return(true)
        }
        return(pendingDeparture)
    }

    /*
     * Issue a travel order from the current location.
     *
     * Purpose: queue a hop for the next tick's cancel/dispatch
     * phases. Refuses when the fleet is already locked unless the
     * new order is recall (handled separately).
     *
     * Parameters:
     *   newOrder — "move", "explore", "take", "trade", "ambush".
     *   dest — destination planet id.
     *   travelEta — computed outbound ETA (0 = teleport).
     *
     * Returns: true when the order was accepted.
     */
    bool issueTravel(String newOrder, int64 dest, int64 travelEta) {
        if (orderLocked()) {
            return(false)
        }
        if (stranded) {
            return(false)
        }
        order = newOrder
        senderPlanetId = locationPlanetId
        destPlanetId = dest
        eta = travelEta
        outboundEta = travelEta
        ticksTraveled = 0
        pendingDeparture = true
        departed = false
        recallRequested = false
        sitting = false
        return(true)
    }

    /*
     * Request recall (cancel if not departed, else turn home).
     *
     * Purpose: single entry for same-tick cancel and in-flight
     * recall (RULES §5.2).
     *
     * Parameters: none.
     *
     * Returns: true when a recall request was recorded.
     */
    bool requestRecall() {
        if (sitting and not pendingDeparture and not departed) {
            return(false)
        }
        recallRequested = true
        return(true)
    }

    /*
     * Mark the fleet as sitting at its current location.
     *
     * Purpose: clear transit flags after arrival or cancel so
     * sit/move on a possession works (RULES §5 / §11.3).
     *
     * Parameters: none.
     *
     * Returns: nothing; mutates this Fleet.
     */
    void becomeSitting() {
        order = "sit"
        destPlanetId = locationPlanetId
        eta = 0
        ticksTraveled = 0
        outboundEta = 0
        pendingDeparture = false
        departed = false
        recallRequested = false
        sitting = true
    }

    /*
     * Land at dest and remember the order that arrived.
     *
     * Purpose: Motion sits the fleet while Take still sees "take"
     * (or trade later) via pendingArrivalOrder (RULES §7.6).
     *
     * Parameters: none (uses destPlanetId / order).
     *
     * Returns: nothing; mutates this Fleet.
     */
    void landAndSit() {
        pendingArrivalOrder = order
        locationPlanetId = destPlanetId
        departed = false
        pendingDeparture = false
        becomeSitting()
    }

    /*
     * Enter the stranded countdown at the current location.
     *
     * Purpose: fuel replacement — cannot hop now; after N ticks
     * the fleet may move again (RULES §6).
     *
     * Parameters:
     *   ticks — setup strandedTicksN countdown.
     *
     * Returns: nothing; mutates this Fleet.
     */
    void becomeStranded(int64 ticks) {
        stranded = true
        strandedLeft = ticks
        pendingDeparture = false
        departed = false
        recallRequested = false
        sitting = true
        order = "sit"
        destPlanetId = locationPlanetId
        eta = 0
        ticksTraveled = 0
        outboundEta = 0
    }
}
