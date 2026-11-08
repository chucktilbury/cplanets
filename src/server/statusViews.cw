/*
 * src/server/statusViews.cw — read-only formatters for operator status.
 *
 * Builds text snapshots from GameDriver / State / ServerConfig so the
 * interactive status menu (and unit tests) can explore what the server
 * knows without mutating game state. Config views are dump-only.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial read-only status formatters.
 *   2026-11-08  Drop menu= from server config dump.
 */

include "config.cw"
include "driver.cw"

/*
 * StatusViews formats live server game state as plain text lines.
 *
 * Holds the same GameDriver the serve path owns (sole writer) plus
 * the loaded ServerConfig. Every method is read-only aside from
 * string assembly — no tick, policy, or order side effects.
 */
class StatusViews {
    GameDriver driver
    ServerConfig cfg

    /*
     * Construct formatters around a live driver and its config.
     *
     * Purpose: share one State with --serve without a second
     * authoritative world.
     *
     * Parameters:
     *   live — GameDriver already wrapping a started State.
     *   loaded — ServerConfig after file + argv overlays.
     *
     * Returns: StatusViews ready for summary / drill-down text.
     */
    StatusViews(GameDriver live, ServerConfig loaded) {
        driver = live
        cfg = loaded
    }

    /*
     * One-line top status: tick, pause, seat/planet/fleet counts.
     *
     * Purpose: top-menu banner so operators see cadence at a glance.
     *
     * Parameters: none.
     *
     * Returns: single summary line (no trailing newline).
     */
    String summaryLine() {
        State game = driver.game
        String paused = "false"
        if (driver.paused) {
            paused = "true"
        }
        String ended = "false"
        if (game.ended) {
            ended = "true"
        }
        return(format(
            "tick={} paused={} ended={} players={} planets={} fleets={} builds={} designs={}",
            game.tickCount,
            paused,
            ended,
            game.players.length,
            game.galaxy.planets.length,
            game.fleets.length,
            game.builds.length,
            game.designs.length))
    }

    /*
     * Multi-line status summary block for menu choice 1.
     *
     * Purpose: expand the banner with end reason / winner when set.
     *
     * Parameters: none.
     *
     * Returns: multi-line text ending with a newline.
     */
    String statusSummary() {
        State game = driver.game
        String text = format("{}\n", summaryLine())
        if (game.ended) {
            text.append(format(
                "endReason={} winnerId={}\n",
                game.endReason,
                game.winnerId))
        }
        text.append(format(
            "locked={} nextFleetId={} nextDesignId={}\n",
            game.locked,
            game.nextFleetId,
            game.nextDesignId))
        return(text)
    }

    /*
     * Count planets owned by one seat.
     *
     * Purpose: player inventory line without duplicating filters.
     *
     * Parameters:
     *   playerId — empire seat id.
     *
     * Returns: owned planet count.
     */
    int64 countOwnedPlanets(int64 playerId) {
        State game = driver.game
        int64 count = 0
        int64 index = 0
        while (index < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[index]
            if (rock.ownerId == playerId) {
                count = count + 1
            }
            index = index + 1
        }
        return(count)
    }

    /*
     * Count fleets owned by one seat.
     *
     * Purpose: player inventory line.
     *
     * Parameters:
     *   playerId — empire seat id.
     *
     * Returns: owned fleet count.
     */
    int64 countOwnedFleets(int64 playerId) {
        State game = driver.game
        int64 count = 0
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet fleet = game.fleets[index]
            if (fleet.ownerId == playerId) {
                count = count + 1
            }
            index = index + 1
        }
        return(count)
    }

    /*
     * Sum hulls on fleets owned by one seat.
     *
     * Purpose: ship count on the player inventory line.
     *
     * Parameters:
     *   playerId — empire seat id.
     *
     * Returns: total hullCount across owned fleets.
     */
    int64 countOwnedHulls(int64 playerId) {
        State game = driver.game
        int64 count = 0
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet fleet = game.fleets[index]
            if (fleet.ownerId == playerId) {
                count = count + fleet.hullCount
                count = count + fleet.escortHullCount
            }
            index = index + 1
        }
        return(count)
    }

    /*
     * Resolve a design name by id, or a fallback token.
     *
     * Purpose: fleet / job lines without repeating bounds checks.
     *
     * Parameters:
     *   designId — index into State.designs.
     *
     * Returns: design.name, or "?" / "none" when missing.
     */
    String designName(int64 designId) {
        if (designId < 0) {
            return("none")
        }
        State game = driver.game
        if (designId >= game.designs.length) {
            return("?")
        }
        Design design = game.designs[designId]
        if (design.name.length == 0) {
            return(format("design{}", designId))
        }
        return(design.name)
    }

    /*
     * Numbered list of empire seats.
     *
     * Purpose: Players menu — pick a seat by list index.
     *
     * Parameters: none.
     *
     * Returns: multi-line seat list.
     */
    String playerList() {
        State game = driver.game
        String text = "Players:\n"
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            text.append(format(
                "  [{}] id={} role={} wealth={} res={} tech={} planets={} fleets={} ships={}\n",
                index + 1,
                seat.id,
                seat.role,
                seat.wealth,
                seat.resources,
                seat.tech,
                countOwnedPlanets(seat.id),
                countOwnedFleets(seat.id),
                countOwnedHulls(seat.id)))
            index = index + 1
        }
        return(text)
    }

    /*
     * Detail block for one empire seat.
     *
     * Purpose: player drill-down before Planets/Fleets/Designs subs.
     *
     * Parameters:
     *   playerId — empire seat id (not list ordinal).
     *
     * Returns: multi-line detail, or an error line when out of range.
     */
    String playerDetail(int64 playerId) {
        State game = driver.game
        if (playerId < 0 or playerId >= game.players.length) {
            return(format("player {} not found\n", playerId))
        }
        Player seat = game.players[playerId]
        String human = "false"
        if (seat.human) {
            human = "true"
        }
        String text = format(
            "Player id={} role={} human={}\n",
            seat.id,
            seat.role,
            human)
        text.append(format(
            "  wealth={} resources={} tech={}\n",
            seat.wealth,
            seat.resources,
            seat.tech))
        text.append(format(
            "  power={} experience={} detection={}\n",
            seat.power,
            seat.experience,
            seat.detectionRange))
        text.append(format(
            "  present={} quit={} dropped={} eliminated={} partition={}\n",
            seat.present,
            seat.quit,
            seat.dropped,
            seat.eliminated,
            seat.partitionId))
        text.append(format(
            "  owned planets={} fleets={} ships={}\n",
            countOwnedPlanets(seat.id),
            countOwnedFleets(seat.id),
            countOwnedHulls(seat.id)))
        return(text)
    }

    /*
     * List planets, optionally filtered by owner.
     *
     * Purpose: top Planets menu (ownerFilter < 0) or player-owned
     * sub-list (ownerFilter = seat id).
     *
     * Parameters:
     *   ownerFilter — owner id, or -1 for all rocks.
     *
     * Returns: numbered multi-line list (ordinal → planet id).
     */
    String planetList(int64 ownerFilter) {
        State game = driver.game
        String text = "Planets:\n"
        if (ownerFilter >= 0) {
            text = format("Planets owned by {}:\n", ownerFilter)
        }
        int64 shown = 0
        int64 index = 0
        while (index < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[index]
            if (ownerFilter < 0 or rock.ownerId == ownerFilter) {
                shown = shown + 1
                String flags = ""
                if (rock.productive) {
                    flags.append("P")
                }
                if (rock.shipyard) {
                    flags.append("Y")
                }
                if (rock.population > 0.0) {
                    flags.append("O")
                }
                if (flags.length == 0) {
                    flags = "-"
                }
                text.append(format(
                    "  [{}] id={} owner={} flags={} alloc={}% liv={} res={}\n",
                    shown,
                    rock.id,
                    rock.ownerId,
                    flags,
                    rock.allocationPct,
                    rock.livability,
                    rock.resources))
            }
            index = index + 1
        }
        if (shown == 0) {
            text.append("  (none)\n")
        }
        return(text)
    }

    /*
     * Map a 1-based list ordinal from planetList to a planet id.
     *
     * Purpose: menu pick → stable planet id under the same filter.
     *
     * Parameters:
     *   ownerFilter — same filter as planetList (-1 = all).
     *   ordinal — 1-based index as shown in the list.
     *
     * Returns: planet id, or -1 when the ordinal is out of range.
     */
    int64 planetIdAt(int64 ownerFilter, int64 ordinal) {
        if (ordinal < 1) {
            return(-1)
        }
        State game = driver.game
        int64 shown = 0
        int64 index = 0
        while (index < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[index]
            if (ownerFilter < 0 or rock.ownerId == ownerFilter) {
                shown = shown + 1
                if (shown == ordinal) {
                    return(rock.id)
                }
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Detail block for one planet, including sitting fleets / jobs.
     *
     * Purpose: planet drill-down (owner, yield flags, defenses, yard).
     *
     * Parameters:
     *   planetId — galaxy planet id.
     *
     * Returns: multi-line detail text.
     */
    String planetDetail(int64 planetId) {
        State game = driver.game
        if (planetId < 0
            or planetId >= game.galaxy.planets.length) {
            return(format("planet {} not found\n", planetId))
        }
        Planet rock = game.galaxy.planets[planetId]
        String text = format(
            "Planet id={} owner={} x={} y={}\n",
            rock.id,
            rock.ownerId,
            rock.x,
            rock.y)
        text.append(format(
            "  livability={} resources={} useful={} qualityKnown={}\n",
            rock.livability,
            rock.resources,
            rock.useful,
            rock.qualityKnown))
        text.append(format(
            "  productive={} shipyard={} population={} alloc={}%\n",
            rock.productive,
            rock.shipyard,
            rock.population,
            rock.allocationPct))
        text.append(format(
            "  satelliteDefense={} partition={}\n",
            rock.satelliteDefense,
            rock.partitionId))
        text.append("  Sitting fleets:\n")
        int64 sits = 0
        int64 fi = 0
        while (fi < game.fleets.length) {
            Fleet fleet = game.fleets[fi]
            if (fleet.sitting
                and fleet.locationPlanetId == planetId) {
                sits = sits + 1
                text.append(format(
                    "    fleet {} owner={} {} x{} order={}\n",
                    fleet.id,
                    fleet.ownerId,
                    designName(fleet.designId),
                    fleet.hullCount,
                    fleet.order))
            }
            fi = fi + 1
        }
        if (sits == 0) {
            text.append("    (none)\n")
        }
        text.append("  Yard jobs:\n")
        int64 jobs = 0
        int64 bi = 0
        while (bi < game.builds.length) {
            BuildJob job = game.builds[bi]
            if (job.planetId == planetId) {
                jobs = jobs + 1
                text.append(format(
                    "    build {} owner={} {} left={} cost={}\n",
                    job.id,
                    job.ownerId,
                    designName(job.designId),
                    job.ticksLeft,
                    job.resourceCost))
            }
            bi = bi + 1
        }
        int64 ri = 0
        while (ri < game.reclaims.length) {
            ReclaimJob job = game.reclaims[ri]
            if (job.planetId == planetId) {
                jobs = jobs + 1
                text.append(format(
                    "    reclaim {} owner={} {} hulls={} left={}\n",
                    job.id,
                    job.ownerId,
                    designName(job.designId),
                    job.hullCount,
                    job.ticksLeft))
            }
            ri = ri + 1
        }
        if (jobs == 0) {
            text.append("    (none)\n")
        }
        return(text)
    }

    /*
     * List fleets, optionally filtered by owner.
     *
     * Purpose: top Fleets menu or player-owned sub-list.
     *
     * Parameters:
     *   ownerFilter — owner id, or -1 for all fleets.
     *
     * Returns: numbered multi-line list (ordinal → fleet id).
     */
    String fleetList(int64 ownerFilter) {
        State game = driver.game
        String text = "Fleets:\n"
        if (ownerFilter >= 0) {
            text = format("Fleets owned by {}:\n", ownerFilter)
        }
        int64 shown = 0
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet fleet = game.fleets[index]
            if (ownerFilter < 0 or fleet.ownerId == ownerFilter) {
                shown = shown + 1
                String where = "sit"
                if (fleet.departed or fleet.pendingDeparture) {
                    where = "flight"
                }
                text.append(format(
                    "  [{}] id={} owner={} {} {} x{} @{} →{} eta={}\n",
                    shown,
                    fleet.id,
                    fleet.ownerId,
                    where,
                    designName(fleet.designId),
                    fleet.hullCount,
                    fleet.locationPlanetId,
                    fleet.destPlanetId,
                    fleet.eta))
            }
            index = index + 1
        }
        if (shown == 0) {
            text.append("  (none)\n")
        }
        return(text)
    }

    /*
     * Map a 1-based list ordinal from fleetList to a fleet id.
     *
     * Purpose: menu pick → stable fleet id under the same filter.
     *
     * Parameters:
     *   ownerFilter — same filter as fleetList (-1 = all).
     *   ordinal — 1-based index as shown in the list.
     *
     * Returns: fleet id, or -1 when the ordinal is out of range.
     */
    int64 fleetIdAt(int64 ownerFilter, int64 ordinal) {
        if (ordinal < 1) {
            return(-1)
        }
        State game = driver.game
        int64 shown = 0
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet fleet = game.fleets[index]
            if (ownerFilter < 0 or fleet.ownerId == ownerFilter) {
                shown = shown + 1
                if (shown == ordinal) {
                    return(fleet.id)
                }
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Find a fleet by id (not list index).
     *
     * Purpose: detail lookup after fleetIdAt.
     *
     * Parameters:
     *   fleetId — State fleet id.
     *
     * Returns: index into game.fleets, or -1 when missing.
     */
    int64 fleetIndexOf(int64 fleetId) {
        State game = driver.game
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet fleet = game.fleets[index]
            if (fleet.id == fleetId) {
                return(index)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Detail block for one fleet (location, mix, cargo, orders).
     *
     * Purpose: fleet drill-down from the Fleets menus.
     *
     * Parameters:
     *   fleetId — stable fleet id.
     *
     * Returns: multi-line detail text.
     */
    String fleetDetail(int64 fleetId) {
        int64 index = fleetIndexOf(fleetId)
        if (index < 0) {
            return(format("fleet {} not found\n", fleetId))
        }
        Fleet fleet = driver.game.fleets[index]
        String where = "sitting"
        if (fleet.departed) {
            where = "in-flight"
        } else (fleet.pendingDeparture) {
            where = "pending-departure"
        }
        String text = format(
            "Fleet id={} owner={} status={} order={}\n",
            fleet.id,
            fleet.ownerId,
            where,
            fleet.order)
        text.append(format(
            "  location={} sender={} dest={} eta={} traveled={}\n",
            fleet.locationPlanetId,
            fleet.senderPlanetId,
            fleet.destPlanetId,
            fleet.eta,
            fleet.ticksTraveled))
        text.append(format(
            "  design={} ({}) hulls={}\n",
            fleet.designId,
            designName(fleet.designId),
            fleet.hullCount))
        if (fleet.escortHullCount > 0 or fleet.escortDesignId >= 0) {
            text.append(format(
                "  escort={} ({}) hulls={}\n",
                fleet.escortDesignId,
                designName(fleet.escortDesignId),
                fleet.escortHullCount))
        }
        text.append(format(
            "  cargoW={} cargoR={} lootW={} lootR={}\n",
            fleet.cargoWealth,
            fleet.cargoResources,
            fleet.lootWealth,
            fleet.lootResources))
        text.append(format(
            "  recall={} stranded={} left={} engagement={}\n",
            fleet.recallRequested,
            fleet.stranded,
            fleet.strandedLeft,
            fleet.engagementId))
        text.append(format(
            "  pendingArrival={} agreement={} tradeSize={}\n",
            fleet.pendingArrivalOrder,
            fleet.agreementId,
            fleet.tradeSize))
        return(text)
    }

    /*
     * List hull designs (ready / developing).
     *
     * Purpose: Designs / jobs menu and player Designs sub-view.
     *
     * Parameters: none (designs are global templates in State).
     *
     * Returns: multi-line design list.
     */
    String designList() {
        State game = driver.game
        String text = "Designs:\n"
        int64 index = 0
        while (index < game.designs.length) {
            Design design = game.designs[index]
            String ready = "ready"
            if (not design.isReady()) {
                ready = format("developing left={}", design.developTicksLeft)
            }
            if (design.closed) {
                ready = "closed"
            }
            text.append(format(
                "  [{}] id={} name={} spd={} reach={} size={} hold={} {}\n",
                index + 1,
                design.id,
                design.name,
                design.speed,
                design.hopReach,
                design.size,
                design.cargoHold,
                ready))
            index = index + 1
        }
        if (game.designs.length == 0) {
            text.append("  (none)\n")
        }
        return(text)
    }

    /*
     * List in-progress yard build and reclaim jobs.
     *
     * Purpose: Designs / jobs menu second section.
     *
     * Parameters: none.
     *
     * Returns: multi-line jobs list.
     */
    String jobsList() {
        State game = driver.game
        String text = "Build jobs:\n"
        int64 index = 0
        while (index < game.builds.length) {
            BuildJob job = game.builds[index]
            text.append(format(
                "  build {} owner={} planet={} {} left={} cost={}\n",
                job.id,
                job.ownerId,
                job.planetId,
                designName(job.designId),
                job.ticksLeft,
                job.resourceCost))
            index = index + 1
        }
        if (game.builds.length == 0) {
            text.append("  (none)\n")
        }
        text.append("Reclaim jobs:\n")
        index = 0
        while (index < game.reclaims.length) {
            ReclaimJob job = game.reclaims[index]
            text.append(format(
                "  reclaim {} owner={} planet={} {} hulls={} left={}\n",
                job.id,
                job.ownerId,
                job.planetId,
                designName(job.designId),
                job.hullCount,
                job.ticksLeft))
            index = index + 1
        }
        if (game.reclaims.length == 0) {
            text.append("  (none)\n")
        }
        return(text)
    }

    /*
     * Read-only dump of server process / network config.
     *
     * Purpose: Config menu — what --config loaded (no write/save).
     *
     * Parameters: none.
     *
     * Returns: multi-line ServerConfig dump.
     */
    String serverConfigDump() {
        String text = "Server config (read-only):\n"
        text.append(format("  setup={}\n", cfg.setup))
        text.append(format("  host={} port={}\n", cfg.host, cfg.port))
        text.append(format(
            "  players={} seed={} cycles={}\n",
            cfg.players,
            cfg.seed,
            cfg.cycles))
        text.append(format(
            "  serve={} injectable={} verbosity={}\n",
            cfg.serve,
            cfg.injectable,
            cfg.verbosity))
        text.append(format(
            "  handshake_miss_ms={} accept_poll_ms={}\n",
            cfg.handshakeMissMs,
            cfg.acceptPollMs))
        return(text)
    }

    /*
     * Read-only dump of loaded scenario / setup knobs.
     *
     * Purpose: Config menu — §14 magnitudes the server started with.
     *
     * Parameters: none.
     *
     * Returns: multi-line Scenario dump (category blocks).
     */
    String scenarioConfigDump() {
        Scenario sc = driver.game.scenario
        String text = "Scenario setup (read-only):\n"
        text.append(format(
            "  mode={} tickPeriod={}s autoAiLag={} verbosity={}\n",
            sc.scenarioMode,
            sc.tickPeriodSeconds,
            sc.tickAutoConfigFromAiLag,
            sc.verbosity))
        text.append(format(
            "  worlds={} usefulMix={} scoutRange={} radius={}\n",
            sc.worldCount,
            sc.usefulMix,
            sc.scoutRange,
            sc.galaxyRadius))
        text.append(format(
            "  start wealth={} res={} tech={} power={} xp={}\n",
            sc.startWealth,
            sc.startResources,
            sc.startTech,
            sc.startPower,
            sc.startExperience))
        text.append(format(
            "  designDevelopTicks={} yardBuildTicks={} reclaimPct={}\n",
            sc.designDevelopTicks,
            sc.yardBuildTicks,
            sc.reclaimPercent))
        text.append(format(
            "  voyageCost={} strandedTicks={} pirateIdle={}\n",
            sc.voyageCost,
            sc.strandedTicksN,
            sc.pirateIdleTicks))
        text.append(format(
            "  productionTickRate={} afkTimeout={}s shrink={}\n",
            sc.productionTickRate,
            sc.afkTimeoutSeconds,
            sc.afkShrinkFactor))
        text.append(format(
            "  techRangeBase={} perTech={} teleportAt={} on={}\n",
            sc.techRangeBase,
            sc.techRangePerTech,
            sc.techTeleportThreshold,
            sc.techTeleportEnabled))
        return(text)
    }
}
