/*
 * src/lib/production.cw — tick phase 1: production + yard builds.
 *
 * Productive planets feed the empire pool; shipyard BuildJobs
 * advance by one tick. Exact formulas are setup placeholders
 * (RULES §7 / §14 / §17). No trade or combat.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial production phase for tick core.
 *   2026-11-05  Phase D4: advance reclaim jobs at yards.
 *   2026-11-07  Use scenario.productionTickRate + afkProductionScale.
 *   2026-11-07  Scale empire-pool credit by Planet.allocationPct.
 */

include "design.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"

/*
 * Production runs RULES §7 step 1 for one tick.
 *
 * Mutates players (empire pools), designs (develop countdown),
 * build/reclaim jobs, and fleets (completed hulls). Appends events.
 */
class Production {
    /*
     * Construct a stateless production phase helper.
     *
     * Purpose: match other tick-phase objects; work lives in run.
     *
     * Parameters: none.
     *
     * Returns: Production instance.
     */
    Production() {
    }

    /*
     * Apply production for every productive planet and yard job.
     *
     * Purpose: advance empire stocks and non-instant builds /
     * reclaim before cancellations and motion (RULES §7.1).
     *
     * Parameters:
     *   scenario — cover factor, yard timings, reclaim percent.
     *   planets — galaxy planet list.
     *   players — empire seats.
     *   designs — design list (develop countdown).
     *   builds — mutable BuildJob list.
     *   reclaims — mutable ReclaimJob list.
     *   fleets — mutable Fleet list (completed hulls).
     *   events — event log to append.
     *   nextFleetId — in/out counter for new sit fleets.
     *
     * Returns: updated nextFleetId after any new fleets.
     */
    int64 run(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list builds,
        list reclaims,
        list fleets,
        list events,
        int64 nextFleetId) {
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            if (rock.productive and rock.ownerId >= 0) {
                producePlanet(scenario, rock, players, events)
            }
            index = index + 1
        }
        advanceDesigns(designs, events)
        nextFleetId = advanceBuilds(
            scenario,
            builds,
            designs,
            fleets,
            events,
            nextFleetId)
        advanceReclaims(scenario, reclaims, players, events)
        return(nextFleetId)
    }

    /*
     * Credit one productive planet into its owner's pools.
     *
     * Purpose: placeholder production using livability/resources
     * scaled by coverFactor and the planet's allocationPct
     * (PUT /budget). Empire-pool path only — no yard logistics.
     * Magnitudes stay setup knobs; allocation is a 0..100 fraction.
     *
     * Parameters:
     *   scenario — coverFactor / productionTickRate knobs.
     *   rock — productive owned planet (allocationPct spend bias).
     *   players — empire list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void producePlanet(
        Scenario scenario,
        Planet rock,
        list players,
        list events) {
        if (rock.ownerId < 0 or rock.ownerId >= players.length) {
            return()
        }
        Player seat = players[rock.ownerId]
        fp64 rate = scenario.productionTickRate
        fp64 scale = seat.afkProductionScale
        fp64 alloc = allocationFraction(rock.allocationPct)
        fp64 wealthGain = (
            rock.livability
            * scenario.coverFactor
            * rate
            * scale
            * alloc)
        fp64 resGain = (
            rock.resources
            * scenario.coverFactor
            * rate
            * scale
            * alloc)
        seat.wealth = seat.wealth + wealthGain
        seat.resources = seat.resources + resGain
        players[rock.ownerId] = seat
        events.append(
            TickEvent("production", -1, rock.id, seat.id, 1))
    }

    /*
     * Convert a planet allocationPct into a 0..1 production fraction.
     *
     * Purpose: PUT /budget stores 0..100; production multiplies
     * empire-pool credit by that fraction (DIALOGS §4.2).
     *
     * Parameters:
     *   allocationPct — stored planet budget (may be out of range).
     *
     * Returns: clamped fraction in [0.0, 1.0].
     */
    fp64 allocationFraction(int64 allocationPct) {
        int64 pct = allocationPct
        if (pct < 0) {
            pct = 0
        }
        if (pct > 100) {
            pct = 100
        }
        return(fp64(pct) / 100.0)
    }

    /*
     * Decrement in-progress design development timers.
     *
     * Purpose: designing a type takes time (RULES §5.3).
     *
     * Parameters:
     *   designs — mutable design list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void advanceDesigns(list designs, list events) {
        int64 index = 0
        while (index < designs.length) {
            Design design = designs[index]
            if (design.developTicksLeft > 0) {
                design.developTicksLeft = design.developTicksLeft - 1
                designs[index] = design
                if (design.developTicksLeft == 0) {
                    events.append(
                        TickEvent(
                            "design_ready",
                            -1,
                            -1,
                            -1,
                            design.id))
                }
            }
            index = index + 1
        }
    }

    /*
     * Advance yard BuildJobs; complete hulls into sit fleets.
     *
     * Purpose: non-instant yard production (RULES §5.3 / §7.1).
     *
     * Parameters:
     *   scenario — unused placeholder for future cost knobs.
     *   builds — mutable job list (completed jobs removed).
     *   designs — design list for validation.
     *   fleets — mutable fleet list.
     *   events — event log.
     *   nextFleetId — next id for a new sit fleet.
     *
     * Returns: updated nextFleetId.
     */
    int64 advanceBuilds(
        Scenario scenario,
        list builds,
        list designs,
        list fleets,
        list events,
        int64 nextFleetId) {
        list remaining = []
        int64 index = 0
        while (index < builds.length) {
            BuildJob job = builds[index]
            job.ticksLeft = job.ticksLeft - 1
            if (job.ticksLeft <= 0) {
                nextFleetId = completeBuild(
                    job,
                    designs,
                    fleets,
                    events,
                    nextFleetId)
            } else {
                remaining.append(job)
            }
            index = index + 1
        }
        builds.clear()
        index = 0
        while (index < remaining.length) {
            builds.append(remaining[index])
            index = index + 1
        }
        return(nextFleetId)
    }

    /*
     * Deliver one completed hull into a sitting fleet at the yard.
     *
     * Purpose: merge into an existing sit fleet of the same design
     * when possible; otherwise spawn a new sit fleet.
     *
     * Parameters:
     *   job — completed BuildJob.
     *   designs — design list (must be ready).
     *   fleets — mutable fleet list.
     *   events — event log.
     *   nextFleetId — next id if spawning.
     *
     * Returns: updated nextFleetId.
     */
    int64 completeBuild(
        BuildJob job,
        list designs,
        list fleets,
        list events,
        int64 nextFleetId) {
        if (job.designId < 0 or job.designId >= designs.length) {
            return(nextFleetId)
        }
        Design design = designs[job.designId]
        if (not design.isReady()) {
            return(nextFleetId)
        }
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == job.ownerId
                and fleet.locationPlanetId == job.planetId
                and fleet.designId == job.designId
                and fleet.sitting
                and not fleet.pendingDeparture
                and not fleet.departed) {
                fleet.hullCount = fleet.hullCount + 1
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "yard",
                        fleet.id,
                        job.planetId,
                        job.ownerId,
                        1))
                return(nextFleetId)
            }
            index = index + 1
        }
        Fleet born = Fleet(
            nextFleetId,
            job.ownerId,
            job.planetId,
            job.designId,
            1)
        nextFleetId = nextFleetId + 1
        fleets.append(born)
        events.append(
            TickEvent(
                "yard",
                born.id,
                job.planetId,
                job.ownerId,
                1))
        return(nextFleetId)
    }

    /*
     * Advance yard ReclaimJobs; credit reclaim percent on complete.
     *
     * Purpose: reclaim only at a yard, not instant (RULES §5.2).
     * Development wealth is never returned.
     *
     * Parameters:
     *   scenario — reclaimPercent.
     *   reclaims — mutable job list (completed removed).
     *   players — empire pools.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void advanceReclaims(
        Scenario scenario,
        list reclaims,
        list players,
        list events) {
        list remaining = []
        int64 index = 0
        while (index < reclaims.length) {
            ReclaimJob job = reclaims[index]
            job.ticksLeft = job.ticksLeft - 1
            if (job.ticksLeft <= 0) {
                completeReclaim(scenario, job, players, events)
            } else {
                remaining.append(job)
            }
            index = index + 1
        }
        reclaims.clear()
        index = 0
        while (index < remaining.length) {
            reclaims.append(remaining[index])
            index = index + 1
        }
    }

    /*
     * Credit reclaim percent of production basis to the empire.
     *
     * Purpose: setup reclaimPercent of resources; never wealth
     * development (RULES §5.2).
     *
     * Parameters:
     *   scenario — reclaimPercent.
     *   job — completed ReclaimJob.
     *   players — seats.
     *   events — log.
     *
     * Returns: nothing.
     */
    void completeReclaim(
        Scenario scenario,
        ReclaimJob job,
        list players,
        list events) {
        if (job.ownerId < 0 or job.ownerId >= players.length) {
            return()
        }
        fp64 pct = scenario.reclaimPercent
        if (pct < 0.0) {
            pct = 0.0
        }
        if (pct > 1.0) {
            pct = 1.0
        }
        fp64 credit = job.resourceBasis * pct
        Player seat = players[job.ownerId]
        seat.resources = seat.resources + credit
        players[job.ownerId] = seat
        events.append(
            TickEvent(
                "reclaim",
                -1,
                job.planetId,
                job.ownerId,
                job.hullCount))
    }
}
