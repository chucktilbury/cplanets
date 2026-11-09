/*
 * src/ai/orderPlan.cw — concrete explore / take / build intents.
 *
 * Phase H only emitted opaque policy blobs. Section C needs the AI
 * to issue the same PUT /order and PUT /build verbs a human uses
 * so fleets leave home and quality gets revealed after go.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial planner from ClientStateView + policy %.
 */

include "../client/designRow.cw"
include "../client/fleetRow.cw"
include "../client/planetRow.cw"
include "../client/progressJob.cw"
include "../client/stateView.cw"
include "policyShape.cw"

/*
 * AiOrderIntent is one concrete client action (or a no-op).
 *
 * Built from the same visibility-limited snapshot a human sees.
 * Never invents hidden rock ids. kind is "none", "order", or
 * "build".
 */
class AiOrderIntent {
    String kind
    int64 fleetId
    int64 destPlanetId
    String order
    int64 hulls
    int64 buildPlanetId
    int64 buildDesignId

    /*
     * Construct an empty no-op intent.
     *
     * Purpose: default return when the snapshot has nothing useful
     * to dispatch or queue.
     *
     * Parameters: none.
     *
     * Returns: AiOrderIntent with kind "none".
     */
    AiOrderIntent() {
        kind = "none"
        fleetId = -1
        destPlanetId = -1
        order = ""
        hulls = 0
        buildPlanetId = -1
        buildDesignId = -1
    }
}

/*
 * AiOrderPlan picks one explore / take / build step from a view.
 *
 * Preference: explore unknown rocks with a sitting scout stack;
 * else take an unowned known rock when expansion is hungry; else
 * queue a yard hull when no sitting owned fleet remains (or when
 * expansion is high and a ready design exists).
 */
class AiOrderPlan {
    /*
     * Construct a stateless planner.
     *
     * Purpose: AiClient owns one instance for maybeIssueOrders.
     *
     * Parameters: none.
     *
     * Returns: AiOrderPlan ready for plan().
     */
    AiOrderPlan() {
    }

    /*
     * Choose one concrete order or build from the seat snapshot.
     *
     * Purpose: turn expansion / role percents into a legal human-
     * equivalent verb so AI clients move fleets after lobby go.
     * Uses only visible rows (same fog as PUT /order chrome).
     *
     * Parameters:
     *   snap — decoded GET /state for this seat.
     *   shape — latest policy shape (expansion / role bias).
     *
     * Returns: AiOrderIntent (kind none / order / build).
     */
    AiOrderIntent plan(ClientStateView snap, AiPolicyShape shape) {
        AiOrderIntent intent = AiOrderIntent()
        if (snap.ended) {
            return(intent)
        }
        FleetRow fleet = pickSittingFleet(snap)
        if (fleet.id >= 0) {
            int64 exploreDest = pickExploreDest(snap, fleet)
            if (exploreDest >= 0) {
                intent.kind = "order"
                intent.fleetId = fleet.id
                intent.destPlanetId = exploreDest
                intent.order = "explore"
                intent.hulls = peelHulls(fleet)
                return(intent)
            }
            if (shape.expansionPct >= 40
                or shape.roleName.equals("conqueror")) {
                int64 takeDest = pickTakeDest(snap, fleet)
                if (takeDest >= 0) {
                    intent.kind = "order"
                    intent.fleetId = fleet.id
                    intent.destPlanetId = takeDest
                    intent.order = "take"
                    intent.hulls = peelHulls(fleet)
                    return(intent)
                }
            }
        }
        if ((fleet.id < 0 or shape.expansionPct >= 55)
            and not hasOwnedBuildJob(snap)) {
            DesignRow design = pickReadyScout(snap)
            int64 yard = snap.firstOwnedYardId()
            if (design.id >= 0 and yard >= 0) {
                intent.kind = "build"
                intent.buildPlanetId = yard
                intent.buildDesignId = design.id
                return(intent)
            }
        }
        return(intent)
    }

    /*
     * True when this seat already has a yard BuildJob queued.
     *
     * Purpose: avoid spam PUT /build every serve-loop cycle while
     * a hull is already cooking (snapshot buildJobs list).
     *
     * Parameters:
     *   snap — seat snapshot.
     *
     * Returns: true when any build job ownerId matches viewerId.
     */
    bool hasOwnedBuildJob(ClientStateView snap) {
        int64 index = 0
        while (index < snap.buildJobs.length) {
            ProgressJob job = snap.buildJobs[index]
            if (job.ownerId == snap.viewerId) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Lowest-id sitting owned unlocked fleet with hulls.
     *
     * Purpose: same preference as Fleets-tab Entry sync so the AI
     * dispatches the home scout stack first.
     *
     * Parameters:
     *   snap — seat snapshot.
     *
     * Returns: FleetRow, or empty row (id -1) when none.
     */
    FleetRow pickSittingFleet(ClientStateView snap) {
        int64 bestId = snap.firstSittingOwnedFleetId()
        if (bestId < 0) {
            return(FleetRow())
        }
        return(snap.findFleet(bestId))
    }

    /*
     * Pick a visible quality-unknown rock to explore.
     *
     * Purpose: reveal livability/resources (RULES §5 explore).
     * Skips the fleet's current location and owned homes that are
     * already known.
     *
     * Parameters:
     *   snap — seat snapshot.
     *   fleet — sitting fleet providing the hop origin.
     *
     * Returns: planet id, or −1 when none.
     */
    int64 pickExploreDest(ClientStateView snap, FleetRow fleet) {
        int64 best = -1
        int64 index = 0
        while (index < snap.planets.length) {
            PlanetRow row = snap.planets[index]
            if (row.visible
                and not row.qualityKnown
                and row.id != fleet.locationPlanetId
                and row.id >= 0) {
                if (best < 0 or row.id < best) {
                    best = row.id
                }
            }
            index = index + 1
        }
        return(best)
    }

    /*
     * Pick a visible unowned quality-known rock to take.
     *
     * Purpose: expansion / conqueror path after scouting. Never
     * targets the seat's own rocks or the fleet's current sit.
     *
     * Parameters:
     *   snap — seat snapshot.
     *   fleet — sitting fleet providing the hop origin.
     *
     * Returns: planet id, or −1 when none.
     */
    int64 pickTakeDest(ClientStateView snap, FleetRow fleet) {
        int64 best = -1
        int64 index = 0
        while (index < snap.planets.length) {
            PlanetRow row = snap.planets[index]
            if (row.visible
                and row.qualityKnown
                and row.ownerId < 0
                and row.id != fleet.locationPlanetId
                and row.id >= 0) {
                if (best < 0 or row.id < best) {
                    best = row.id
                }
            }
            index = index + 1
        }
        return(best)
    }

    /*
     * Pick a ready scout (or any ready) design for yard build.
     *
     * Purpose: recreate fleets when the starter stack is locked
     * in flight or when expansion wants more hulls.
     *
     * Parameters:
     *   snap — seat snapshot with design catalog.
     *
     * Returns: DesignRow, or empty row (id -1) when none ready.
     */
    DesignRow pickReadyScout(ClientStateView snap) {
        DesignRow fallback = DesignRow()
        int64 index = 0
        while (index < snap.designs.length) {
            DesignRow row = snap.designs[index]
            if (row.ready and not row.closed and row.id >= 0) {
                if (row.scout) {
                    return(row)
                }
                if (fallback.id < 0) {
                    fallback = row
                }
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * Peel one hull from a multi-hull sit stack for a hop.
     *
     * Purpose: leave remaining scouts home so later cycles can
     * explore other rocks (0 = whole stack when only one hull).
     *
     * Parameters:
     *   fleet — sitting stack.
     *
     * Returns: hulls field for PUT /order (0 or 1).
     */
    int64 peelHulls(FleetRow fleet) {
        if (fleet.hullCount > 1) {
            return(1)
        }
        return(0)
    }
}
