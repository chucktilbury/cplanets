/*
 * tests/unit/unit_aiStatusMenu.cw — AI explore status view walk.
 *
 * Builds an AiExploreState with a synthetic ClientStateView and
 * checks summary / seat / planet / fleet / design / config /
 * decisions tokens without stdin.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI status menu unit program.
 */

include "ai/config.cw"
include "ai/exploreState.cw"
include "ai/policyShape.cw"
include "ai/reaction.cw"
include "ai/statusViews.cw"
include "ai/verboseLog.cw"
include "client/designRow.cw"
include "client/fleetRow.cw"
include "client/planetRow.cw"
include "client/stateView.cw"

start {
    bool ok = true

    AiConfig cfg = AiConfig()
    cfg.playerId = 1
    cfg.host = "127.0.0.1"
    cfg.port = 7700
    cfg.verbosity = 3
    cfg.clampAll()
    ReactionLag lag = ReactionLag()
    AiVerboseLog verbose = AiVerboseLog()
    verbose.setLevel(3)
    verbose.echo = false
    verbose.emit("verbosity: seat player=1 handshake=ok\n")
    AiExploreState state = AiExploreState(cfg, lag, verbose)
    state.noteDial(true)
    state.noteHandshake(true)

    ClientStateView snap = ClientStateView(1)
    snap.tick = 4
    snap.wealthMilli = 1500
    snap.resourcesMilli = 800
    PlanetRow home = PlanetRow()
    home.id = 0
    home.visible = true
    home.ownerId = 1
    home.shipyard = true
    home.qualityKnown = true
    home.livabilityDisplay = 7
    home.resourcesDisplay = 5
    snap.planets.append(home)
    FleetRow stack = FleetRow()
    stack.id = 1
    stack.visible = true
    stack.ownerId = 1
    stack.sitting = true
    stack.hullCount = 2
    stack.locationPlanetId = 0
    snap.fleets.append(stack)
    DesignRow design = DesignRow()
    design.id = 1
    design.name = "scout"
    design.scout = true
    design.ready = true
    snap.designs.append(design)
    state.noteSnapshot(snap, 4)

    AiPolicyShape shape = AiPolicyShape()
    shape.roleName = "conqueror"
    shape.expansionPct = 55
    state.notePolicy(shape, "put")
    state.noteCycle(0, "put")

    AiStatusViews views = AiStatusViews(state)
    String summary = views.summaryLine()
    if (not summary.contains("seat=1")) {
        ok = false
    }
    if (not summary.contains("tick=4")) {
        ok = false
    }
    if (not summary.contains("dial=true")) {
        ok = false
    }
    if (not summary.contains("snapshot=true")) {
        ok = false
    }

    String status = views.statusSummary()
    if (not status.contains("role=")) {
        ok = false
    }
    if (not status.contains("lastCycle index=0")) {
        ok = false
    }

    String seat = views.seatDetail()
    if (not seat.contains("Seat id=1")) {
        ok = false
    }

    String planets = views.planetList()
    if (not planets.contains("Planets (client-visible):")) {
        ok = false
    }
    if (not planets.contains("[1]")) {
        ok = false
    }
    int64 planetId = views.planetIdAt(1)
    if (planetId != 0) {
        ok = false
    } else {
        String detail = views.planetDetail(planetId)
        if (not detail.contains("Planet")) {
            ok = false
        }
    }

    String fleets = views.fleetList()
    if (not fleets.contains("Fleets (client-visible):")) {
        ok = false
    }
    int64 fleetId = views.fleetIdAt(1)
    if (fleetId != 1) {
        ok = false
    }

    String designs = views.designList()
    if (not designs.contains("Designs (from last snapshot):")) {
        ok = false
    }
    if (not designs.contains("scout")) {
        ok = false
    }

    String config = views.configDump()
    if (not config.contains("AI config (read-only):")) {
        ok = false
    }
    if (not config.contains("playerId=1")) {
        ok = false
    }

    String decisions = views.decisionsDump()
    if (not decisions.contains("lastPolicy via=put")) {
        ok = false
    }
    if (not decisions.contains("verbosity: seat")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
