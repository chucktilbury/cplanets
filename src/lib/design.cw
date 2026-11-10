/*
 * src/lib/design.cw — hull design templates (Phase C / D2).
 *
 * Designs hold speed, hop reach, size/flags, and development /
 * production timing. Magnitudes and cost formulas stay scenario-
 * owned (RULES §5.3 / §14). Instant design/build is out. D2 adds
 * freighter / escort templates and hold-capacity helpers.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Design + yard BuildJob for tick core.
 *   2026-11-05  Phase D1: makeDefense satellite template.
 *   2026-11-05  Phase D2: freighter/escort + hold capacity.
 *   2026-11-05  Phase D4: combatStrength; frigate/destroyer;
 *               ReclaimJob; develop countdown helper.
 *   2026-11-07  make* take speed/size/hold from callers (Scenario).
 *   2026-11-10  ownerId + sameParameters for CPL-101 develop
 *               noop / per-seat name uniqueness.
 */

/*
 * Design is one developed (or developing) hull template.
 *
 * Speed and hopReach feed ETA and cost coefficients. Scout and
 * colony flags select dispatch weights. developTicksLeft > 0 means
 * the design is not yet ready to produce.
 */
class Design {
    int64 id
    # Empire that developed this type; < 0 means shared system
    # template (seeded scout/colony defaults).
    int64 ownerId
    String name
    fp64 speed
    fp64 hopReach
    fp64 size
    fp64 cargoHold
    bool scout
    bool colony
    bool defense
    int64 developTicksLeft
    bool closed

    /*
     * Construct an empty design slot.
     *
     * Purpose: allocate before helpers fill scout/colony defaults
     * or a custom mix.
     *
     * Parameters:
     *   designId — stable index in the state's design list.
     *
     * Returns: Design with zeroed stats and open status.
     */
    Design(int64 designId) {
        id = designId
        ownerId = -1
        name = ""
        speed = 1.0
        hopReach = 1.0
        size = 1.0
        cargoHold = 0.0
        scout = false
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * True when design knobs match another draft (CPL-101 noop).
     *
     * Purpose: develop is a no-op when the seat already has an open
     * type with the same parameters. Equality covers every knob
     * that affects the type: speed, hopReach, size, cargoHold, and
     * scout/colony/defense flags. Name is not part of equality.
     *
     * Parameters:
     *   other — draft or existing design to compare.
     *
     * Returns: true when all type-affecting knobs match.
     */
    bool sameParameters(Design other) {
        if (speed != other.speed) {
            return(false)
        }
        if (hopReach != other.hopReach) {
            return(false)
        }
        if (size != other.size) {
            return(false)
        }
        if (cargoHold != other.cargoHold) {
            return(false)
        }
        if (scout != other.scout) {
            return(false)
        }
        if (colony != other.colony) {
            return(false)
        }
        if (defense != other.defense) {
            return(false)
        }
        return(true)
    }

    /*
     * True when development is finished and the design is open.
     *
     * Purpose: gate yard production without callers repeating the
     * developTicksLeft / closed checks.
     *
     * Parameters: none.
     *
     * Returns: true when ready to queue hull builds.
     */
    bool isReady() {
        if (closed) {
            return(false)
        }
        return(developTicksLeft <= 0)
    }

    /*
     * Fill this slot as the default scout template.
     *
     * Purpose: give Phase C tests a light, long-reach hull without
     * inventing a full design UI. Magnitudes come from Scenario /
     * callers (RULES §14).
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   spd — design speed.
     *   sz — design size / dispatch weight basis.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeScout(fp64 hop, fp64 spd, fp64 sz) {
        name = "scout"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = 0.0
        scout = true
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Fill this slot as the default colony template.
     *
     * Purpose: heavier dispatch weight and shorter reach for sit /
     * move and stranded tests. Magnitudes from Scenario / callers.
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   spd — design speed.
     *   sz — design size / dispatch weight basis.
     *   hold — cargo hold per hull.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeColony(fp64 hop, fp64 spd, fp64 sz, fp64 hold) {
        name = "colony"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = hold
        scout = false
        colony = true
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Fill this slot as a parked satellite / defense hull.
     *
     * Purpose: D1 tests for leave-behind defenses after warships
     * abandon a rock (RULES §11.2).
     *
     * Parameters:
     *   strengthSize — size used as combat strength per hull.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeDefense(fp64 strengthSize) {
        name = "satellite"
        speed = 0.0
        hopReach = 0.0
        size = strengthSize
        cargoHold = 0.0
        scout = false
        colony = false
        defense = true
        developTicksLeft = 0
        closed = false
    }

    /*
     * Fill this slot as a cargo freighter template.
     *
     * Purpose: D2 trade fleets need named hold size so S=100 with
     * hold 10 requires 10 hulls (RULES §5.1 / §8.1).
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   hold — cargo hold per hull.
     *   spd — design speed.
     *   sz — design size.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeFreighter(fp64 hop, fp64 hold, fp64 spd, fp64 sz) {
        name = "freighter"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = hold
        scout = false
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Fill this slot as a light escort war hull (no cargo).
     *
     * Purpose: escorts on a trade mission cycle with the freighters
     * (RULES §5 / §8.2); hold stays zero so they do not cover S.
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   spd — design speed.
     *   sz — design size.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeEscort(fp64 hop, fp64 spd, fp64 sz) {
        name = "escort"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = 0.0
        scout = false
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Total cargo capacity for a hull count of this design.
     *
     * Purpose: gate trade leave when holds must cover S
     * (RULES §5.1 — 10×10 for S=100).
     *
     * Parameters:
     *   hulls — number of hulls of this design.
     *
     * Returns: cargoHold * hulls as fp64.
     */
    fp64 holdCapacity(int64 hulls) {
        if (hulls < 0) {
            return(0.0)
        }
        return(cargoHold * fp64(hulls))
    }

    /*
     * True when this design's holds cover standing size S.
     *
     * Purpose: dispatch refuses trade leave when capacity < S.
     *
     * Parameters:
     *   hulls — cargo hull count.
     *   sizeS — agreement standing size.
     *
     * Returns: true when holdCapacity(hulls) >= sizeS.
     */
    bool coversTradeSize(int64 hulls, fp64 sizeS) {
        return(holdCapacity(hulls) >= sizeS)
    }

    /*
     * Per-hull comparative strength contribution.
     *
     * Purpose: shared §12 input for Combat and Screen without a
     * circular include. Colony hulls are weakly defended.
     *
     * Parameters: none (uses this design's flags/size).
     *
     * Returns: strength points per hull.
     */
    fp64 combatStrength() {
        if (colony) {
            return(size * 0.25)
        }
        return(size)
    }

    /*
     * Fill this slot as a light frigate (screens heavies).
     *
     * Purpose: D4 screening tests — frigates die first and screen
     * destroyers (RULES §12).
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   spd — design speed.
     *   sz — design size.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeFrigate(fp64 hop, fp64 spd, fp64 sz) {
        name = "frigate"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = 0.0
        scout = false
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Fill this slot as a heavy destroyer (needs screens).
     *
     * Purpose: D4 screening — heavies without screens take more
     * losses (RULES §12).
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *   spd — design speed.
     *   sz — design size.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeDestroyer(fp64 hop, fp64 spd, fp64 sz) {
        name = "destroyer"
        speed = spd
        hopReach = hop
        size = sz
        cargoHold = 0.0
        scout = false
        colony = false
        defense = false
        developTicksLeft = 0
        closed = false
    }

    /*
     * Begin non-instant development of this design.
     *
     * Purpose: designing a type takes setup ticks (RULES §5.3).
     *
     * Parameters:
     *   ticks — scenario.designDevelopTicks.
     *
     * Returns: nothing; sets developTicksLeft.
     */
    void beginDevelop(int64 ticks) {
        if (ticks < 1) {
            developTicksLeft = 1
        } else {
            developTicksLeft = ticks
        }
        closed = false
    }
}

/*
 * BuildJob is one in-progress yard hull production.
 *
 * Completes after yardBuildTicks (scenario) unless cancelled.
 * CPL-101 credits one hull into unassigned stock at the yard.
 */
class BuildJob {
    int64 id
    int64 ownerId
    int64 planetId
    int64 designId
    int64 ticksLeft
    fp64 resourceCost

    /*
     * Construct a yard build order.
     *
     * Purpose: track non-instant production (RULES §5.3).
     *
     * Parameters:
     *   jobId — stable id in the state build list.
     *   owner — empire paying resources.
     *   planet — shipyard planet id.
     *   design — design id being built.
     *   ticks — remaining production ticks.
     *   cost — resources already sunk for this hull.
     *
     * Returns: BuildJob ready for the production phase.
     */
    BuildJob(
        int64 jobId,
        int64 owner,
        int64 planet,
        int64 design,
        int64 ticks,
        fp64 cost) {
        id = jobId
        ownerId = owner
        planetId = planet
        designId = design
        ticksLeft = ticks
        resourceCost = cost
    }
}

/*
 * ReclaimJob is one in-progress yard reclaim of interned hulls.
 *
 * Completes after yardBuildTicks (scenario). Credits a setup
 * percent of the sunk production resources; development wealth
 * is never returned (RULES §5.2 / §5.3).
 */
class ReclaimJob {
    int64 id
    int64 ownerId
    int64 planetId
    int64 designId
    int64 hullCount
    int64 ticksLeft
    fp64 resourceBasis

    /*
     * Construct a yard reclaim order.
     *
     * Purpose: track non-instant reclaim at a shipyard.
     *
     * Parameters:
     *   jobId — stable id in the state reclaim list.
     *   owner — empire reclaiming.
     *   planet — shipyard planet id.
     *   design — design id of the hulls.
     *   hulls — number of hulls being reclaimed.
     *   ticks — remaining reclaim ticks.
     *   basis — production-resource basis for percent return.
     *
     * Returns: ReclaimJob ready for the production phase.
     */
    ReclaimJob(
        int64 jobId,
        int64 owner,
        int64 planet,
        int64 design,
        int64 hulls,
        int64 ticks,
        fp64 basis) {
        id = jobId
        ownerId = owner
        planetId = planet
        designId = design
        hullCount = hulls
        ticksLeft = ticks
        resourceBasis = basis
    }
}
