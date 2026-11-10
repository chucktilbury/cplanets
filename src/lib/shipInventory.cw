/*
 * src/lib/shipInventory.cw — unassigned stock credit/debit helpers.
 *
 * CPL-101: builds fill staged unassigned counts; fleet assign
 * debits them. Geography: stocks sit at a yard/planet, not in an
 * abstract hangar (RULES §5).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial credit / available / debit helpers.
 */

include "hullStock.cw"

/*
 * ShipInventory groups unassigned HullStock row mutations.
 *
 * Purpose: keep State.queue* methods thinner and give unit tests a
 * focused place to assert build→stock and assign debit behavior.
 */
class ShipInventory {
    /*
     * Construct a helper (no per-instance state).
     *
     * Purpose: allow State / Production to call credit/debit
     * without free functions.
     *
     * Parameters: none.
     *
     * Returns: empty ShipInventory helper.
     */
    ShipInventory() {
    }

    /*
     * Count unassigned hulls for one owner/design/planet.
     *
     * Purpose: assign over-check and Ships inventory chrome.
     *
     * Parameters:
     *   stocks — mutable HullStock list on State.
     *   ownerId — empire seat.
     *   designId — type id.
     *   planetId — stage planet (-1 sums all planets for owner+type).
     *
     * Returns: available hull count (>= 0).
     */
    int64 available(
        list stocks,
        int64 ownerId,
        int64 designId,
        int64 planetId) {
        int64 total = 0
        int64 index = 0
        while (index < stocks.length) {
            HullStock row = stocks[index]
            if (row.ownerId == ownerId
                and row.designId == designId
                and (planetId < 0 or row.planetId == planetId)) {
                total = total + row.count
            }
            index = index + 1
        }
        return(total)
    }

    /*
     * Credit hulls into an unassigned stock row at a planet.
     *
     * Purpose: build completion and any future return-to-stock path.
     * Merges into an existing matching row when present.
     *
     * Parameters:
     *   stocks — mutable HullStock list.
     *   ownerId — empire seat.
     *   designId — ready design id.
     *   planetId — stage planet (yard that built them).
     *   hulls — count to add (> 0).
     *
     * Returns: new total for that row, or -1 when hulls <= 0.
     */
    int64 credit(
        list stocks,
        int64 ownerId,
        int64 designId,
        int64 planetId,
        int64 hulls) {
        if (hulls <= 0) {
            return(-1)
        }
        int64 index = 0
        while (index < stocks.length) {
            HullStock row = stocks[index]
            if (row.ownerId == ownerId
                and row.designId == designId
                and row.planetId == planetId) {
                row.count = row.count + hulls
                stocks[index] = row
                return(row.count)
            }
            index = index + 1
        }
        HullStock born = HullStock(
            ownerId, designId, planetId, hulls)
        stocks.append(born)
        return(hulls)
    }

    /*
     * Debit hulls from unassigned stock at one planet.
     *
     * Purpose: fleet assign and stock reclaim. Hard-refuses when
     * available < hulls (no silent truncate).
     *
     * Parameters:
     *   stocks — mutable HullStock list.
     *   ownerId — empire seat.
     *   designId — type id.
     *   planetId — stage planet to debit.
     *   hulls — count to remove (> 0).
     *
     * Returns: true when debited; false when over-assign / missing.
     */
    bool debit(
        list stocks,
        int64 ownerId,
        int64 designId,
        int64 planetId,
        int64 hulls) {
        if (hulls <= 0) {
            return(false)
        }
        int64 index = 0
        while (index < stocks.length) {
            HullStock row = stocks[index]
            if (row.ownerId == ownerId
                and row.designId == designId
                and row.planetId == planetId) {
                if (row.count < hulls) {
                    return(false)
                }
                row.count = row.count - hulls
                stocks[index] = row
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Sum unassigned hulls of one design for an owner (all planets).
     *
     * Purpose: free design name when total hull presence hits zero.
     *
     * Parameters:
     *   stocks — HullStock list.
     *   ownerId — empire seat.
     *   designId — type id.
     *
     * Returns: total unassigned count.
     */
    int64 totalForDesign(
        list stocks, int64 ownerId, int64 designId) {
        return(available(stocks, ownerId, designId, -1))
    }
}
