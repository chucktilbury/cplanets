/*
 * src/lib/dispatch.cw — departures, dispatch wealth, trade loading.
 *
 * After same-tick cancellations, pending fleets pay sender-only
 * costs and leave (RULES §5.1). Loading applies only to trade
 * orders; trade cycle resolution is Phase D.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial dispatch/loading phase for tick core.
 */

include "design.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"
include "travel.cw"

/*
 * Dispatch pays sunk departure costs and marks fleets in flight.
 *
 * Cannot-pay and out-of-reach hops do not leave. Out-of-reach
 * becomes stranded for strandedTicksN (RULES §6).
 */
class Dispatch {
    Travel travel

    /*
     * Construct a dispatch phase with a Travel helper.
     *
     * Purpose: share ETA/reach math with issue-order call sites.
     *
     * Parameters: none.
     *
     * Returns: Dispatch ready for run.
     */
    Dispatch() {
        travel = Travel()
    }

    /*
     * Attempt departure for every pending fleet.
     *
     * Purpose: RULES §7 after cancellations — fleets that still
     * intend to leave pay and depart, or strand / stay.
     *
     * Parameters:
     *   scenario — dispatch weights, stranded N, voyage cost.
     *   planets — galaxy list.
     *   players — empire pools (wealth/resources).
     *   designs — hull templates.
     *   fleets — mutable fleet list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void run(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingDeparture) {
                applyDeparture(
                    scenario,
                    planets,
                    players,
                    designs,
                    fleets,
                    events,
                    index)
            }
            index = index + 1
        }
    }

    /*
     * Dispatch weight for one hull of a design.
     *
     * Purpose: scouts almost nothing; colonies more; else size
     * (RULES §5.1). Coefficients from scenario.
     *
     * Parameters:
     *   scenario — dispatchWeightScout / Colony.
     *   design — hull flags and size.
     *
     * Returns: wealth cost per hull.
     */
    fp64 weightFor(Scenario scenario, Design design) {
        if (design.scout) {
            return(scenario.dispatchWeightScout)
        }
        if (design.colony) {
            return(scenario.dispatchWeightColony)
        }
        return(design.size)
    }

    /*
     * Total dispatch wealth for a fleet's hull mix.
     *
     * Purpose: sum weight * hullCount (+ voyageCost placeholder).
     *
     * Parameters:
     *   scenario — weight knobs and voyageCost.
     *   design — hull template.
     *   hulls — fleet.hullCount.
     *
     * Returns: sunk wealth required to leave.
     */
    fp64 dispatchCost(
        Scenario scenario,
        Design design,
        int64 hulls) {
        fp64 per = weightFor(scenario, design)
        return(per * fp64(hulls) + scenario.voyageCost)
    }

    /*
     * Trade-only loading cost (sender pays).
     *
     * Purpose: wealth cargo + resource cargo for S (RULES §5.1).
     * Phase C exposes the charge; trade arrivals are Phase D.
     *
     * Parameters:
     *   fleet — pending trade fleet with cargo fields filled.
     *
     * Returns: wealth loading cost (resources charged separately).
     */
    fp64 loadingWealth(Fleet fleet) {
        return(fleet.cargoWealth)
    }

    /*
     * Resource half of trade loading.
     *
     * Purpose: pair with loadingWealth for sender-only S fill.
     *
     * Parameters:
     *   fleet — pending trade fleet.
     *
     * Returns: resource loading cost.
     */
    fp64 loadingResources(Fleet fleet) {
        return(fleet.cargoResources)
    }

    /*
     * Pay and depart one pending fleet, or strand / abort.
     *
     * Purpose: centralize reach, wealth, and loading checks.
     *
     * Parameters:
     *   scenario — knobs.
     *   planets — galaxy.
     *   players — pools.
     *   designs — templates.
     *   fleets — mutable list.
     *   events — log.
     *   index — fleet index in fleets.
     *
     * Returns: nothing; mutates fleets/players.
     */
    void applyDeparture(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            fleet.pendingDeparture = false
            fleet.becomeSitting()
            fleets[index] = fleet
            return()
        }
        if (fleet.senderPlanetId < 0
            or fleet.senderPlanetId >= planets.length
            or fleet.destPlanetId < 0
            or fleet.destPlanetId >= planets.length) {
            fleet.pendingDeparture = false
            fleet.becomeSitting()
            fleets[index] = fleet
            return()
        }
        Design design = designs[fleet.designId]
        Planet origin = planets[fleet.senderPlanetId]
        Planet dest = planets[fleet.destPlanetId]
        if (not travel.canHop(design, origin, dest)) {
            fleet.becomeStranded(scenario.strandedTicksN)
            fleets[index] = fleet
            events.append(
                TickEvent(
                    "stranded",
                    fleet.id,
                    origin.id,
                    fleet.ownerId,
                    scenario.strandedTicksN))
            return()
        }
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            fleet.pendingDeparture = false
            fleet.becomeSitting()
            fleets[index] = fleet
            return()
        }
        Player seat = players[fleet.ownerId]
        fp64 cost = dispatchCost(scenario, design, fleet.hullCount)
        fp64 loadW = 0.0
        fp64 loadR = 0.0
        if (fleet.order.equals("trade")) {
            loadW = loadingWealth(fleet)
            loadR = loadingResources(fleet)
        }
        if (seat.wealth < cost + loadW or seat.resources < loadR) {
            fleet.pendingDeparture = false
            fleet.becomeSitting()
            fleets[index] = fleet
            events.append(
                TickEvent(
                    "depart_fail",
                    fleet.id,
                    origin.id,
                    fleet.ownerId,
                    0))
            return()
        }
        seat.wealth = seat.wealth - cost - loadW
        seat.resources = seat.resources - loadR
        players[fleet.ownerId] = seat
        fleet.pendingDeparture = false
        fleet.departed = true
        fleet.sitting = false
        fleet.ticksTraveled = 0
        fleets[index] = fleet
        events.append(
            TickEvent(
                "depart",
                fleet.id,
                origin.id,
                fleet.ownerId,
                fleet.eta))
    }
}
