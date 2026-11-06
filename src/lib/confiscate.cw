/*
 * src/lib/confiscate.cw — attributed attack + confiscation (D4).
 *
 * RULES §9: attributed attack ends the player–player agreement and
 * arms confiscation of ships arriving from the attacker at the
 * victim's remaining worlds. Capture-use chance decides intern vs
 * destroy (RULES §5.3). Take on a planet they own is attributed.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial attributed-attack confiscation helpers.
 */

include "agreement.cw"
include "design.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "rng.cw"
include "scenario.cw"

/*
 * ConfiscationArm is one victim←attacker confiscation grant.
 *
 * Armed when an attributed attack happens. Arrivals from attacker
 * at victim-owned worlds are seized until the game ends (v1).
 */
class ConfiscationArm {
    int64 victimId
    int64 attackerId
    bool armed

    /*
     * Construct an armed confiscation pair.
     *
     * Purpose: record RULES §9 grant after attributed attack.
     *
     * Parameters:
     *   victim — empire whose worlds confiscate.
     *   attacker — empire whose arriving ships are seized.
     *
     * Returns: ConfiscationArm with armed true.
     */
    ConfiscationArm(int64 victim, int64 attacker) {
        victimId = victim
        attackerId = attacker
        armed = true
    }
}

/*
 * Confiscate closes agreements and seizes inbound attacker fleets.
 *
 * Also rolls capture-use when interning seized or combat-captured
 * hulls (RULES §5.3 / §9).
 */
class Confiscate {
    /*
     * Construct a confiscation helper.
     *
     * Purpose: match other tick-phase objects.
     *
     * Parameters: none.
     *
     * Returns: Confiscate instance.
     */
    Confiscate() {
    }

    /*
     * Close any live pact between two empires.
     *
     * Purpose: attributed attack ends agreement (RULES §9).
     *
     * Parameters:
     *   agreements — mutable pact list.
     *   a / b — empire ids.
     *   events — tick log.
     *
     * Returns: true when a pact was closed.
     */
    bool closePactBetween(
        list agreements,
        int64 a,
        int64 b,
        list events) {
        bool closed = false
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.isLive()
                and pact.involves(a)
                and pact.involves(b)) {
                pact.close()
                agreements[index] = pact
                events.append(
                    TickEvent(
                        "agreement_closed",
                        -1,
                        -1,
                        a,
                        pact.id))
                closed = true
            }
            index = index + 1
        }
        return(closed)
    }

    /*
     * Arm confiscation for victim against attacker if missing.
     *
     * Purpose: ships arriving from attacker at victim worlds are
     * seized (RULES §9).
     *
     * Parameters:
     *   arms — mutable ConfiscationArm list.
     *   victimId — victim empire.
     *   attackerId — attacker empire.
     *   events — log.
     *
     * Returns: nothing.
     */
    void arm(
        list arms,
        int64 victimId,
        int64 attackerId,
        list events) {
        if (victimId < 0 or attackerId < 0 or victimId == attackerId) {
            return()
        }
        int64 index = 0
        while (index < arms.length) {
            ConfiscationArm cur = arms[index]
            if (cur.armed
                and cur.victimId == victimId
                and cur.attackerId == attackerId) {
                return()
            }
            index = index + 1
        }
        arms.append(ConfiscationArm(victimId, attackerId))
        events.append(
            TickEvent(
                "confiscation_armed",
                -1,
                -1,
                victimId,
                attackerId))
    }

    /*
     * Attribute an attack: close pact + arm confiscation.
     *
     * Purpose: take on a planet they own is attributed (§9).
     *
     * Parameters:
     *   agreements — pacts.
     *   arms — confiscation arms.
     *   attackerId — attacking empire.
     *   victimId — defending / former owner.
     *   events — log.
     *
     * Returns: nothing.
     */
    void attributeAttack(
        list agreements,
        list arms,
        int64 attackerId,
        int64 victimId,
        list events) {
        closePactBetween(agreements, attackerId, victimId, events)
        arm(arms, victimId, attackerId, events)
    }

    /*
     * True when victim may confiscate this attacker's arrivals.
     *
     * Purpose: gate seize on arrival.
     *
     * Parameters:
     *   arms — arm list.
     *   victimId — planet owner.
     *   attackerId — arriving fleet owner.
     *
     * Returns: true when an armed pair matches.
     */
    bool isArmed(list arms, int64 victimId, int64 attackerId) {
        int64 index = 0
        while (index < arms.length) {
            ConfiscationArm cur = arms[index]
            if (cur.armed
                and cur.victimId == victimId
                and cur.attackerId == attackerId) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Roll whether captured hulls can be used by the victor.
     *
     * Purpose: setup captureUseChance; else destroy (RULES §5.3).
     *
     * Parameters:
     *   scenario — captureUseChance.
     *   rng — seeded stream.
     *
     * Returns: true when hulls are interned instead of destroyed.
     */
    bool rollCaptureUse(Scenario scenario, SeededRng rng) {
        fp64 chance = scenario.captureUseChance
        if (chance <= 0.0) {
            return(false)
        }
        if (chance >= 1.0) {
            return(true)
        }
        return(rng.nextFp01() < chance)
    }

    /*
     * Seize an arriving fleet at a victim world if armed.
     *
     * Purpose: confiscate hulls + contents; capture-use or destroy.
     * Does not bounce or trade (RULES §9).
     *
     * Parameters:
     *   scenario — capture-use chance.
     *   arms — arm list.
     *   planets — galaxy.
     *   players — seats (unused; signature for callers).
     *   designs — designs.
     *   fleets — mutable fleets.
     *   events — log.
     *   rng — capture-use rolls.
     *   fleetIndex — arriving fleet index.
     *   nextFleetId — counter for interned sit fleet.
     *
     * Returns: updated nextFleetId.
     */
    int64 maybeSeizeArrival(
        Scenario scenario,
        list arms,
        list planets,
        list players,
        list designs,
        list fleets,
        list events,
        SeededRng rng,
        int64 fleetIndex,
        int64 nextFleetId) {
        if (fleetIndex < 0 or fleetIndex >= fleets.length) {
            return(nextFleetId)
        }
        Fleet fleet = fleets[fleetIndex]
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= planets.length) {
            return(nextFleetId)
        }
        Planet rock = planets[fleet.locationPlanetId]
        if (rock.ownerId < 0 or rock.ownerId == fleet.ownerId) {
            return(nextFleetId)
        }
        if (not isArmed(arms, rock.ownerId, fleet.ownerId)) {
            return(nextFleetId)
        }
        int64 victim = rock.ownerId
        int64 hulls = fleet.hullCount
        int64 designId = fleet.designId
        fp64 wealth = fleet.cargoWealth + fleet.lootWealth
        fp64 resources = fleet.cargoResources + fleet.lootResources
        if (victim >= 0 and victim < players.length) {
            Player seat = players[victim]
            seat.wealth = seat.wealth + wealth
            seat.resources = seat.resources + resources
            players[victim] = seat
        }
        fleet.hullCount = 0
        fleet.escortHullCount = 0
        fleet.cargoWealth = 0.0
        fleet.cargoResources = 0.0
        fleet.lootWealth = 0.0
        fleet.lootResources = 0.0
        fleet.pendingArrivalOrder = ""
        fleet.becomeSitting()
        fleets[fleetIndex] = fleet
        events.append(
            TickEvent(
                "confiscate",
                fleet.id,
                rock.id,
                victim,
                hulls))
        if (hulls > 0 and rollCaptureUse(scenario, rng)) {
            nextFleetId = internHulls(
                fleets,
                victim,
                rock.id,
                designId,
                hulls,
                events,
                nextFleetId)
        } else {
            events.append(
                TickEvent(
                    "capture_destroy",
                    fleet.id,
                    rock.id,
                    victim,
                    hulls))
        }
        return(nextFleetId)
    }

    /*
     * Intern captured hulls as a sitting fleet for the victor.
     *
     * Purpose: usable captures are interned of that design, not a
     * free new development (RULES §5.3).
     *
     * Parameters:
     *   fleets — mutable list.
     *   ownerId — victor.
     *   planetId — intern location.
     *   designId — captured design.
     *   hulls — count.
     *   events — log.
     *   nextFleetId — id counter.
     *
     * Returns: updated nextFleetId.
     */
    int64 internHulls(
        list fleets,
        int64 ownerId,
        int64 planetId,
        int64 designId,
        int64 hulls,
        list events,
        int64 nextFleetId) {
        if (hulls <= 0) {
            return(nextFleetId)
        }
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == ownerId
                and fleet.locationPlanetId == planetId
                and fleet.designId == designId
                and fleet.sitting
                and not fleet.pendingDeparture
                and not fleet.departed) {
                fleet.hullCount = fleet.hullCount + hulls
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "capture_use",
                        fleet.id,
                        planetId,
                        ownerId,
                        hulls))
                return(nextFleetId)
            }
            index = index + 1
        }
        Fleet born = Fleet(
            nextFleetId,
            ownerId,
            planetId,
            designId,
            hulls)
        nextFleetId = nextFleetId + 1
        fleets.append(born)
        events.append(
            TickEvent(
                "capture_use",
                born.id,
                planetId,
                ownerId,
                hulls))
        return(nextFleetId)
    }

    /*
     * Process sitting arrivals for confiscation arms.
     *
     * Purpose: after Motion lands fleets, seize armed arrivals
     * before trade/take exchange (RULES §7.6 / §9).
     *
     * Parameters: scenario, arms, planets, players, designs,
     *   fleets, events, rng, nextFleetId.
     *
     * Returns: updated nextFleetId.
     */
    int64 processArrivals(
        Scenario scenario,
        list arms,
        list planets,
        list players,
        list designs,
        list fleets,
        list events,
        SeededRng rng,
        int64 nextFleetId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.sitting
                and not fleet.pendingDeparture
                and fleet.hullCount > 0
                and not fleet.pendingArrivalOrder.equals("")) {
                nextFleetId = maybeSeizeArrival(
                    scenario,
                    arms,
                    planets,
                    players,
                    designs,
                    fleets,
                    events,
                    rng,
                    index,
                    nextFleetId)
            }
            index = index + 1
        }
        return(nextFleetId)
    }
}
