/*
 * src/lib/screen.cw — weaker-hull screening for combat losses.
 *
 * RULES §12: weaker hulls die first and screen; frigates tend to
 * die; destroyers without a screen are more vulnerable; colony
 * hulls do not screen. Losses are per design. Magnitudes stay
 * scenario-owned placeholders (PLAN D4).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial screening helpers for Phase D4.
 */

include "design.cw"
include "fleet.cw"

/*
 * Screen applies comparative-strength hits with light-first deaths.
 *
 * Callers pass a hit measured in strength points; this helper
 * removes hulls from fleets of one side, preferring screen hulls
 * before heavies. While any non-colony screen hull remains, heavies
 * absorb only a fraction of the remaining hit.
 */
class Screen {
    /*
     * Construct a screening helper.
     *
     * Purpose: match other combat-phase objects.
     *
     * Parameters: none.
     *
     * Returns: Screen instance.
     */
    Screen() {
    }

    /*
     * True when a design can screen heavier hulls.
     *
     * Purpose: colony never screens; defense/satellite and light
     * war hulls (size < heavy threshold) do.
     *
     * Parameters:
     *   design — hull template.
     *
     * Returns: true when this design screens heavies.
     */
    bool canScreen(Design design) {
        if (design.colony) {
            return(false)
        }
        if (design.defense) {
            return(true)
        }
        return(design.size < 4.0)
    }

    /*
     * True when a design is a heavy that benefits from screens.
     *
     * Purpose: destroyer-class and larger take reduced losses while
     * screens remain (RULES §12).
     *
     * Parameters:
     *   design — hull template.
     *
     * Returns: true when size >= 4 and not colony/defense.
     */
    bool isHeavy(Design design) {
        if (design.colony or design.defense) {
            return(false)
        }
        return(design.size >= 4.0)
    }

    /*
     * Apply a strength hit to fleets of one owner in an engagement.
     *
     * Purpose: kill screen hulls first; heavies take only 25% of
     * leftover hit while any screen hull remains, else full hit.
     *
     * Parameters:
     *   fleets — mutable fleet list.
     *   designs — design list.
     *   engagementId — open fight id (-1 = match by planet).
     *   planetId — rock id when engagementId < 0.
     *   ownerId — side taking losses.
     *   hit — strength points to remove (>= 0).
     *
     * Returns: strength actually removed from hulls.
     */
    fp64 applyHit(
        list fleets,
        list designs,
        int64 engagementId,
        int64 planetId,
        int64 ownerId,
        fp64 hit) {
        if (hit <= 0.0) {
            return(0.0)
        }
        fp64 removed = removeFromBand(
            fleets,
            designs,
            engagementId,
            planetId,
            ownerId,
            hit,
            1)
        fp64 left = hit - removed
        if (left <= 0.0) {
            return(removed)
        }
        bool screensLeft = hasScreenHull(
            fleets,
            designs,
            engagementId,
            planetId,
            ownerId)
        fp64 heavyHit = left
        if (screensLeft) {
            heavyHit = left * 0.25
        }
        fp64 heavyRemoved = removeFromBand(
            fleets,
            designs,
            engagementId,
            planetId,
            ownerId,
            heavyHit,
            2)
        removed = removed + heavyRemoved
        left = hit - removed
        if (left > 0.0) {
            fp64 rest = removeFromBand(
                fleets,
                designs,
                engagementId,
                planetId,
                ownerId,
                left,
                3)
            removed = removed + rest
        }
        return(removed)
    }

    /*
     * True when the side still has a non-colony screen hull.
     *
     * Purpose: gate the heavy-protection discount.
     *
     * Parameters:
     *   fleets / designs — lists.
     *   engagementId / planetId / ownerId — side filter.
     *
     * Returns: true when at least one screening hull remains.
     */
    bool hasScreenHull(
        list fleets,
        list designs,
        int64 engagementId,
        int64 planetId,
        int64 ownerId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (sideMatch(
                fleet,
                engagementId,
                planetId,
                ownerId)
                and fleet.hullCount > 0
                and fleet.designId >= 0
                and fleet.designId < designs.length) {
                Design design = designs[fleet.designId]
                if (canScreen(design)) {
                    return(true)
                }
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Remove strength from one band: 1=screen, 2=heavy, 3=other.
     *
     * Purpose: ordered attrition without sorting lists in place.
     *
     * Parameters:
     *   fleets / designs — lists.
     *   engagementId / planetId / ownerId — side filter.
     *   hit — strength to remove.
     *   band — 1 screen, 2 heavy, 3 colony/other.
     *
     * Returns: strength removed in this band.
     */
    fp64 removeFromBand(
        list fleets,
        list designs,
        int64 engagementId,
        int64 planetId,
        int64 ownerId,
        fp64 hit,
        int64 band) {
        fp64 need = hit
        fp64 gone = 0.0
        int64 index = 0
        while (index < fleets.length and need > 0.0) {
            Fleet fleet = fleets[index]
            if (sideMatch(
                fleet,
                engagementId,
                planetId,
                ownerId)
                and fleet.hullCount > 0
                and fleet.designId >= 0
                and fleet.designId < designs.length) {
                Design design = designs[fleet.designId]
                bool take = false
                if (band == 1 and canScreen(design)) {
                    take = true
                } else (band == 2 and isHeavy(design)) {
                    take = true
                } else (band == 3
                    and not canScreen(design)
                    and not isHeavy(design)) {
                    take = true
                }
                if (take) {
                    fp64 per = design.combatStrength()
                    if (per <= 0.0) {
                        fleet.hullCount = 0
                        fleets[index] = fleet
                    } else {
                        int64 kill = int64(need / per + 0.999)
                        if (kill < 1) {
                            kill = 1
                        }
                        if (kill > fleet.hullCount) {
                            kill = fleet.hullCount
                        }
                        fleet.hullCount = fleet.hullCount - kill
                        fleets[index] = fleet
                        fp64 lost = fp64(kill) * per
                        gone = gone + lost
                        need = need - lost
                    }
                }
            }
            index = index + 1
        }
        return(gone)
    }

    /*
     * True when a fleet belongs to the losing side filter.
     *
     * Purpose: match engagement participants, or sitters at a
     * planet when engagementId is unset.
     *
     * Parameters:
     *   fleet — candidate.
     *   engagementId — fight id, or −1.
     *   planetId — rock when engagementId < 0.
     *   ownerId — side owner.
     *
     * Returns: true when the fleet is on that side.
     */
    bool sideMatch(
        Fleet fleet,
        int64 engagementId,
        int64 planetId,
        int64 ownerId) {
        if (fleet.ownerId != ownerId) {
            return(false)
        }
        if (engagementId >= 0) {
            return(fleet.engagementId == engagementId)
        }
        if (fleet.locationPlanetId != planetId) {
            return(false)
        }
        return(fleet.sitting or fleet.engagementId >= 0)
    }
}
