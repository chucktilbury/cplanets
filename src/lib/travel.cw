/*
 * src/lib/travel.cw — range, ETA, and tech teleport (Phase C).
 *
 * ETA is distance/speed shaped by technology; high tech maps to
 * ETA 0 (teleport) via scenario threshold (RULES §6 / §14). Hop
 * reach is a hull attribute from an occupied world.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial travel math for tick core.
 */

import math as TravelMath

include "design.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"

/*
 * Travel computes hop distance and ETA for fleet orders.
 *
 * Pure helpers: no state mutation. Stranding decisions live in
 * the dispatch phase that calls canHop. Uses alias TravelMath so
 * it can coexist with galaxy.cw's Math import.
 */
class Travel {
    TravelMath.Math math

    /*
     * Construct a travel helper with a Math instance.
     *
     * Purpose: share one Math.sqrt/ceil path across ETA calls
     * without static imports at every call site.
     *
     * Parameters: none.
     *
     * Returns: Travel ready for distance / etaTicks.
     */
    Travel() {
        math = TravelMath.Math()
    }

    /*
     * Euclidean distance between two planets.
     *
     * Purpose: feed ETA and hop-reach checks.
     *
     * Parameters:
     *   a — origin planet.
     *   b — destination planet.
     *
     * Returns: non-negative fp64 distance in galaxy units.
     */
    fp64 distance(Planet a, Planet b) {
        fp64 dx = a.x - b.x
        fp64 dy = a.y - b.y
        return(math.sqrt(dx * dx + dy * dy))
    }

    /*
     * True when the hop is within the design's reach.
     *
     * Purpose: enforce RULES §6 hop-from-occupied-world limit
     * before dispatch spends wealth.
     *
     * Parameters:
     *   design — hull template providing hopReach.
     *   a — origin.
     *   b — destination.
     *
     * Returns: true when distance <= design.hopReach.
     */
    bool canHop(Design design, Planet a, Planet b) {
        fp64 dist = distance(a, b)
        return(dist <= design.hopReach)
    }

    /*
     * Compute travel ETA in ticks for one hop.
     *
     * Purpose: distance/speed with tech teleport mapping. Zero
     * distance or teleport tech yields ETA 0; otherwise at least
     * one tick when there is a positive distance.
     *
     * Parameters:
     *   scenario — tech→teleport threshold.
     *   player — technology attribute.
     *   design — speed for the hop.
     *   a — origin planet.
     *   b — destination planet.
     *
     * Returns: integer ETA ticks (>= 0).
     */
    int64 etaTicks(
        Scenario scenario,
        Player player,
        Design design,
        Planet a,
        Planet b) {
        if (scenario.teleports(player.tech)) {
            return(0)
        }
        fp64 dist = distance(a, b)
        if (dist <= 0.0) {
            return(0)
        }
        fp64 speed = design.speed
        if (speed <= 0.0) {
            speed = 1.0
        }
        fp64 raw = dist / speed
        fp64 rounded = math.ceil(raw)
        int64 ticks = int64(rounded)
        if (ticks < 1) {
            ticks = 1
        }
        return(ticks)
    }

    /*
     * Recall ETA after turning toward the sender.
     *
     * Purpose: return leg is ticks already spent outbound, or
     * zero when technology teleports (RULES §5.2).
     *
     * Parameters:
     *   scenario — teleport mapping.
     *   player — technology attribute.
     *   ticksSpent — ticksTraveled on the outbound leg.
     *
     * Returns: integer return ETA (>= 0).
     */
    int64 recallEta(
        Scenario scenario,
        Player player,
        int64 ticksSpent) {
        if (scenario.teleports(player.tech)) {
            return(0)
        }
        if (ticksSpent < 0) {
            return(0)
        }
        return(ticksSpent)
    }
}
