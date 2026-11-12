/*
 * src/lib/planet.cw — galaxy rock state (Phase B / D1 / D5 / CPL-112).
 *
 * Planets exist at game start. Quality stays unknown until explore
 * or take (RULES §3 / §13). Home is already productive with a yard.
 * D1 adds satelliteDefense for parked defense layers (§11.2).
 * D5 tags each rock with a sandbox partitionId for contact.
 * CPL-112: air / water / common+rare minerals with accessibility;
 * livability and resources stay derived farming / industry
 * composites for production and 1–10 display.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial planet fields for setup galaxy.
 *   2026-11-05  Phase D1: satelliteDefense for Ho-shaped leave-behind.
 *   2026-11-05  Phase D5: partitionId for sandbox contact.
 *   2026-11-07  allocationPct stand-in for planet budget chrome.
 *   2026-11-07  allocationPct scales production empire-pool credit.
 *   2026-11-10  Stable display name; planet 0 defaults to "Home".
 *   2026-11-11  CPL-112: air/water/minerals + accessibility;
 *               habitTicksLeft for colony terraforming delay.
 */

/*
 * Planet is one rock in the galaxy snapshot.
 *
 * Placement, inherent quality (four resources + accessibility),
 * ownership, productive/yard/explored flags, sandbox partition,
 * and the satellite defense layer used when warships leave.
 * Empire stocks stay on the Player; these fields are rock quality
 * only and must not block a later per-planet shipping layer.
 */
class Planet {
    int64 id
    # Stable UI / wire label. Planet index 0 is "Home" (primary
    # seat home). Other rocks default to "Planet {id}".
    String name
    fp64 x
    fp64 y
    # Derived farming composite ≈ (air + water) / 2.
    fp64 livability
    # Derived industry composite ≈ common + rare * rareWeight.
    fp64 resources
    # Inherent quantities (internal min..max setup units).
    fp64 air
    fp64 water
    fp64 commonMinerals
    fp64 rareMinerals
    # Accessibility 0..1 (1 = easy extract / terraform).
    fp64 airAccess
    fp64 waterAccess
    fp64 commonMineralsAccess
    fp64 rareMineralsAccess
    bool useful
    bool productive
    bool shipyard
    bool qualityKnown
    int64 ownerId
    fp64 population
    fp64 satelliteDefense
    int64 partitionId
    int64 allocationPct
    # Colony terraforming countdown; 0 = idle / already habitable.
    int64 habitTicksLeft

    /*
     * Construct an unowned, unexplored rock at the origin.
     *
     * Purpose: allocate a planet slot before galaxy placement fills
     * coordinates and mix. Index 0 is named "Home"; every other
     * slot gets a unique "Planet {id}" label for dropdown chrome.
     *
     * Parameters:
     *   planetId — stable index in the galaxy list.
     *
     * Returns: Planet with unknown quality and no owner.
     */
    Planet(int64 planetId) {
        id = planetId
        if (planetId == 0) {
            name = "Home"
        } else {
            name = format("Planet {}", planetId)
        }
        x = 0.0
        y = 0.0
        livability = 0.0
        resources = 0.0
        air = 0.0
        water = 0.0
        commonMinerals = 0.0
        rareMinerals = 0.0
        airAccess = 1.0
        waterAccess = 1.0
        commonMineralsAccess = 1.0
        rareMineralsAccess = 1.0
        useful = false
        productive = false
        shipyard = false
        qualityKnown = false
        ownerId = -1
        population = 0.0
        satelliteDefense = 0.0
        partitionId = 0
        # Full existing production magnitudes by default; PUT
        # /budget may throttle to allocationPct/100 (DIALOGS §4.2).
        allocationPct = 100
        habitTicksLeft = 0
    }

    /*
     * Refresh livability / resources composites from quantities.
     *
     * Purpose: keep derived farming (air+water) and industry
     * (common + rare×weight) in sync after galaxy mix or edits
     * (CPL-112 / RULES §3).
     *
     * Parameters:
     *   rareWeight — setup rare_mineral_weight (>= 0).
     *
     * Returns: nothing; mutates livability and resources.
     */
    void refreshComposites(fp64 rareWeight) {
        fp64 weight = rareWeight
        if (weight < 0.0) {
            weight = 0.0
        }
        livability = (air + water) * 0.5
        resources = commonMinerals + rareMinerals * weight
    }

    /*
     * Mean air+water accessibility for terraforming difficulty.
     *
     * Purpose: low access → longer / costlier habitability
     * (CPL-112).
     *
     * Parameters: none.
     *
     * Returns: mean of airAccess and waterAccess (unclamped).
     */
    fp64 habitAccess() {
        return((airAccess + waterAccess) * 0.5)
    }

    /*
     * Mean mineral accessibility for extract / yard difficulty.
     *
     * Purpose: low mineral access → higher yard cost and longer
     * build times; also scales industry production (CPL-112).
     *
     * Parameters: none.
     *
     * Returns: mean of common and rare mineral access.
     */
    fp64 mineralAccess() {
        return((commonMineralsAccess + rareMineralsAccess) * 0.5)
    }

    /*
     * Squared distance to another point in the galaxy plane.
     *
     * Purpose: scout-range tests without importing Math.sqrt.
     *
     * Parameters:
     *   ox — other x coordinate.
     *   oy — other y coordinate.
     *
     * Returns: (dx*dx + dy*dy) as fp64.
     */
    fp64 distanceSquaredTo(fp64 ox, fp64 oy) {
        fp64 dx = x - ox
        fp64 dy = y - oy
        return(dx * dx + dy * dy)
    }

    /*
     * True when this rock lies within range of a point.
     *
     * Purpose: mark starting scout-neighborhood membership.
     *
     * Parameters:
     *   ox — observer x.
     *   oy — observer y.
     *   reach — inclusive distance in galaxy units.
     *
     * Returns: true when distanceSquared <= reach*reach.
     */
    bool inRangeOf(fp64 ox, fp64 oy, fp64 reach) {
        return(distanceSquaredTo(ox, oy) <= reach * reach)
    }
}
