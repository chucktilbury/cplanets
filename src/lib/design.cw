/*
 * src/lib/design.cw — hull design templates (Phase C).
 *
 * Designs hold speed, hop reach, size/flags, and development /
 * production timing. Magnitudes and cost formulas stay scenario-
 * owned (RULES §5.3 / §14). Instant design/build is out.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Design + yard BuildJob for tick core.
 *   2026-11-05  Phase D1: makeDefense satellite template.
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
     * inventing a full design UI.
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeScout(fp64 hop) {
        name = "scout"
        speed = 2.0
        hopReach = hop
        size = 0.5
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
     * move and stranded tests.
     *
     * Parameters:
     *   hop — hop reach in galaxy units.
     *
     * Returns: nothing; mutates this Design.
     */
    void makeColony(fp64 hop) {
        name = "colony"
        speed = 1.0
        hopReach = hop
        size = 5.0
        cargoHold = 10.0
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
}

/*
 * BuildJob is one in-progress yard hull production.
 *
 * Completes after yardBuildTicks (scenario) unless cancelled.
 * Phase C credits one hull into a sitting fleet at the yard.
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
