/*
 * src/lib/combat.cw — shared combat machine (Phase D4).
 *
 * Planet defense and midpoint ambush share strength, screening,
 * and multi-tick advance (RULES §12). Duration follows comparative
 * strength; large gaps short-circuit. Recall into/out of a fight
 * still participates via engagementId on fleets.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial shared combat for take defense (D1 stub).
 *   2026-11-05  Phase D4: screening attrition, refresh strengths,
 *               mark participants, shared advanceTick.
 */

include "design.cw"
include "engagement.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "scenario.cw"
include "screen.cw"

/*
 * Combat computes comparative strength and advances engagements.
 *
 * Entry points: needsFight, fleetStrength, defenderStrength,
 * openAtPlanet, markParticipants, refreshStrengths, advanceTick,
 * shortCircuits, findOpenAtPlanet.
 */
class Combat {
    Screen screen

    /*
     * Construct a combat helper with a Screen submodule.
     *
     * Purpose: keep light-first losses beside strength math.
     *
     * Parameters: none.
     *
     * Returns: Combat instance.
     */
    Combat() {
        screen = Screen()
    }

    /*
     * Per-hull strength contribution for a design.
     *
     * Purpose: delegate to Design.combatStrength (RULES §12).
     *
     * Parameters:
     *   design — hull template.
     *
     * Returns: strength points per hull.
     */
    fp64 hullStrength(Design design) {
        return(design.combatStrength())
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
     * Sum strength of fleets tagged with an engagement id + owner.
     *
     * Purpose: refresh attacker/defender mobile strength each tick
     * so recall into/out still counts under battle rules.
     *
     * Parameters:
     *   fleets — fleet list.
     *   designs — designs.
     *   engagementId — open fight id.
     *   ownerId — side owner.
     *
     * Returns: summed strength of matching engaged fleets.
     */
    fp64 engagedOwnerStrength(
        list fleets,
        list designs,
        int64 engagementId,
        int64 ownerId) {
        fp64 total = 0.0
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.engagementId == engagementId
                and fleet.ownerId == ownerId
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
     * Mark fleets at a planet as participants in an engagement.
     *
     * Purpose: attacker take fleet + parked defenders stay under
     * battle rules through recall (RULES §5.2 / §12).
     *
     * Parameters:
     *   fleets — mutable list.
     *   engagementId — fight id.
     *   planetId — rock.
     *   attackerOwnerId — attacker empire.
     *   defenderOwnerId — defender empire.
     *   attackerFleetId — primary take fleet (always marked).
     *
     * Returns: nothing.
     */
    void markParticipants(
        list fleets,
        int64 engagementId,
        int64 planetId,
        int64 attackerOwnerId,
        int64 defenderOwnerId,
        int64 attackerFleetId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            bool mark = false
            if (fleet.id == attackerFleetId) {
                mark = true
            } else (fleet.locationPlanetId == planetId
                and fleet.sitting
                and fleet.ownerId == defenderOwnerId
                and fleet.hullCount > 0) {
                mark = true
            } else (fleet.locationPlanetId == planetId
                and fleet.ownerId == attackerOwnerId
                and fleet.hullCount > 0
                and (fleet.sitting or fleet.id == attackerFleetId)) {
                mark = true
            }
            if (mark) {
                fleet.engagementId = engagementId
                fleets[index] = fleet
            }
            index = index + 1
        }
    }

    /*
     * Clear engagementId on all fleets for a finished fight.
     *
     * Purpose: free mid-dispatch / recall motion after resolve.
     *
     * Parameters:
     *   fleets — mutable list.
     *   engagementId — closed fight id.
     *
     * Returns: nothing.
     */
    void clearParticipants(list fleets, int64 engagementId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.engagementId == engagementId) {
                fleet.engagementId = -1
                fleets[index] = fleet
            }
            index = index + 1
        }
    }

    /*
     * Join a recalling or arriving fleet into an open fight.
     *
     * Purpose: recall into a fight still under battle rules —
     * reinforcements can reverse a defeat in progress (§5.2).
     *
     * Parameters:
     *   fleets — mutable list.
     *   fleetIndex — index to mark.
     *   engagementId — open fight.
     *
     * Returns: nothing.
     */
    void joinEngagement(
        list fleets,
        int64 fleetIndex,
        int64 engagementId) {
        if (fleetIndex < 0 or fleetIndex >= fleets.length) {
            return()
        }
        Fleet fleet = fleets[fleetIndex]
        fleet.engagementId = engagementId
        fleets[fleetIndex] = fleet
    }

    /*
     * Recompute fight strengths from current participants + rock.
     *
     * Purpose: multi-tick duration tracks live comparative strength
     * after attrition and recall join/leave tagging.
     *
     * Parameters:
     *   scenario — inherent defense.
     *   fight — open engagement (mutated).
     *   rock — defended planet (planet fights only).
     *   fleets — fleets.
     *   designs — designs.
     *
     * Returns: nothing; updates strengthLeft fields.
     */
    void refreshStrengths(
        Scenario scenario,
        Engagement fight,
        Planet rock,
        list fleets,
        list designs) {
        fight.attackerStrengthLeft = engagedOwnerStrength(
            fleets,
            designs,
            fight.id,
            fight.attackerOwnerId)
        fp64 parked = engagedOwnerStrength(
            fleets,
            designs,
            fight.id,
            fight.defenderOwnerId)
        if (fight.planetaryDefenseLeft < 0.0) {
            fight.planetaryDefenseLeft = 0.0
        }
        fight.defenderStrengthLeft = parked + fight.planetaryDefenseLeft
    }

    /*
     * Seed planetaryDefenseLeft from sats + productive inherent.
     *
     * Purpose: non-hull defense decays under attrition instead of
     * refreshing full each tick (RULES §11.2 / §12).
     *
     * Parameters:
     *   scenario — productiveInherentDefense.
     *   rock — defended planet.
     *   fight — engagement to seed.
     *
     * Returns: nothing; sets planetaryDefenseLeft.
     */
    void seedPlanetaryDefense(
        Scenario scenario,
        Planet rock,
        Engagement fight) {
        fp64 layer = 0.0
        if (rock.satelliteDefense > 0.0) {
            layer = layer + rock.satelliteDefense
        }
        if (rock.productive and scenario.productiveInherentDefense > 0.0) {
            layer = layer + scenario.productiveInherentDefense
        }
        fight.planetaryDefenseLeft = layer
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
     * One tick of screened attrition on an open engagement.
     *
     * Purpose: stronger side chips the weaker by a fraction of the
     * weaker strength scaled by battleStrengthDurationCoeff; losses
     * apply per design with screening (RULES §12).
     *
     * Parameters:
     *   scenario — duration coeff.
     *   fight — open engagement.
     *   fleets — mutable fleets (hull losses).
     *   designs — designs.
     *
     * Returns: nothing; mutates fleets and fight.ticksOpen.
     */
    void advanceTick(
        Scenario scenario,
        Engagement fight,
        list fleets,
        list designs) {
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
            fp64 remain = hit
            if (fight.planetaryDefenseLeft > 0.0) {
                if (remain >= fight.planetaryDefenseLeft) {
                    remain = remain - fight.planetaryDefenseLeft
                    fight.planetaryDefenseLeft = 0.0
                } else {
                    fight.planetaryDefenseLeft = (
                        fight.planetaryDefenseLeft - remain)
                    remain = 0.0
                }
            }
            if (remain > 0.0) {
                screen.applyHit(
                    fleets,
                    designs,
                    fight.id,
                    fight.planetId,
                    fight.defenderOwnerId,
                    remain)
            }
        } else {
            fp64 hit = atk / (step + 1.0)
            if (hit < 0.25) {
                hit = 0.25
            }
            screen.applyHit(
                fleets,
                designs,
                fight.id,
                fight.planetId,
                fight.attackerOwnerId,
                hit)
        }
        fight.ticksOpen = fight.ticksOpen + 1
    }

    /*
     * Apply one tick of attrition (strength-only stub alias).
     *
     * Purpose: keep D1 unit callers compiling; prefer advanceTick
     * when fleets are available for screening.
     *
     * Parameters:
     *   scenario — battleStrengthDurationCoeff.
     *   fight — open engagement to mutate.
     *
     * Returns: nothing; updates strengthLeft fields only.
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
