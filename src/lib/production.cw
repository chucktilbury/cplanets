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
 *   2026-11-10  completeBuild credits unassigned HullStock (CPL-101)
 *               instead of auto-spawning / merging a sitting fleet.
 *   2026-11-09  reclaim event fleetId carries designId so State can
 *               free the type name after the last hulls reclaim.
 *   2026-11-11  CPL-112: farming vs industry production axes;
 *               accessibility scales credit; advance habit ticks.
 *   2026-11-11  CPL-113: per-planet net = credit − upkeep; clamp
 *               empire pools at zero when debit exceeds stock.
 */

include "design.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"
include "shipInventory.cw"

/*
 * Production runs RULES §7 step 1 for one tick.
 *
 * Mutates players (empire pools), designs (develop countdown),
 * build/reclaim jobs, and unassigned hull stocks (completed
 * builds). Appends events. Fleets are no longer auto-spawned on
 * yard complete (CPL-101).
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
     *   stocks — mutable unassigned HullStock list.
     *   events — event log to append.
     *   nextFleetId — unused after CPL-101 (kept for tick signature).
     *
     * Returns: nextFleetId unchanged (builds no longer spawn fleets).
     */
    int64 run(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list builds,
        list reclaims,
        list stocks,
        list events,
        int64 nextFleetId) {
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            if (rock.habitTicksLeft > 0) {
                advanceHabit(rock, planets, index, events)
                rock = planets[index]
            }
            if (rock.productive and rock.ownerId >= 0) {
                producePlanet(scenario, rock, players, events)
            }
            index = index + 1
        }
        advanceDesigns(designs, events)
        advanceBuilds(scenario, builds, designs, stocks, events)
        advanceReclaims(scenario, reclaims, players, events)
        return(nextFleetId)
    }

    /*
     * Decrement colony terraforming countdown; mark productive.
     *
     * Purpose: CPL-112 — low air/water accessibility delays
     * habitability after populate. Stocks stay empire-wide.
     *
     * Parameters:
     *   rock — planet with habitTicksLeft > 0.
     *   planets — mutable galaxy list.
     *   index — rock index in planets.
     *   events — event log.
     *
     * Returns: nothing; may set productive and clear habitTicksLeft.
     */
    void advanceHabit(
        Planet rock,
        list planets,
        int64 index,
        list events) {
        rock.habitTicksLeft = rock.habitTicksLeft - 1
        if (rock.habitTicksLeft <= 0) {
            rock.habitTicksLeft = 0
            rock.productive = true
            events.append(
                TickEvent(
                    "habit",
                    -1,
                    rock.id,
                    rock.ownerId,
                    1))
        }
        planets[index] = rock
    }

    /*
     * Apply one productive planet's net income to empire pools.
     *
     * Purpose: CPL-113 — each productive rock yields
     *   net = production credit − upkeep
     * Farming (air+water → wealth) and industry (minerals →
     * resources) are independent. Credit scales with accessibility;
     * upkeep scales with accessDifficulty (1/access). Net may be
     * negative (ongoing debit into the empire pool). Empire-pool
     * path only — no per-planet stockpile. When a debit would drive
     * a pool below zero, clamp that axis to zero (planet-index
     * order; remaining stock absorbs a partial debit).
     *
     * Parameters:
     *   scenario — cover / production / upkeep rates, accessFloor.
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
        fp64 wealthUpkeepRate = scenario.wealthUpkeepTickRate
        if (wealthUpkeepRate < 0.0) {
            wealthUpkeepRate = 0.0
        }
        fp64 resUpkeepRate = scenario.resourcesUpkeepTickRate
        if (resUpkeepRate < 0.0) {
            resUpkeepRate = 0.0
        }
        fp64 scale = seat.afkProductionScale
        fp64 alloc = allocationFraction(rock.allocationPct)
        fp64 shared = scenario.coverFactor * rate * scale * alloc
        fp64 farmAccess = rock.habitAccess()
        fp64 farmDiff = scenario.accessDifficulty(farmAccess)
        fp64 mineAccess = rock.mineralAccess()
        fp64 mineDiff = scenario.accessDifficulty(mineAccess)
        # Clamp access the same way difficulty floors it, so credit
        # never uses a raw below-floor access while upkeep uses floor.
        if (farmAccess < scenario.accessFloor) {
            farmAccess = scenario.accessFloor
        }
        if (farmAccess < 0.0) {
            farmAccess = 0.0
        }
        if (mineAccess < scenario.accessFloor) {
            mineAccess = scenario.accessFloor
        }
        if (mineAccess < 0.0) {
            mineAccess = 0.0
        }
        fp64 wealthCredit = rock.livability * farmAccess * shared
        # Upkeep uses difficulty and its own rate; share cover/AFK/
        # allocation so throttling a rock throttles both sides.
        fp64 wealthUpkeep = (
            rock.livability
            * farmDiff
            * wealthUpkeepRate
            * scenario.coverFactor
            * scale
            * alloc)
        fp64 wealthNet = wealthCredit - wealthUpkeep
        fp64 resCredit = rock.resources * mineAccess * shared
        fp64 resUpkeep = (
            rock.resources
            * mineDiff
            * resUpkeepRate
            * scenario.coverFactor
            * scale
            * alloc)
        fp64 resNet = resCredit - resUpkeep
        wealthNet = clampPoolDelta(seat.wealth, wealthNet)
        resNet = clampPoolDelta(seat.resources, resNet)
        seat.wealth = seat.wealth + wealthNet
        seat.resources = seat.resources + resNet
        players[rock.ownerId] = seat
        events.append(
            TickEvent("production", -1, rock.id, seat.id, 1))
    }

    /*
     * Truncate a pool delta so the resulting stock stays >= 0.
     *
     * Purpose: CPL-113 coherent clamp — empire wealth/resources
     * never go negative from planet upkeep. Credits pass through;
     * debits that exceed the current stock become a full drain.
     *
     * Parameters:
     *   stock — current empire pool value (>= 0 expected).
     *   delta — proposed credit (positive) or debit (negative).
     *
     * Returns: delta, or -stock when debit would overdraw.
     */
    fp64 clampPoolDelta(fp64 stock, fp64 delta) {
        if (delta >= 0.0) {
            return(delta)
        }
        if (stock + delta >= 0.0) {
            return(delta)
        }
        if (stock <= 0.0) {
            return(0.0)
        }
        return(0.0 - stock)
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
     * Advance yard BuildJobs; complete hulls into unassigned stock.
     *
     * Purpose: non-instant yard production (RULES §5.3 / §7.1).
     * CPL-101: completed hulls stage at the yard, not auto-fleet.
     *
     * Parameters:
     *   scenario — unused placeholder for future cost knobs.
     *   builds — mutable job list (completed jobs removed).
     *   designs — design list for validation.
     *   stocks — mutable unassigned HullStock list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void advanceBuilds(
        Scenario scenario,
        list builds,
        list designs,
        list stocks,
        list events) {
        list remaining = []
        int64 index = 0
        while (index < builds.length) {
            BuildJob job = builds[index]
            job.ticksLeft = job.ticksLeft - 1
            if (job.ticksLeft <= 0) {
                completeBuild(job, designs, stocks, events)
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
    }

    /*
     * Deliver completed hulls into unassigned stock at the yard.
     *
     * Purpose: builds do not auto-place into a fleet (CPL-101).
     * Hulls stage at the yard planet until fleet assign. CPL-111
     * credits job.hullCount (batch qty) instead of a hard-coded 1.
     *
     * Parameters:
     *   job — completed BuildJob.
     *   designs — design list (must be ready).
     *   stocks — mutable unassigned HullStock list.
     *   events — event log.
     *
     * Returns: nothing.
     */
    void completeBuild(
        BuildJob job,
        list designs,
        list stocks,
        list events) {
        if (job.designId < 0 or job.designId >= designs.length) {
            return()
        }
        Design design = designs[job.designId]
        if (not design.isReady()) {
            return()
        }
        int64 hulls = job.hullCount
        if (hulls < 1) {
            hulls = 1
        }
        ShipInventory book = ShipInventory()
        book.credit(
            stocks,
            job.ownerId,
            job.designId,
            job.planetId,
            hulls)
        events.append(
            TickEvent(
                "yard",
                -1,
                job.planetId,
                job.ownerId,
                hulls))
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
     * development (RULES §5.2). Emits a "reclaim" TickEvent whose
     * fleetId slot carries job.designId so State.tick can free the
     * type name when no hulls of that design remain (CPL-101).
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
        # fleetId slot carries designId so State.tick can call
        # maybeFreeDesign after the last hulls of a type reclaim
        # (CPL-101 name free). value remains hull count for digest.
        events.append(
            TickEvent(
                "reclaim",
                job.designId,
                job.planetId,
                job.ownerId,
                job.hullCount))
    }
}
