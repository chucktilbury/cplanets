/*
 * src/lib/take.cw — take / occupy / colony populate (Phase D1).
 *
 * RULES §7.6 arrivals and §11: unowned free take; undefended owned
 * non-productive free; productive / satellites / parked fight via
 * Combat; colony required to populate; war fleets stay after take.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial take/occupy/colony for Phase D1.
 *   2026-11-05  Phase D2: clear only take pendingArrivalOrder.
 */

include "combat.cw"
include "design.cw"
include "engagement.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "scenario.cw"

/*
 * Take resolves arriving take orders into occupy or combat.
 *
 * Free takes transfer ownership immediately. Contested takes open
 * or join an Engagement; Combat.advanceAll finishes them later.
 */
class Take {
    Combat combat

    /*
     * Construct a take phase with a shared Combat helper.
     *
     * Purpose: keep planet-defense entry points in one place.
     *
     * Parameters: none.
     *
     * Returns: Take ready for processArrivals / finishResolved.
     */
    Take() {
        combat = Combat()
    }

    /*
     * Handle every fleet that arrived with a take order.
     *
     * Purpose: RULES §7.6 take/occupy and §11 colony gate. Clears
     * pendingArrivalOrder for all fleets after handling.
     *
     * Parameters:
     *   scenario — inherent-defense / battle knobs.
     *   planets — mutable galaxy.
     *   designs — hull templates.
     *   fleets — mutable fleet list.
     *   engagements — mutable open fights.
     *   events — tick event log.
     *   nextEngagementId — id counter.
     *
     * Returns: updated nextEngagementId.
     */
    int64 processArrivals(
        Scenario scenario,
        list planets,
        list designs,
        list fleets,
        list engagements,
        list events,
        int64 nextEngagementId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingArrivalOrder.equals("take")) {
                nextEngagementId = resolveTakeArrival(
                    scenario,
                    planets,
                    designs,
                    fleets,
                    engagements,
                    events,
                    nextEngagementId,
                    index)
                fleet = fleets[index]
                fleet.pendingArrivalOrder = ""
                fleets[index] = fleet
            }
            index = index + 1
        }
        return(nextEngagementId)
    }

    /*
     * Resolve one arriving take fleet at its location.
     *
     * Purpose: free occupy vs open combat vs join open fight.
     *
     * Parameters:
     *   scenario — combat knobs.
     *   planets — galaxy.
     *   designs — designs.
     *   fleets — fleets.
     *   engagements — fights.
     *   events — log.
     *   nextEngagementId — next id.
     *   fleetIndex — index of the arriving fleet.
     *
     * Returns: updated nextEngagementId.
     */
    int64 resolveTakeArrival(
        Scenario scenario,
        list planets,
        list designs,
        list fleets,
        list engagements,
        list events,
        int64 nextEngagementId,
        int64 fleetIndex) {
        Fleet fleet = fleets[fleetIndex]
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= planets.length) {
            return(nextEngagementId)
        }
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            return(nextEngagementId)
        }
        Planet rock = planets[fleet.locationPlanetId]
        Design design = designs[fleet.designId]
        fp64 atk = combat.fleetStrength(fleet, design)
        if (rock.ownerId == fleet.ownerId) {
            # Already a possession: sit/move; colony may still populate.
            applyPopulateIfColony(rock, fleet, design, events)
            planets[fleet.locationPlanetId] = rock
            fleets[fleetIndex] = fleet
            return(nextEngagementId)
        }
        fp64 parked = 0.0
        if (rock.ownerId >= 0) {
            parked = combat.parkedOwnerStrength(
                fleets,
                designs,
                rock.id,
                rock.ownerId)
        }
        if (not combat.needsFight(
            scenario,
            rock,
            fleet.ownerId,
            parked)) {
            applyOccupy(rock, fleet, design, events)
            planets[fleet.locationPlanetId] = rock
            fleets[fleetIndex] = fleet
            return(nextEngagementId)
        }
        fp64 defn = combat.defenderStrength(scenario, rock, parked)
        int64 existing = combat.findOpenAtPlanet(engagements, rock.id)
        if (existing >= 0) {
            Engagement fight = engagements[existing]
            fight.attackerStrengthLeft = fight.attackerStrengthLeft + atk
            engagements[existing] = fight
            events.append(
                TickEvent(
                    "combat_join",
                    fleet.id,
                    rock.id,
                    fleet.ownerId,
                    fight.id))
            return(nextEngagementId)
        }
        nextEngagementId = combat.openAtPlanet(
            scenario,
            engagements,
            nextEngagementId,
            rock,
            fleet,
            atk,
            defn,
            events)
        if (combat.shortCircuits(scenario, atk, defn)) {
            Engagement fight = engagements[engagements.length - 1]
            resolveEngagementOutcome(
                planets,
                designs,
                fleets,
                events,
                fight,
                atk >= defn)
            fight.close()
            engagements[engagements.length - 1] = fight
        }
        return(nextEngagementId)
    }

    /*
     * Occupy a free rock after a take (no fight).
     *
     * Purpose: unowned or undefended non-productive (§11.1 / §11.2).
     * War fleets stay as sitters; colony populates when present.
     *
     * Parameters:
     *   rock — destination planet (mutated).
     *   fleet — arriving take fleet (mutated if colony dies N/A).
     *   design — fleet design.
     *   events — log.
     *
     * Returns: nothing.
     */
    void applyOccupy(
        Planet rock,
        Fleet fleet,
        Design design,
        list events) {
        rock.ownerId = fleet.ownerId
        rock.qualityKnown = true
        events.append(
            TickEvent(
                "take",
                fleet.id,
                rock.id,
                fleet.ownerId,
                0))
        applyPopulateIfColony(rock, fleet, design, events)
    }

    /*
     * Populate when a surviving colony hull is present.
     *
     * Purpose: colony required to populate; dead colony does not
     * (RULES §11.3). Sitting alone never populates.
     *
     * Parameters:
     *   rock — occupied planet.
     *   fleet — fleet that may carry colony hulls.
     *   design — that fleet's design.
     *   events — log.
     *
     * Returns: nothing; may set population / productive.
     */
    void applyPopulateIfColony(
        Planet rock,
        Fleet fleet,
        Design design,
        list events) {
        if (not design.colony) {
            return()
        }
        if (fleet.hullCount <= 0) {
            return()
        }
        rock.population = 1.0
        rock.productive = true
        events.append(
            TickEvent(
                "populate",
                fleet.id,
                rock.id,
                fleet.ownerId,
                fleet.hullCount))
    }

    /*
     * Apply win/loss after an engagement resolves.
     *
     * Purpose: attacker win → occupy + colony gate; defender win →
     * sink attacking hulls. Satellite layer clears on take.
     *
     * Parameters:
     *   planets — galaxy.
     *   designs — designs.
     *   fleets — fleets.
     *   events — log.
     *   fight — resolved engagement.
     *   attackerWins — true when attacker side won.
     *
     * Returns: nothing.
     */
    void resolveEngagementOutcome(
        list planets,
        list designs,
        list fleets,
        list events,
        Engagement fight,
        bool attackerWins) {
        if (fight.planetId < 0 or fight.planetId >= planets.length) {
            return()
        }
        Planet rock = planets[fight.planetId]
        if (attackerWins) {
            int64 fidx = findFleetIndex(fleets, fight.attackerFleetId)
            if (fidx >= 0) {
                Fleet fleet = fleets[fidx]
                Design design = designs[0]
                if (fleet.designId >= 0
                    and fleet.designId < designs.length) {
                    design = designs[fleet.designId]
                }
                applyCombatLosses(fleet, fight.attackerStrengthLeft, design)
                rock.satelliteDefense = 0.0
                applyOccupy(rock, fleet, design, events)
                fleets[fidx] = fleet
            } else {
                rock.ownerId = fight.attackerOwnerId
                rock.qualityKnown = true
                rock.satelliteDefense = 0.0
                events.append(
                    TickEvent(
                        "take",
                        fight.attackerFleetId,
                        rock.id,
                        fight.attackerOwnerId,
                        0))
            }
            clearParkedDefenders(
                fleets,
                designs,
                rock.id,
                fight.defenderOwnerId)
        } else {
            int64 fidx = findFleetIndex(fleets, fight.attackerFleetId)
            if (fidx >= 0) {
                Fleet fleet = fleets[fidx]
                fleet.hullCount = 0
                fleets[fidx] = fleet
            }
            events.append(
                TickEvent(
                    "defend",
                    fight.attackerFleetId,
                    rock.id,
                    fight.defenderOwnerId,
                    0))
        }
        planets[fight.planetId] = rock
    }

    /*
     * Scale hullCount down to match remaining strength.
     *
     * Purpose: D1 attrition stub — survivors stay for colony check.
     *
     * Parameters:
     *   fleet — attacker fleet (mutated).
     *   strengthLeft — remaining attacker strength.
     *   design — hull template for per-hull strength.
     *
     * Returns: nothing.
     */
    void applyCombatLosses(
        Fleet fleet,
        fp64 strengthLeft,
        Design design) {
        fp64 per = combat.hullStrength(design)
        if (per <= 0.0) {
            fleet.hullCount = 0
            return()
        }
        int64 left = int64(strengthLeft / per + 0.0001)
        if (left < 0) {
            left = 0
        }
        if (left > fleet.hullCount) {
            left = fleet.hullCount
        }
        fleet.hullCount = left
    }

    /*
     * Zero hulls of parked defenders after a successful take.
     *
     * Purpose: conqueror clears the rock's defending mobile stock.
     *
     * Parameters:
     *   fleets — fleet list.
     *   designs — unused (signature symmetry).
     *   planetId — rock.
     *   ownerId — former owner.
     *
     * Returns: nothing.
     */
    void clearParkedDefenders(
        list fleets,
        list designs,
        int64 planetId,
        int64 ownerId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == ownerId
                and fleet.locationPlanetId == planetId
                and fleet.sitting) {
                fleet.hullCount = 0
                fleets[index] = fleet
            }
            index = index + 1
        }
    }

    /*
     * Locate a fleet index by id.
     *
     * Purpose: engagement resolution mutates the attacker slot.
     *
     * Parameters:
     *   fleets — fleet list.
     *   fleetId — id to find.
     *
     * Returns: index or −1.
     */
    int64 findFleetIndex(list fleets, int64 fleetId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.id == fleetId) {
                return(index)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Advance open engagements one tick; resolve finished ones.
     *
     * Purpose: RULES §7.7 ongoing combat via shared Combat entry.
     *
     * Parameters:
     *   scenario — attrition knobs.
     *   planets — galaxy.
     *   designs — designs.
     *   fleets — fleets.
     *   engagements — open fights.
     *   events — log.
     *
     * Returns: nothing.
     */
    void advanceEngagements(
        Scenario scenario,
        list planets,
        list designs,
        list fleets,
        list engagements,
        list events) {
        int64 index = 0
        while (index < engagements.length) {
            Engagement fight = engagements[index]
            if (fight.open) {
                if (combat.shortCircuits(
                    scenario,
                    fight.attackerStrengthLeft,
                    fight.defenderStrengthLeft)) {
                    bool win = (
                        fight.attackerStrengthLeft
                        >= fight.defenderStrengthLeft)
                    resolveEngagementOutcome(
                        planets,
                        designs,
                        fleets,
                        events,
                        fight,
                        win)
                    fight.close()
                } else {
                    combat.advanceOne(scenario, fight)
                    if (fight.attackerStrengthLeft <= 0.0
                        or fight.defenderStrengthLeft <= 0.0) {
                        bool win = fight.attackerStrengthLeft > 0.0
                        resolveEngagementOutcome(
                            planets,
                            designs,
                            fleets,
                            events,
                            fight,
                            win)
                        fight.close()
                    }
                }
                engagements[index] = fight
                events.append(
                    TickEvent(
                        "combat_tick",
                        fight.attackerFleetId,
                        fight.planetId,
                        fight.attackerOwnerId,
                        fight.ticksOpen))
            }
            index = index + 1
        }
    }
}
