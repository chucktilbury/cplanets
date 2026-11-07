/*
 * src/lib/take.cw — take / occupy / colony populate (Phase D1/D4).
 *
 * RULES §7.6 arrivals and §11: unowned free take; undefended owned
 * non-productive free; productive / satellites / parked fight via
 * Combat; colony required to populate; war fleets stay after take.
 * D4: multi-tick screened combat, attributed attack, capture-use.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial take/occupy/colony for Phase D1.
 *   2026-11-05  Phase D2: clear only take pendingArrivalOrder.
 *   2026-11-05  Phase D4: participants, screened advance, attribute.
 *   2026-11-07  Wire attack_bump on defender wins (RULES §11.2).
 */

include "combat.cw"
include "confiscate.cw"
include "design.cw"
include "engagement.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "rng.cw"
include "scenario.cw"

/*
 * Take resolves arriving take orders into occupy or combat.
 *
 * Free takes transfer ownership immediately. Contested takes open
 * or join an Engagement; advanceEngagements finishes them later.
 */
class Take {
    Combat combat
    Confiscate confiscate
    int64 nextFleetIdOut

    /*
     * Construct a take phase with Combat and Confiscate helpers.
     *
     * Purpose: keep planet-defense and §9 attribution in one place.
     *
     * Parameters: none.
     *
     * Returns: Take ready for processArrivals / advanceEngagements.
     */
    Take() {
        combat = Combat()
        confiscate = Confiscate()
        nextFleetIdOut = 1
    }

    /*
     * Handle every fleet that arrived with a take order.
     *
     * Purpose: RULES §7.6 take/occupy and §11 colony gate. Clears
     * pendingArrivalOrder for take fleets after handling.
     *
     * Parameters:
     *   scenario — inherent-defense / battle knobs.
     *   planets — mutable galaxy.
     *   players — empire pools (attack bump credits).
     *   designs — hull templates.
     *   fleets — mutable fleet list.
     *   engagements — mutable open fights.
     *   agreements — pacts (closed on attributed take).
     *   arms — confiscation arms.
     *   events — tick event log.
     *   rng — capture-use rolls.
     *   nextEngagementId — id counter.
     *   nextFleetId — intern counter.
     *
     * Returns: nothing; updates next* via out fields on driver —
     *   this method returns a packed pair via mutating lists only;
     *   caller reads engagement id from return value and fleet id
     *   from nextFleetId inout pattern below.
     */
    int64 processArrivals(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list engagements,
        list agreements,
        list arms,
        list events,
        SeededRng rng,
        int64 nextEngagementId,
        int64 nextFleetId) {
        nextFleetIdOut = nextFleetId
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingArrivalOrder.equals("take")) {
                nextEngagementId = resolveTakeArrival(
                    scenario,
                    planets,
                    players,
                    designs,
                    fleets,
                    engagements,
                    agreements,
                    arms,
                    events,
                    rng,
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
     * Purpose: free occupy vs open combat vs join open fight;
     * attributed attack ends agreement + confiscation (§9).
     *
     * Parameters: see processArrivals; fleetIndex selects fleet.
     *
     * Returns: updated nextEngagementId.
     */
    int64 resolveTakeArrival(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list engagements,
        list agreements,
        list arms,
        list events,
        SeededRng rng,
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
            applyPopulateIfColony(rock, fleet, design, events)
            planets[fleet.locationPlanetId] = rock
            fleets[fleetIndex] = fleet
            return(nextEngagementId)
        }
        int64 priorOwner = rock.ownerId
        if (priorOwner >= 0 and priorOwner != fleet.ownerId) {
            confiscate.attributeAttack(
                agreements,
                arms,
                fleet.ownerId,
                priorOwner,
                events)
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
            combat.joinEngagement(fleets, fleetIndex, fight.id)
            combat.refreshStrengths(
                scenario,
                fight,
                rock,
                fleets,
                designs)
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
        Engagement fight = engagements[engagements.length - 1]
        combat.markParticipants(
            fleets,
            fight.id,
            rock.id,
            fleet.ownerId,
            rock.ownerId,
            fleet.id)
        combat.seedPlanetaryDefense(scenario, rock, fight)
        combat.refreshStrengths(
            scenario,
            fight,
            rock,
            fleets,
            designs)
        if (combat.shortCircuits(
            scenario,
            fight.attackerStrengthLeft,
            fight.defenderStrengthLeft)) {
            bool win = (
                fight.attackerStrengthLeft
                >= fight.defenderStrengthLeft)
            nextFleetIdOut = resolveEngagementOutcome(
                scenario,
                planets,
                players,
                designs,
                fleets,
                events,
                rng,
                fight,
                win,
                nextFleetIdOut)
            combat.clearParticipants(fleets, fight.id)
            fight.close()
        }
        engagements[engagements.length - 1] = fight
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
     *   fleet — arriving take fleet.
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
     * Purpose: attacker win → occupy + capture-use on defenders;
     * defender win → sink attacking hulls and credit attack_bump
     * wealth/resources from attacker size (RULES §11.2).
     *
     * Parameters:
     *   scenario — capture-use chance + attackBump.
     *   planets / players / designs / fleets / events / rng /
     *   fight / win.
     *   nextFleetId — intern counter.
     *
     * Returns: updated nextFleetId.
     */
    int64 resolveEngagementOutcome(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list events,
        SeededRng rng,
        Engagement fight,
        bool attackerWins,
        int64 nextFleetId) {
        if (fight.planetId < 0 or fight.planetId >= planets.length) {
            return(nextFleetId)
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
            nextFleetId = captureOrClearDefenders(
                scenario,
                fleets,
                designs,
                events,
                rng,
                rock.id,
                fight.defenderOwnerId,
                fight.attackerOwnerId,
                nextFleetId)
        } else {
            fp64 atkSize = attackerEngagedSize(
                fleets, designs, fight)
            creditAttackBump(
                scenario, players, fight.defenderOwnerId, atkSize)
            int64 fidx = findFleetIndex(fleets, fight.attackerFleetId)
            if (fidx >= 0) {
                Fleet fleet = fleets[fidx]
                fleet.hullCount = 0
                fleets[fidx] = fleet
            }
            zeroOwnerEngaged(
                fleets,
                fight.id,
                fight.attackerOwnerId)
            events.append(
                TickEvent(
                    "defend",
                    fight.attackerFleetId,
                    rock.id,
                    fight.defenderOwnerId,
                    0))
        }
        planets[fight.planetId] = rock
        return(nextFleetId)
    }

    /*
     * Sum design.size * hulls for attacker fleets in a fight.
     *
     * Purpose: attack_bump basis before hulls are zeroed.
     *
     * Parameters:
     *   fleets — fleet list.
     *   designs — design list.
     *   fight — engagement being resolved.
     *
     * Returns: total attacker size points (>= 0).
     */
    fp64 attackerEngagedSize(
        list fleets,
        list designs,
        Engagement fight) {
        fp64 total = 0.0
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == fight.attackerOwnerId
                and fleet.engagementId == fight.id
                and fleet.hullCount > 0
                and fleet.designId >= 0
                and fleet.designId < designs.length) {
                Design design = designs[fleet.designId]
                total = total + design.size * fp64(fleet.hullCount)
            }
            index = index + 1
        }
        return(total)
    }

    /*
     * Credit defender wealth/resources from attack_bump.
     *
     * Purpose: RULES §11.2 — defender win yields attack bump from
     * attacker size. Magnitude = size * attackBump (placeholder).
     *
     * Parameters:
     *   scenario — attackBump.
     *   players — empire pools.
     *   defenderId — seat receiving the bump.
     *   attackerSize — summed design.size * hulls.
     *
     * Returns: nothing.
     */
    void creditAttackBump(
        Scenario scenario,
        list players,
        int64 defenderId,
        fp64 attackerSize) {
        if (defenderId < 0 or defenderId >= players.length) {
            return()
        }
        if (attackerSize <= 0.0) {
            return()
        }
        fp64 credit = attackerSize * scenario.attackBump
        Player seat = players[defenderId]
        seat.wealth = seat.wealth + credit
        seat.resources = seat.resources + credit
        players[defenderId] = seat
    }

    /*
     * Capture-use roll on parked defenders, else destroy.
     *
     * Purpose: RULES §5.3 captured hulls; conqueror clears the rock.
     *
     * Parameters: scenario, fleets, designs, events, rng, planet,
     *   defender, victor, nextFleetId.
     *
     * Returns: updated nextFleetId.
     */
    int64 captureOrClearDefenders(
        Scenario scenario,
        list fleets,
        list designs,
        list events,
        SeededRng rng,
        int64 planetId,
        int64 defenderId,
        int64 victorId,
        int64 nextFleetId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == defenderId
                and fleet.locationPlanetId == planetId
                and fleet.hullCount > 0) {
                int64 hulls = fleet.hullCount
                int64 designId = fleet.designId
                fleet.hullCount = 0
                fleets[index] = fleet
                if (confiscate.rollCaptureUse(scenario, rng)) {
                    nextFleetId = confiscate.internHulls(
                        fleets,
                        victorId,
                        planetId,
                        designId,
                        hulls,
                        events,
                        nextFleetId)
                } else {
                    events.append(
                        TickEvent(
                            "capture_destroy",
                            fleet.id,
                            planetId,
                            victorId,
                            hulls))
                }
            }
            index = index + 1
        }
        return(nextFleetId)
    }

    /*
     * Zero hulls for one owner still tagged on an engagement.
     *
     * Purpose: wipe attacker participants after a defend win.
     *
     * Parameters:
     *   fleets — list.
     *   engagementId — fight.
     *   ownerId — side to wipe.
     *
     * Returns: nothing.
     */
    void zeroOwnerEngaged(
        list fleets,
        int64 engagementId,
        int64 ownerId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.engagementId == engagementId
                and fleet.ownerId == ownerId) {
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
     * Pull sitting same-owner fleets at a rock into an open fight.
     *
     * Purpose: recall into a fight — reinforcements at the sender
     * under attack join and can reverse a defeat (RULES §5.2).
     *
     * Parameters:
     *   fleets — mutable list.
     *   fight — open planet engagement.
     *
     * Returns: nothing.
     */
    void absorbReinforcements(list fleets, Engagement fight) {
        if (fight.planetId < 0) {
            return()
        }
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.engagementId < 0
                and fleet.locationPlanetId == fight.planetId
                and fleet.sitting
                and fleet.hullCount > 0
                and (fleet.ownerId == fight.attackerOwnerId
                    or fleet.ownerId == fight.defenderOwnerId)) {
                fleet.engagementId = fight.id
                fleets[index] = fleet
            }
            index = index + 1
        }
    }

    /*
     * Advance open engagements one tick; resolve finished ones.
     *
     * Purpose: RULES §7.7 ongoing combat via shared Combat entry.
     *
     * Parameters:
     *   scenario — attrition knobs.
     *   planets / players / designs / fleets / engagements /
     *   events / rng.
     *   nextFleetId — intern counter.
     *
     * Returns: updated nextFleetId.
     */
    int64 advanceEngagements(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list engagements,
        list events,
        SeededRng rng,
        int64 nextFleetId) {
        nextFleetIdOut = nextFleetId
        int64 index = 0
        while (index < engagements.length) {
            Engagement fight = engagements[index]
            if (fight.open and fight.planetId >= 0
                and fight.planetId < planets.length) {
                Planet rock = planets[fight.planetId]
                absorbReinforcements(fleets, fight)
                combat.refreshStrengths(
                    scenario,
                    fight,
                    rock,
                    fleets,
                    designs)
                if (combat.shortCircuits(
                    scenario,
                    fight.attackerStrengthLeft,
                    fight.defenderStrengthLeft)) {
                    bool win = (
                        fight.attackerStrengthLeft
                        >= fight.defenderStrengthLeft)
                    nextFleetIdOut = resolveEngagementOutcome(
                        scenario,
                        planets,
                        players,
                        designs,
                        fleets,
                        events,
                        rng,
                        fight,
                        win,
                        nextFleetIdOut)
                    combat.clearParticipants(fleets, fight.id)
                    fight.close()
                } else {
                    combat.advanceTick(
                        scenario,
                        fight,
                        fleets,
                        designs)
                    combat.refreshStrengths(
                        scenario,
                        fight,
                        rock,
                        fleets,
                        designs)
                    if (fight.attackerStrengthLeft <= 0.0
                        or fight.defenderStrengthLeft <= 0.0) {
                        bool win = fight.attackerStrengthLeft > 0.0
                        nextFleetIdOut = resolveEngagementOutcome(
                            scenario,
                            planets,
                            players,
                            designs,
                            fleets,
                            events,
                            rng,
                            fight,
                            win,
                            nextFleetIdOut)
                        combat.clearParticipants(fleets, fight.id)
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
        return(nextFleetIdOut)
    }
}
