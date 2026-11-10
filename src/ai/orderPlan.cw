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
 *   2026-11-10  CPL-101: after build→stock, create "ai-N" fleet and
 *               assign before dispatch; keep starter fleet first.
 */

include "../client/designRow.cw"
include "../client/fleetRow.cw"
include "../client/planetRow.cw"
include "../client/progressJob.cw"
include "../client/stateView.cw"
include "../client/stockRow.cw"
include "policyShape.cw"

/*
 * AiOrderIntent is one concrete client action (or a no-op).
 *
 * Built from the same visibility-limited snapshot a human sees.
 * Never invents hidden rock ids. kind is "none", "order",
 * "build", "fleet", or "assign".
 */
class AiOrderIntent {
    String kind
    int64 fleetId
    int64 destPlanetId
    String order
    int64 hulls
    int64 buildPlanetId
    int64 buildDesignId
    String fleetName
    String typeName
    int64 qty

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
        fleetName = ""
        typeName = ""
        qty = 0
    }
}

/*
 * AiOrderPlan picks one explore / take / build / assign step.
 *
 * Preference: explore/take with a sitting assigned stack (starter
 * fleet first); else create/assign from unassigned stock at home
 * yard; else queue a yard hull when expansion wants more ships.
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
     * Choose one concrete order, assign, create, or build.
     *
     * Purpose: turn expansion / role percents into a legal human-
     * equivalent verb so AI clients move fleets after lobby go.
     * Uses only visible rows (same fog as PUT /order chrome).
     * CPL-101: builds stage stock — create+assign before dispatch
     * when only unassigned hulls remain.
     *
     * Parameters:
     *   snap — decoded GET /state for this seat.
     *   shape — latest policy shape (expansion / role bias).
     *
     * Returns: AiOrderIntent (kind none / order / build / fleet /
     * assign).
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
        AiOrderIntent fromStock = planFromStock(snap)
        if (not fromStock.kind.equals("none")) {
            return(fromStock)
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
     * Create or assign from unassigned stock at the home yard.
     *
     * Purpose: CPL-101 playable path when the starter stack is
     * gone/locked and builds have staged hulls. Prefer assigning
     * into an empty owned fleet at that planet; else create
     * "ai-N" there.
     *
     * Parameters:
     *   snap — seat snapshot.
     *
     * Returns: AiOrderIntent kind fleet / assign / none.
     */
    AiOrderIntent planFromStock(ClientStateView snap) {
        AiOrderIntent intent = AiOrderIntent()
        StockRow stock = pickStockAtYard(snap)
        if (stock.count < 1 or stock.designId < 0) {
            return(intent)
        }
        DesignRow design = snap.findDesign(stock.designId)
        if (design.id < 0 or design.name.length < 1) {
            return(intent)
        }
        FleetRow empty = pickEmptyFleetAt(snap, stock.planetId)
        if (empty.id >= 0) {
            intent.kind = "assign"
            intent.fleetId = empty.id
            intent.typeName = design.name
            intent.qty = 1
            return(intent)
        }
        intent.kind = "fleet"
        intent.fleetName = nextAiFleetName(snap)
        intent.buildPlanetId = stock.planetId
        return(intent)
    }

    /*
     * Pick unassigned stock staged at an owned yard.
     *
     * Purpose: prefer home yard stock for create+assign.
     *
     * Parameters:
     *   snap — seat snapshot.
     *
     * Returns: StockRow with count > 0, or empty sentinel.
     */
    StockRow pickStockAtYard(ClientStateView snap) {
        int64 yard = snap.firstOwnedYardId()
        int64 index = 0
        StockRow best = StockRow()
        while (index < snap.stocks.length) {
            StockRow row = snap.stocks[index]
            if (row.count > 0 and row.designId >= 0) {
                if (yard >= 0 and row.planetId == yard) {
                    return(row)
                }
                if (best.count < 1) {
                    best = row
                }
            }
            index = index + 1
        }
        return(best)
    }

    /*
     * Find an empty owned sitting fleet at a planet.
     *
     * Purpose: reuse a just-created "ai-N" container for assign.
     *
     * Parameters:
     *   snap — seat snapshot.
     *   planetId — required location.
     *
     * Returns: FleetRow with hullCount 0, or empty sentinel.
     */
    FleetRow pickEmptyFleetAt(ClientStateView snap, int64 planetId) {
        int64 index = 0
        while (index < snap.fleets.length) {
            FleetRow row = snap.fleets[index]
            if (row.visible
                and row.ownerId == snap.viewerId
                and row.sitting
                and not row.orderLocked()
                and row.locationPlanetId == planetId
                and row.hullCount <= 0
                and row.id >= 1) {
                return(row)
            }
            index = index + 1
        }
        return(FleetRow())
    }

    /*
     * Allocate the next unused "ai-N" fleet name for this seat.
     *
     * Purpose: unique per-seat create names without colliding.
     *
     * Parameters:
     *   snap — seat snapshot with owned fleet names.
     *
     * Returns: "ai-1", "ai-2", … first free label.
     */
    String nextAiFleetName(ClientStateView snap) {
        int64 n = 1
        while (n < 10000) {
            String candidate = format("ai-{}", n)
            if (not fleetNameTaken(snap, candidate)) {
                return(candidate)
            }
            n = n + 1
        }
        return(format("ai-{}", snap.tick))
    }

    /*
     * True when an owned fleet already uses this name.
     *
     * Purpose: nextAiFleetName uniqueness check.
     *
     * Parameters:
     *   snap — seat snapshot.
     *   fleetName — candidate label.
     *
     * Returns: true when a visible owned fleet has that name.
     */
    bool fleetNameTaken(ClientStateView snap, String fleetName) {
        int64 index = 0
        while (index < snap.fleets.length) {
            FleetRow row = snap.fleets[index]
            if (row.ownerId == snap.viewerId
                and row.name.equals(fleetName)) {
                return(true)
            }
            index = index + 1
        }
        return(false)
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
