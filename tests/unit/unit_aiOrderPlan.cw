/*
 * tests/unit/unit_aiOrderPlan.cw — AI explore / take / build intents.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial order planner unit program.
 *   2026-11-10  CPL-101: stock → create "ai-N" / assign intents.
 */

include "ai/orderPlan.cw"
include "ai/policyShape.cw"
include "client/designRow.cw"
include "client/fleetRow.cw"
include "client/planetRow.cw"
include "client/progressJob.cw"
include "client/stateView.cw"
include "client/stockRow.cw"

start {
    bool ok = true
    AiOrderPlan planner = AiOrderPlan()
    AiPolicyShape shape = AiPolicyShape()
    shape.roleName = "neutral"
    shape.expansionPct = 60

    ClientStateView snap = ClientStateView(0)
    FleetRow fleet = FleetRow()
    fleet.id = 1
    fleet.visible = true
    fleet.sitting = true
    fleet.ownerId = 0
    fleet.locationPlanetId = 0
    fleet.hullCount = 3
    fleet.order = "sit"
    snap.fleets.append(fleet)

    PlanetRow home = PlanetRow()
    home.id = 0
    home.visible = true
    home.qualityKnown = true
    home.ownerId = 0
    home.shipyard = true
    snap.planets.append(home)

    PlanetRow unknown = PlanetRow()
    unknown.id = 2
    unknown.visible = true
    unknown.qualityKnown = false
    unknown.ownerId = -1
    snap.planets.append(unknown)

    AiOrderIntent explore = planner.plan(snap, shape)
    if (not explore.kind.equals("order")) {
        ok = false
    }
    if (ok and not explore.order.equals("explore")) {
        ok = false
    }
    if (ok and explore.fleetId != 1) {
        ok = false
    }
    if (ok and explore.destPlanetId != 2) {
        ok = false
    }
    if (ok and explore.hulls != 1) {
        ok = false
    }

    # No unknown rocks: expansion hungry → take unowned known.
    snap.planets = []
    snap.planets.append(home)
    PlanetRow freeRock = PlanetRow()
    freeRock.id = 3
    freeRock.visible = true
    freeRock.qualityKnown = true
    freeRock.ownerId = -1
    snap.planets.append(freeRock)
    shape.roleName = "conqueror"
    AiOrderIntent take = planner.plan(snap, shape)
    if (ok and not take.kind.equals("order")) {
        ok = false
    }
    if (ok and not take.order.equals("take")) {
        ok = false
    }
    if (ok and take.destPlanetId != 3) {
        ok = false
    }

    # No sitting fleet + stock → create "ai-N" before build.
    snap.fleets = []
    DesignRow scout = DesignRow()
    scout.id = 0
    scout.name = "scout"
    scout.scout = true
    scout.ready = true
    snap.designs.append(scout)
    StockRow stock = StockRow()
    stock.designId = 0
    stock.planetId = 0
    stock.count = 2
    snap.stocks.append(stock)
    AiOrderIntent create = planner.plan(snap, shape)
    if (ok and not create.kind.equals("fleet")) {
        ok = false
    }
    if (ok and not create.fleetName.equals("ai-1")) {
        ok = false
    }
    if (ok and create.buildPlanetId != 0) {
        ok = false
    }

    # Empty named fleet at yard + stock → assign.
    FleetRow empty = FleetRow()
    empty.id = 4
    empty.visible = true
    empty.sitting = true
    empty.ownerId = 0
    empty.locationPlanetId = 0
    empty.hullCount = 0
    empty.name = "ai-1"
    empty.order = "sit"
    snap.fleets.append(empty)
    AiOrderIntent assign = planner.plan(snap, shape)
    if (ok and not assign.kind.equals("assign")) {
        ok = false
    }
    if (ok and assign.fleetId != 4) {
        ok = false
    }
    if (ok and not assign.typeName.equals("scout")) {
        ok = false
    }
    if (ok and assign.qty != 1) {
        ok = false
    }

    # No sitting fleet / no stock → yard build when ready scout.
    snap.fleets = []
    snap.stocks = []
    AiOrderIntent build = planner.plan(snap, shape)
    if (ok and not build.kind.equals("build")) {
        ok = false
    }
    if (ok and build.buildPlanetId != 0) {
        ok = false
    }
    if (ok and build.buildDesignId != 0) {
        ok = false
    }

    # Already cooking a hull → no second build spam.
    ProgressJob job = ProgressJob()
    job.ownerId = 0
    job.ticksLeft = 3
    snap.buildJobs.append(job)
    AiOrderIntent skipped = planner.plan(snap, shape)
    if (ok and not skipped.kind.equals("none")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
