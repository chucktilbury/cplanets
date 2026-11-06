/*
 * src/lib/combat.cw — shared combat entry points (Phase D1 stub).
 *
 * Planet defense and (later) midpoint ambush share strength and
 * advance (RULES §12). D1 stubs multi-tick attrition enough for
 * productive inherent defense and parked/satellite defenders;
 * full design screening / recall-into-fight depth is D4.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial shared combat for take defense.
 */

include "design.cw"
include "engagement.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "scenario.cw"

/*
 * Combat computes comparative strength and advances engagements.
 *
 * Entry points used by Take and TickDriver: needsFight,
 * fleetStrength, defenderStrength, openAtPlanet, advanceAll.
 */
class Combat {
    /*
     * Construct a stateless combat helper.
     *
     * Purpose: match other tick-phase objects.
     *
     * Parameters: none.
     *
     * Returns: Combat instance.
     */
    Combat() {
    }

    /*
     * Per-hull strength contribution for a design.
     *
     * Purpose: colony hulls are weakly defended (RULES §12);
     * defense-flagged hulls count full size; others use size.
     *
     * Parameters:
     *   design — hull template.
     *
     * Returns: strength points per hull.
     */
    fp64 hullStrength(Design design) {
        if (design.colony) {
            return(design.size * 0.25)
        }
        if (design.defense) {
            return(design.size)
        }
        return(design.size)
    }

    /*
     * Comparative strength of one fleet's current hulls.
     *
     * Purpose: attacker and parked-defender inputs for §12.
     *
     * Parameters:
     *   fleet — fleet with hullCount.
     *   design — that fleet's design.
     *
     * Returns: hullCount * per-hull strength.
     */
    fp64 fleetStrength(Fleet fleet, Design design) {
        if (fleet.hullCount <= 0) {
            return(0.0)
        }
        return(fp64(fleet.hullCount) * hullStrength(design))
    }

    /*
     * True when a take on this rock must open combat.
     *
     * Purpose: unowned and undefended non-productive are free;
     * productive owned always fights inherent defense; ships and
     * satellites defend (RULES §11.1–§11.2).
     *
     * Parameters:
     *   scenario — productiveInherentDefense knob.
     *   rock — destination planet.
     *   attackerOwnerId — fleet owner.
     *   parkedStrength — sum of sitting defender fleets here.
     *
     * Returns: true when the take is not free.
     */
    bool needsFight(
        Scenario scenario,
        Planet rock,
        int64 attackerOwnerId,
        fp64 parkedStrength) {
        if (rock.ownerId < 0) {
            return(false)
        }
        if (rock.ownerId == attackerOwnerId) {
            return(false)
        }
        if (parkedStrength > 0.0) {
            return(true)
        }
        if (rock.satelliteDefense > 0.0) {
            return(true)
        }
        if (rock.productive and scenario.productiveInherentDefense > 0.0) {
            return(true)
        }
        return(false)
    }

    /*
     * Defender comparative strength at a rock.
     *
     * Purpose: parked hulls + satellites + productive inherent
     * baseline (RULES §11.2 / §12).
     *
     * Parameters:
     *   scenario — productiveInherentDefense.
     *   rock — defended planet.
     *   parkedStrength — sitting defender fleets' strength.
     *
     * Returns: total defender strength (>= 0).
     */
    fp64 defenderStrength(
        Scenario scenario,
        Planet rock,
        fp64 parkedStrength) {
        fp64 total = parkedStrength
        if (rock.satelliteDefense > 0.0) {
            total = total + rock.satelliteDefense
        }
        if (rock.productive and scenario.productiveInherentDefense > 0.0) {
            total = total + scenario.productiveInherentDefense
        }
        return(total)
    }

    /*
     * Sum strength of sitting fleets owned by owner at planet.
     *
     * Purpose: parked defenders for needsFight / defenderStrength.
     *
     * Parameters:
     *   fleets — all fleets.
     *   designs — design list.
     *   planetId — rock location.
     *   ownerId — defending empire.
     *
     * Returns: summed fleetStrength of matching sitters.
     */
    fp64 parkedOwnerStrength(
        list fleets,
        list designs,
        int64 planetId,
        int64 ownerId) {
        fp64 total = 0.0
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == ownerId
                and fleet.locationPlanetId == planetId
                and fleet.sitting
                and not fleet.departed
                and not fleet.pendingDeparture
                and fleet.hullCount > 0
                and fleet.designId >= 0
                and fleet.designId < designs.length) {
                Design design = designs[fleet.designId]
                total = total + fleetStrength(fleet, design)
            }
            index = index + 1
        }
        return(total)
    }

    /*
     * Open a planet engagement for an arriving take fleet.
     *
     * Purpose: shared entry when Take decides the rock fights.
     * Large strength gaps short-circuit via battleShortCircuitGap.
     *
     * Parameters:
     *   scenario — battle duration / gap knobs.
     *   engagements — mutable engagement list.
     *   nextId — next engagement id.
     *   rock — defended planet.
     *   fleet — attacking fleet.
     *   atk — attacker strength.
     *   defn — defender strength.
     *   events — tick event log.
     *
     * Returns: updated next engagement id.
     */
    int64 openAtPlanet(
        Scenario scenario,
        list engagements,
        int64 nextId,
        Planet rock,
        Fleet fleet,
        fp64 atk,
        fp64 defn,
        list events) {
        Engagement fight = Engagement(nextId)
        nextId = nextId + 1
        fight.openPlanet(
            rock.id,
            fleet.id,
            fleet.ownerId,
            rock.ownerId,
            atk,
            defn)
        engagements.append(fight)
        events.append(
            TickEvent(
                "combat_open",
                fleet.id,
                rock.id,
                fleet.ownerId,
                nextId - 1))
        return(nextId)
    }

    /*
     * True when the strength gap collapses the fight immediately.
     *
     * Purpose: RULES §12 large-gap may finish in 0/1 tick using
     * scenario.battleShortCircuitGap.
     *
     * Parameters:
     *   scenario — battleShortCircuitGap.
     *   atk — attacker strength.
     *   defn — defender strength.
     *
     * Returns: true when max/min >= gap (or either side is 0).
     */
    bool shortCircuits(Scenario scenario, fp64 atk, fp64 defn) {
        if (atk <= 0.0 or defn <= 0.0) {
            return(true)
        }
        fp64 hi = atk
        fp64 lo = defn
        if (defn > atk) {
            hi = defn
            lo = atk
        }
        if (lo <= 0.0) {
            return(true)
        }
        return(hi / lo >= scenario.battleShortCircuitGap)
    }

    /*
     * Apply one tick of attrition to an open engagement.
     *
     * Purpose: comparative-strength stub — stronger side chips the
     * weaker by a fixed fraction of the gap each tick (D1; D4 will
     * refine per-design screening).
     *
     * Parameters:
     *   scenario — unused knobs reserved for D4 formulas.
     *   fight — open engagement to mutate.
     *
     * Returns: nothing; updates strengthLeft fields.
     */
    void advanceOne(Scenario scenario, Engagement fight) {
        fp64 atk = fight.attackerStrengthLeft
        fp64 defn = fight.defenderStrengthLeft
        if (atk <= 0.0 or defn <= 0.0) {
            return()
        }
        fp64 step = scenario.battleStrengthDurationCoeff
        if (step <= 0.0) {
            step = 1.0
        }
        if (atk >= defn) {
            fp64 hit = defn / (step + 1.0)
            if (hit < 0.25) {
                hit = 0.25
            }
            fight.defenderStrengthLeft = defn - hit
            if (fight.defenderStrengthLeft < 0.0) {
                fight.defenderStrengthLeft = 0.0
            }
        } else {
            fp64 hit = atk / (step + 1.0)
            if (hit < 0.25) {
                hit = 0.25
            }
            fight.attackerStrengthLeft = atk - hit
            if (fight.attackerStrengthLeft < 0.0) {
                fight.attackerStrengthLeft = 0.0
            }
        }
        fight.ticksOpen = fight.ticksOpen + 1
    }

    /*
     * Find an open engagement for a planet, or −1.
     *
     * Purpose: Take joins an existing fight instead of stacking.
     *
     * Parameters:
     *   engagements — engagement list.
     *   planetId — rock id.
     *
     * Returns: index in engagements, or −1.
     */
    int64 findOpenAtPlanet(list engagements, int64 planetId) {
        int64 index = 0
        while (index < engagements.length) {
            Engagement fight = engagements[index]
            if (fight.open and fight.planetId == planetId) {
                return(index)
            }
            index = index + 1
        }
        return(-1)
    }
}
