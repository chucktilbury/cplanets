/*
 * src/lib/planet.cw — galaxy rock state (Phase B).
 *
 * Planets exist at game start. Quality stays unknown until explore
 * or take (RULES §3 / §13). Home is already productive with a yard.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial planet fields for setup galaxy.
 */

/*
 * Planet is one rock in the galaxy snapshot.
 *
 * Phase B stores placement, inherent quality, ownership, and the
 * productive/yard/explored flags needed for start-of-game checks.
 * Fleets and defenses arrive in later phases.
 */
class Planet {
    int64 id
    fp64 x
    fp64 y
    fp64 livability
    fp64 resources
    bool useful
    bool productive
    bool shipyard
    bool qualityKnown
    int64 ownerId
    fp64 population

    /*
     * Construct an unowned, unexplored rock at the origin.
     *
     * Purpose: allocate a planet slot before galaxy placement fills
     * coordinates and mix.
     *
     * Parameters:
     *   planetId — stable index in the galaxy list.
     *
     * Returns: Planet with unknown quality and no owner.
     */
    Planet(int64 planetId) {
        id = planetId
        x = 0.0
        y = 0.0
        livability = 0.0
        resources = 0.0
        useful = false
        productive = false
        shipyard = false
        qualityKnown = false
        ownerId = -1
        population = 0.0
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
