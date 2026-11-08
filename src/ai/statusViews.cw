/*
 * src/ai/statusViews.cw — read-only formatters for AI status menu.
 *
 * Builds plain-text snapshots from AiExploreState so the operator
 * can explore what this AI client knows — not server authority.
 * Config dumps are read-only; no write/save.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI client status formatters.
 *   2026-11-08  Summary line includes suspended flag.
 */

include "../client/designRow.cw"
include "../client/fleetRow.cw"
include "../client/planetRow.cw"
include "exploreState.cw"

/*
 * AiStatusViews formats live AI client knowledge as text lines.
 *
 * Every method is read-only aside from string assembly. Planets /
 * fleets / designs come from the last decoded GET snapshot when
 * present; otherwise the text says the view is empty.
 */
class AiStatusViews {
    AiExploreState state

    /*
     * Construct formatters around a live explore bag.
     *
     * Purpose: share one AiExploreState with the serve-loop.
     *
     * Parameters:
     *   live — AiExploreState owned by AiClient / menu gate.
     *
     * Returns: AiStatusViews ready for summary / drill-down text.
     */
    AiStatusViews(AiExploreState live) {
        state = live
    }

    /*
     * One-line top banner: seat, tick, dial, pause, error hint.
     *
     * Purpose: top-menu header so operators see cadence at a glance.
     *
     * Parameters: none.
     *
     * Returns: single summary line (no trailing newline).
     */
    String summaryLine() {
        String dial = "false"
        if (state.dialOk) {
            dial = "true"
        }
        String handshake = "false"
        if (state.handshakeOk) {
            handshake = "true"
        }
        String paused = "false"
        if (state.decisionPaused) {
            paused = "true"
        }
        String suspended = "false"
        if (state.suspended) {
            suspended = "true"
        }
        String snap = "false"
        if (state.hasSnapshot) {
            snap = "true"
        }
        String err = "(none)"
        if (state.lastError.length > 0) {
            err = state.lastError
        }
        return(format(
            "seat={} tick={} dial={} handshake={} snapshot={} paused={} suspended={} cycles={} lastError={}",
            state.config.playerId,
            state.view.publishedTick,
            dial,
            handshake,
            snap,
            paused,
            suspended,
            state.cyclesDone,
            err))
    }

    /*
     * Multi-line status summary for menu choice 1.
     *
     * Purpose: expand the banner with role / lag / last cycle.
     *
     * Parameters: none.
     *
     * Returns: multi-line text ending with a newline.
     */
    String statusSummary() {
        String ambush = "false"
        if (state.view.ambushLocked) {
            ambush = "true"
        }
        String lagEver = "false"
        if (state.lag.everUpdated) {
            lagEver = "true"
        }
        String text = format("{}\n", summaryLine())
        text.append(format(
            "role={} ambushLocked={} competitors={}\n",
            state.view.currentRole,
            ambush,
            state.view.knownCompetitorCount))
        text.append(format(
            "wealth={} resources={} tech={} detection={}\n",
            state.view.wealth,
            state.view.resources,
            state.view.tech,
            state.view.detectionRange))
        text.append(format(
            "lag ever={} lastTick={} lastMs={}\n",
            lagEver,
            state.lag.lastUpdateTick,
            state.lag.lastUpdateMs))
        if (state.lastCycleIndex >= 0) {
            text.append(format(
                "lastCycle index={} action={}\n",
                state.lastCycleIndex,
                state.lastCycleAction))
        } else {
            text.append("lastCycle=(none)\n")
        }
        if (state.hasSnapshot) {
            String ended = "false"
            if (state.snapshot.ended) {
                ended = "true"
            }
            text.append(format(
                "snapshot planets={} fleets={} designs={} ended={}\n",
                state.snapshot.planets.length,
                state.snapshot.fleets.length,
                state.snapshot.designs.length,
                ended))
        } else {
            text.append("snapshot=(none yet)\n")
        }
        return(text)
    }

    /*
     * Seat / role detail block.
     *
     * Purpose: menu choice for this client's identity and pools.
     *
     * Parameters: none.
     *
     * Returns: multi-line seat text.
     */
    String seatDetail() {
        String ambush = "false"
        if (state.view.ambushLocked) {
            ambush = "true"
        }
        String text = format(
            "Seat id={} role={} ambushLocked={}\n",
            state.view.playerId,
            state.view.currentRole,
            ambush)
        text.append(format(
            "wealth={} resources={} tech={}\n",
            state.view.wealth,
            state.view.resources,
            state.view.tech))
        text.append(format(
            "detectionRange={} knownCompetitors={}\n",
            state.view.detectionRange,
            state.view.knownCompetitorCount))
        if (state.hasSnapshot) {
            text.append(state.snapshot.knownCompetitorsText())
        }
        return(text)
    }

    /*
     * Last decoded snapshot header summary.
     *
     * Purpose: menu choice before drilling into lists.
     *
     * Parameters: none.
     *
     * Returns: multi-line snapshot summary.
     */
    String snapshotSummary() {
        if (not state.hasSnapshot) {
            return(
                "Snapshot: (none — GET /state not decoded yet)\n")
        }
        ClientStateView snap = state.snapshot
        String ended = "false"
        if (snap.ended) {
            ended = "true"
        }
        String paused = "false"
        if (snap.paused) {
            paused = "true"
        }
        String text = format(
            "Snapshot tick={} ended={} winnerId={} viewerId={}\n",
            snap.tick,
            ended,
            snap.winnerId,
            snap.viewerId)
        text.append(format(
            "visible planets={} fleets={} designs={} humans={}\n",
            snap.visiblePlanetCount(),
            snap.visibleFleetCount(),
            snap.designs.length,
            snap.humanCount))
        text.append(format(
            "paused={} wealthMilli={} resourcesMilli={}\n",
            paused,
            snap.wealthMilli,
            snap.resourcesMilli))
        return(text)
    }

    /*
     * Visible planet list from the last snapshot.
     *
     * Purpose: planets browse; client visibility only.
     *
     * Parameters: none.
     *
     * Returns: numbered multi-line list text.
     */
    String planetList() {
        if (not state.hasSnapshot) {
            return("Planets: (no snapshot)\n")
        }
        String text = "Planets (client-visible):\n"
        int64 shown = 0
        int64 index = 0
        while (index < state.snapshot.planets.length) {
            PlanetRow row = state.snapshot.planets[index]
            if (row.visible) {
                shown = shown + 1
                text.append(format(
                    "[{}] {}\n", shown, row.listLabel()))
            }
            index = index + 1
        }
        if (shown < 1) {
            text.append("(none visible)\n")
        }
        return(text)
    }

    /*
     * Map a 1-based list ordinal to a visible planet id.
     *
     * Purpose: menu detail lookup without exposing hidden rows.
     *
     * Parameters:
     *   ordinal — 1-based index in the visible list.
     *
     * Returns: planet id, or -1 when out of range.
     */
    int64 planetIdAt(int64 ordinal) {
        if (not state.hasSnapshot or ordinal < 1) {
            return(-1)
        }
        int64 shown = 0
        int64 index = 0
        while (index < state.snapshot.planets.length) {
            PlanetRow row = state.snapshot.planets[index]
            if (row.visible) {
                shown = shown + 1
                if (shown == ordinal) {
                    return(row.id)
                }
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Detail text for one planet id from the snapshot.
     *
     * Purpose: planet drill-down.
     *
     * Parameters:
     *   planetId — rock id.
     *
     * Returns: multi-line detail, or a missing stub.
     */
    String planetDetail(int64 planetId) {
        if (not state.hasSnapshot) {
            return("Planet: (no snapshot)\n")
        }
        PlanetRow row = state.snapshot.findPlanet(planetId)
        if (row.id < 0) {
            return(format("Planet id={}: (not in view)\n", planetId))
        }
        String visible = "false"
        if (row.visible) {
            visible = "true"
        }
        String quality = "false"
        if (row.qualityKnown) {
            quality = "true"
        }
        String productive = "false"
        if (row.productive) {
            productive = "true"
        }
        String populated = "false"
        if (row.populated) {
            populated = "true"
        }
        String yard = "false"
        if (row.shipyard) {
            yard = "true"
        }
        String text = format("{}\n", row.listLabel())
        text.append(format(
            "visible={} qualityKnown={} productive={} populated={} shipyard={}\n",
            visible,
            quality,
            productive,
            populated,
            yard))
        text.append(format(
            "ownerId={} alloc={}% x={} y={}\n",
            row.ownerId,
            row.allocationPct,
            row.x,
            row.y))
        return(text)
    }

    /*
     * Visible fleet list from the last snapshot.
     *
     * Purpose: fleets browse; client visibility only.
     *
     * Parameters: none.
     *
     * Returns: numbered multi-line list text.
     */
    String fleetList() {
        if (not state.hasSnapshot) {
            return("Fleets: (no snapshot)\n")
        }
        String text = "Fleets (client-visible):\n"
        int64 shown = 0
        int64 index = 0
        while (index < state.snapshot.fleets.length) {
            FleetRow row = state.snapshot.fleets[index]
            if (row.visible) {
                shown = shown + 1
                text.append(format(
                    "[{}] {}\n", shown, row.listLabel()))
            }
            index = index + 1
        }
        if (shown < 1) {
            text.append("(none visible)\n")
        }
        return(text)
    }

    /*
     * Map a 1-based list ordinal to a visible fleet id.
     *
     * Purpose: menu detail lookup.
     *
     * Parameters:
     *   ordinal — 1-based index in the visible list.
     *
     * Returns: fleet id, or -1 when out of range.
     */
    int64 fleetIdAt(int64 ordinal) {
        if (not state.hasSnapshot or ordinal < 1) {
            return(-1)
        }
        int64 shown = 0
        int64 index = 0
        while (index < state.snapshot.fleets.length) {
            FleetRow row = state.snapshot.fleets[index]
            if (row.visible) {
                shown = shown + 1
                if (shown == ordinal) {
                    return(row.id)
                }
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Detail text for one fleet id from the snapshot.
     *
     * Purpose: fleet drill-down.
     *
     * Parameters:
     *   fleetId — fleet id.
     *
     * Returns: multi-line detail, or a missing stub.
     */
    String fleetDetail(int64 fleetId) {
        if (not state.hasSnapshot) {
            return("Fleet: (no snapshot)\n")
        }
        FleetRow row = state.snapshot.findFleet(fleetId)
        if (row.id < 0) {
            return(format("Fleet id={}: (not in view)\n", fleetId))
        }
        return(format("{}\n", row.listLabel()))
    }

    /*
     * Design catalog from the last snapshot chrome trailer.
     *
     * Purpose: designs browse (client catalog, not server yard
     * authority beyond what GET published).
     *
     * Parameters: none.
     *
     * Returns: multi-line design list text.
     */
    String designList() {
        if (not state.hasSnapshot) {
            return("Designs: (no snapshot)\n")
        }
        String text = "Designs (from last snapshot):\n"
        if (state.snapshot.designs.length < 1) {
            text.append("(none)\n")
            return(text)
        }
        int64 index = 0
        while (index < state.snapshot.designs.length) {
            DesignRow row = state.snapshot.designs[index]
            text.append(format(
                "[{}] {}\n", index + 1, row.listLabel()))
            index = index + 1
        }
        text.append(state.snapshot.progressText())
        return(text)
    }

    /*
     * Read-only AI config dump (dial + difficulty axes).
     *
     * Purpose: config menu section; no write/save.
     *
     * Parameters: none.
     *
     * Returns: multi-line config text.
     */
    String configDump() {
        AiConfig cfg = state.config
        String once = "false"
        if (cfg.once) {
            once = "true"
        }
        String serveLoop = "false"
        if (cfg.serveLoop) {
            serveLoop = "true"
        }
        String text = "AI config (read-only):\n"
        text.append(format(
            "host={} port={} playerId={} seed={}\n",
            cfg.host,
            cfg.port,
            cfg.playerId,
            cfg.seed))
        text.append(format(
            "verbosity={} cycles={} once={} serveLoop={}\n",
            cfg.verbosity,
            cfg.cycles,
            once,
            serveLoop))
        text.append(format(
            "aggression={} stickiness={} expansion={} escort={}\n",
            cfg.aggression,
            cfg.roleStickiness,
            cfg.expansion,
            cfg.escort))
        text.append(format(
            "agreement={} techVsHulls={} surprise={}\n",
            cfg.agreementAppetite,
            cfg.techVsHulls,
            cfg.surpriseRate))
        text.append(format(
            "reactionLagTicks={} reactionLagSeconds={}\n",
            cfg.reactionLagTicks,
            cfg.reactionLagSeconds))
        return(text)
    }

    /*
     * Recent decisions / verbosity capture + last policy.
     *
     * Purpose: decisions/errors menu section.
     *
     * Parameters: none.
     *
     * Returns: multi-line decisions text.
     */
    String decisionsDump() {
        String text = format(
            "Verbosity level={} (decisionsAt={} fullAt={})\n",
            state.verbose.level,
            state.verbose.decisionsAt,
            state.verbose.fullAt)
        if (state.hasPolicy) {
            int64 surprise = 0
            if (state.lastPolicy.surpriseApplied) {
                surprise = 1
            }
            text.append(format(
                "lastPolicy via={} role={} expansion={} escort={} agreement={} tech={} surprise={}\n",
                state.lastPolicyVia,
                state.lastPolicy.roleName,
                state.lastPolicy.expansionPct,
                state.lastPolicy.escortPct,
                state.lastPolicy.agreementS,
                state.lastPolicy.techBiasPct,
                surprise))
        } else {
            text.append("lastPolicy=(none)\n")
        }
        if (state.lastError.length > 0) {
            text.append(format("lastError={}\n", state.lastError))
        } else {
            text.append("lastError=(none)\n")
        }
        text.append("Recent verbosity lines:\n")
        if (state.verbose.lines.length < 1) {
            text.append("(none captured)\n")
            return(text)
        }
        int64 index = 0
        while (index < state.verbose.lines.length) {
            text.append(state.verbose.lines[index])
            index = index + 1
        }
        return(text)
    }
}
