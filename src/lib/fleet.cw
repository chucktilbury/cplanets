/*
 * src/lib/fleet.cw — fleet orders and transit state (Phase C–D3).
 *
 * Holds hull mix, sender/destination, order, ETA, stranded
 * countdown, and mid-dispatch lock flags (RULES §5 / §6). D1
 * records pendingArrivalOrder so take can run after sit landing.
 * D2 adds trade leg, agreement, fills, and escort mix. D3 adds
 * ambush in-position / idle / loot riding until return.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Fleet for tick core.
 *   2026-11-05  Phase D1: pendingArrivalOrder for take/occupy.
 *   2026-11-05  Phase D2: trade cycle fields + escorts.
 *   2026-11-05  Phase D3: ambush position, idle, loot cargo.
 *   2026-11-05  Phase D4: engagementId for recall-into-fight.
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
    int64 agreementId
    fp64 tradeSize
    bool cargoFilled
    bool tradeOutbound
    int64 tradeFarPlanetId
    int64 escortDesignId
    int64 escortHullCount
    bool ambushInPosition
    int64 ambushIdleLeft
    int64 ambushEdgeA
    int64 ambushEdgeB
    fp64 lootWealth
    fp64 lootResources
    int64 engagementId

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
        agreementId = -1
        tradeSize = 0.0
        cargoFilled = false
        tradeOutbound = true
        tradeFarPlanetId = -1
        escortDesignId = -1
        escortHullCount = 0
        ambushInPosition = false
        ambushIdleLeft = 0
        ambushEdgeA = -1
        ambushEdgeB = -1
        lootWealth = 0.0
        lootResources = 0.0
        engagementId = -1
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
        if (sitting
            and not pendingDeparture
            and not departed
            and engagementId < 0) {
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
        ambushInPosition = false
        ambushIdleLeft = 0
        ambushEdgeA = -1
        ambushEdgeB = -1
    }

    /*
     * Enter ambush wait at the hop midpoint.
     *
     * Purpose: RULES §6 / §10 — after half hop ETA the pirate is
     * in position; combat may fire; idle countdown starts.
     *
     * Parameters:
     *   idleTicks — scenario pirateIdleTicks.
     *
     * Returns: nothing; mutates this Fleet.
     */
    void enterAmbushPosition(int64 idleTicks) {
        ambushInPosition = true
        ambushIdleLeft = idleTicks
        eta = 0
        departed = true
        pendingDeparture = false
        sitting = false
        recallRequested = false
        order = "ambush"
    }

    /*
     * Canonical undirected edge key low endpoint.
     *
     * Purpose: match pirates and passers on the same A–B hop.
     *
     * Parameters: none (uses ambushEdgeA/B or sender/dest).
     *
     * Returns: min endpoint planet id.
     */
    int64 edgeLo() {
        int64 a = ambushEdgeA
        int64 b = ambushEdgeB
        if (a < 0 or b < 0) {
            a = senderPlanetId
            b = destPlanetId
        }
        if (b < a) {
            return(b)
        }
        return(a)
    }

    /*
     * Canonical undirected edge key high endpoint.
     *
     * Purpose: pair with edgeLo for midpoint grouping.
     *
     * Parameters: none.
     *
     * Returns: max endpoint planet id.
     */
    int64 edgeHi() {
        int64 a = ambushEdgeA
        int64 b = ambushEdgeB
        if (a < 0 or b < 0) {
            a = senderPlanetId
            b = destPlanetId
        }
        if (b < a) {
            return(a)
        }
        return(b)
    }

    /*
     * True when this fleet carries uncredited pirate loot.
     *
     * Purpose: credit on return to sender (RULES §10).
     *
     * Parameters: none.
     *
     * Returns: true when either loot field is positive.
     */
    bool hasLoot() {
        if (lootWealth > 0.0) {
            return(true)
        }
        return(lootResources > 0.0)
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
