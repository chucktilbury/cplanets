/*
 * src/lib/hullStock.cw — unassigned hull inventory staged at a yard.
 *
 * Builds credit empire stocks here instead of auto-spawning a
 * sitting fleet (CPL-101 / RULES §5). Stocks are keyed by owner +
 * design + planet so reclaim/build geography and range-from-
 * occupied-world stay intact without treating unassigned hulls as
 * a fleet.
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial HullStock for unassigned yard inventory.
 */

/*
 * HullStock is one unassigned type-count at a planet.
 *
 * Purpose: hold built (or returned) hulls that are not yet in a
 * named fleet. Assign moves count into a fleet at the same rock;
 * reclaim peels from stock at a shipyard.
 */
class HullStock {
    int64 ownerId
    int64 designId
    int64 planetId
    int64 count

    /*
     * Construct a stock row for one type at one rock.
     *
     * Purpose: allocate before credit/debit helpers mutate count.
     *
     * Parameters:
     *   owner — empire seat that owns the hulls.
     *   design — ready design id.
     *   planet — stage planet (usually the yard that built them).
     *   hulls — initial unassigned count (>= 0).
     *
     * Returns: HullStock with the given keys and count.
     */
    HullStock(
        int64 owner,
        int64 design,
        int64 planet,
        int64 hulls) {
        ownerId = owner
        designId = design
        planetId = planet
        count = hulls
    }
}
