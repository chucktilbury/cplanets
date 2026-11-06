/*
 * src/lib/midpoint.cw — midpoint ambush phase (Phase D3).
 *
 * RULES §7.5 / §6 / §10: promote pirates after half hop ETA; two
 * pirates on one edge war (passers live); pirate vs passer loads
 * loot and forced-recalls; identify rolls (§9); idle timeout
 * forced recall (§7.8). Loot credits on return are handled in
 * Motion after land.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial midpoint ambush / pirate idle phase.
 */

include "agreement.cw"
include "combat.cw"
include "design.cw"
include "event.cw"
include "fleet.cw"
include "identify.cw"
include "player.cw"
include "rng.cw"
include "scenario.cw"
include "travel.cw"

/*
 * Midpoint resolves ambush in-position fights and idle recalls.
 *
 * Instant comparative-strength resolution (short-circuit style)
 * covers D3 fn cases; multi-tick midpoint engagements stay D4.
 */
class Midpoint {
    Combat combat
    Identify identify
    Travel travel

    /*
     * Construct midpoint helpers.
     *
     * Purpose: share combat strength and identify rolls.
     *
     * Parameters: none.
     *
     * Returns: Midpoint ready for run / idleTimeout.
     */
    Midpoint() {
        combat = Combat()
        identify = Identify()
        travel = Travel()
    }

    /*
     * Half of a hop ETA in ticks (integer division).
     *
     * Purpose: RULES §6 example ETA 10 ⇒ 5; no invented ceil/floor.
     *
     * Parameters:
     *   fullEta — full A→B hop ETA.
     *
     * Returns: fullEta / 2 (>= 0).
     */
    int64 halfEta(int64 fullEta) {
        if (fullEta < 0) {
            return(0)
        }
        return(fullEta / 2)
    }

    /*
     * Run §7.5 midpoint: promote, two-pirate wars, pirate vs passer.
     *
     * Purpose: fire ambush only when pirates are in position.
     *
     * Parameters:
     *   scenario — attrition / leftover / identify knobs.
     *   players — empire pools and roles.
     *   designs — hull templates.
     *   fleets — mutable fleet list.
     *   agreements — pacts (closed on attributed ambush).
     *   events — tick log.
     *   rng — seeded identify rolls.
     *
     * Returns: nothing.
     */
    void run(
        Scenario scenario,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        SeededRng rng) {
        promoteInPosition(scenario, fleets, events)
        resolveTwoPirateWars(
            scenario,
            players,
            designs,
            fleets,
            events)
        resolvePiratePassers(
            scenario,
            players,
            designs,
            fleets,
            agreements,
            events,
            rng)
    }

    /*
     * Promote ambush fleets that finished the half-hop approach.
     *
     * Purpose: eta was set to half on depart; eta<=0 means in
     * position (RULES §6). Do not land at the far planet.
     *
     * Parameters:
     *   scenario — pirateIdleTicks.
     *   fleets — mutable list.
     *   events — log.
     *
     * Returns: nothing.
     */
    void promoteInPosition(
        Scenario scenario,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.departed
                and not fleet.ambushInPosition
                and not fleet.stranded
                and fleet.order.equals("ambush")
                and fleet.eta <= 0) {
                fleet.enterAmbushPosition(scenario.pirateIdleTicks)
                fleets[index] = fleet
                events.append(
                    TickEvent(
                        "ambush_ready",
                        fleet.id,
                        fleet.edgeLo(),
                        fleet.ownerId,
                        fleet.ambushIdleLeft))
            }
            index = index + 1
        }
    }

    /*
     * True when a departed non-ambush fleet is at the hop midpoint.
     *
     * Purpose: passer meeting condition — ticksTraveled == half
     * outbound ETA; skip half==0 odd-ETA edge (open in RULES §17).
     *
     * Parameters:
     *   fleet — in-flight fleet.
     *
     * Returns: true when crossing the midpoint this phase.
     */
    bool passerAtMidpoint(Fleet fleet) {
        if (not fleet.departed or fleet.ambushInPosition) {
            return(false)
        }
        if (fleet.stranded or fleet.order.equals("ambush")) {
            return(false)
        }
        if (fleet.order.equals("recall")) {
            return(false)
        }
        int64 half = halfEta(fleet.outboundEta)
        if (half < 1) {
            return(false)
        }
        return(fleet.ticksTraveled == half)
    }

    /*
     * Fleet combat strength including escorts.
     *
     * Purpose: midpoint fights count escort hulls.
     *
     * Parameters:
     *   fleet — fleet mix.
     *   designs — templates.
     *
     * Returns: comparative strength (>= 0).
     */
    fp64 strengthOf(Fleet fleet, list designs) {
        fp64 total = 0.0
        if (fleet.designId >= 0 and fleet.designId < designs.length) {
            Design design = designs[fleet.designId]
            total = total + combat.fleetStrength(fleet, design)
        }
        if (fleet.escortDesignId >= 0
            and fleet.escortDesignId < designs.length
            and fleet.escortHullCount > 0) {
            Design escort = designs[fleet.escortDesignId]
            fp64 per = combat.hullStrength(escort)
            fp64 escortStr = fp64(fleet.escortHullCount) * per
            total = total + escortStr
        }
        return(total)
    }

    /*
     * Apply forced recall toward sender (immediate retarget).
     *
     * Purpose: RULES §10 after robbery / two-pirate win / idle.
     *
     * Parameters:
     *   scenario — teleport mapping.
     *   players — tech for return ETA.
     *   fleet — mutable fleet (returned via list store by caller).
     *
     * Returns: updated Fleet headed home.
     */
    Fleet forceRecall(
        Scenario scenario,
        list players,
        Fleet fleet) {
        int64 back = 0
        if (fleet.ownerId >= 0 and fleet.ownerId < players.length) {
            Player seat = players[fleet.ownerId]
            back = travel.recallEta(
                scenario,
                seat,
                fleet.ticksTraveled)
        }
        fleet.ambushInPosition = false
        fleet.ambushIdleLeft = 0
        fleet.destPlanetId = fleet.senderPlanetId
        fleet.eta = back
        fleet.outboundEta = back
        fleet.ticksTraveled = 0
        fleet.order = "recall"
        fleet.recallRequested = false
        fleet.departed = true
        fleet.pendingDeparture = false
        fleet.sitting = false
        return(fleet)
    }

    /*
     * Shrink hulls by a leftover / attrition fraction.
     *
     * Purpose: two-pirate leftover and post-robbery attrition
     * (scenario pirateLeftover / pirateAttrition).
     *
     * Parameters:
     *   fleet — mutable fleet.
     *   keepFraction — fraction of hulls to keep in (0, 1].
     *
     * Returns: updated Fleet.
     */
    Fleet shrinkHulls(Fleet fleet, fp64 keepFraction) {
        fp64 frac = keepFraction
        if (frac < 0.0) {
            frac = 0.0
        }
        if (frac > 1.0) {
            frac = 1.0
        }
        int64 kept = int64(fp64(fleet.hullCount) * frac + 0.999)
        if (kept < 1 and fleet.hullCount > 0 and frac > 0.0) {
            kept = 1
        }
        if (frac <= 0.0) {
            kept = 0
        }
        fleet.hullCount = kept
        if (fleet.escortHullCount > 0) {
            int64 ek = int64(fp64(fleet.escortHullCount) * frac + 0.999)
            if (ek < 1 and fleet.escortHullCount > 0 and frac > 0.0) {
                ek = 1
            }
            if (frac <= 0.0) {
                ek = 0
            }
            fleet.escortHullCount = ek
        }
        return(fleet)
    }

    /*
     * Destroy a fleet in place (zero hulls, clear transit).
     *
     * Purpose: loser of midpoint fight.
     *
     * Parameters:
     *   fleet — mutable fleet.
     *
     * Returns: updated Fleet.
     */
    Fleet wipeFleet(Fleet fleet) {
        fleet.hullCount = 0
        fleet.escortHullCount = 0
        fleet.cargoWealth = 0.0
        fleet.cargoResources = 0.0
        fleet.lootWealth = 0.0
        fleet.lootResources = 0.0
        fleet.ambushInPosition = false
        fleet.ambushIdleLeft = 0
        fleet.departed = false
        fleet.pendingDeparture = false
        fleet.sitting = true
        fleet.order = "sit"
        fleet.eta = 0
        return(fleet)
    }

    /*
     * War every pair of in-position pirates that share an edge.
     *
     * Purpose: RULES §10 — two pirates war; passers unharmed;
     * winner recalls with almost nothing (pirateLeftover).
     *
     * Parameters:
     *   scenario — leftover knob.
     *   designs — strength.
     *   fleets — mutable list.
     *   events — log.
     *
     * Returns: nothing.
     */
    void resolveTwoPirateWars(
        Scenario scenario,
        list players,
        list designs,
        list fleets,
        list events) {
        int64 i = 0
        while (i < fleets.length) {
            Fleet a = fleets[i]
            if (a.ambushInPosition and a.hullCount > 0) {
                int64 j = i + 1
                while (j < fleets.length) {
                    Fleet b = fleets[j]
                    if (b.ambushInPosition
                        and b.hullCount > 0
                        and a.edgeLo() == b.edgeLo()
                        and a.edgeHi() == b.edgeHi()
                        and a.ownerId != b.ownerId) {
                        fightPirates(
                            scenario,
                            players,
                            designs,
                            fleets,
                            events,
                            i,
                            j)
                        a = fleets[i]
                        if (not a.ambushInPosition or a.hullCount <= 0) {
                            j = fleets.length
                        }
                    }
                    j = j + 1
                }
            }
            i = i + 1
        }
    }

    /*
     * Resolve one two-pirate midpoint fight.
     *
     * Purpose: stronger wins; leftover hulls; forced recall; no
     * passer involvement.
     *
     * Parameters:
     *   scenario — leftover / teleport.
     *   players — return ETA tech.
     *   designs — templates.
     *   fleets — list.
     *   events — log.
     *   indexA / indexB — fleet indices.
     *
     * Returns: nothing.
     */
    void fightPirates(
        Scenario scenario,
        list players,
        list designs,
        list fleets,
        list events,
        int64 indexA,
        int64 indexB) {
        Fleet a = fleets[indexA]
        Fleet b = fleets[indexB]
        fp64 sa = strengthOf(a, designs)
        fp64 sb = strengthOf(b, designs)
        int64 winIdx = indexA
        int64 loseIdx = indexB
        if (sb > sa) {
            winIdx = indexB
            loseIdx = indexA
        }
        Fleet loser = wipeFleet(fleets[loseIdx])
        fleets[loseIdx] = loser
        Fleet winner = fleets[winIdx]
        int64 edge = winner.edgeLo()
        winner = shrinkHulls(winner, scenario.pirateLeftover)
        winner.lootWealth = 0.0
        winner.lootResources = 0.0
        winner.cargoWealth = 0.0
        winner.cargoResources = 0.0
        winner = forceRecall(scenario, players, winner)
        fleets[winIdx] = winner
        events.append(
            TickEvent(
                "pirate_war",
                winner.id,
                edge,
                winner.ownerId,
                loser.id))
        events.append(
            TickEvent(
                "recall",
                winner.id,
                winner.senderPlanetId,
                winner.ownerId,
                winner.eta))
    }

    /*
     * Ambush each passer that meets a single in-position pirate.
     *
     * Purpose: RULES §10 robbery; skip edges with 2+ pirates left
     * in position (they already warred or still contested).
     *
     * Parameters: scenario, players, designs, fleets, agreements,
     *   events, rng — as in run().
     *
     * Returns: nothing.
     */
    void resolvePiratePassers(
        Scenario scenario,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        SeededRng rng) {
        int64 p = 0
        while (p < fleets.length) {
            Fleet passer = fleets[p]
            if (passerAtMidpoint(passer) and passer.hullCount > 0) {
                int64 lo = passer.edgeLo()
                int64 hi = passer.edgeHi()
                int64 pirateIdx = findSolePirate(fleets, lo, hi)
                if (pirateIdx >= 0) {
                    ambushPasser(
                        scenario,
                        players,
                        designs,
                        fleets,
                        agreements,
                        events,
                        rng,
                        pirateIdx,
                        p)
                }
            }
            p = p + 1
        }
    }

    /*
     * Find the only in-position pirate on an edge, or -1.
     *
     * Purpose: two-pirate edges do not rob passers.
     *
     * Parameters:
     *   fleets — list.
     *   lo / hi — edge endpoints.
     *
     * Returns: pirate index, or -1 if none or more than one.
     */
    int64 findSolePirate(list fleets, int64 lo, int64 hi) {
        int64 found = -1
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ambushInPosition
                and fleet.hullCount > 0
                and fleet.edgeLo() == lo
                and fleet.edgeHi() == hi) {
                if (found >= 0) {
                    return(-1)
                }
                found = index
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Resolve pirate vs passer at the midpoint.
     *
     * Purpose: pirate win loads 100% cargo as loot, attrition,
     * forced recall, identify rolls; pirate loss transfers loot
     * to non-pirate winner (RULES §10 / §9).
     *
     * Parameters: indices into fleets plus shared tick args.
     *
     * Returns: nothing.
     */
    void ambushPasser(
        Scenario scenario,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        SeededRng rng,
        int64 pirateIdx,
        int64 passerIdx) {
        Fleet pirate = fleets[pirateIdx]
        Fleet passer = fleets[passerIdx]
        fp64 ps = strengthOf(pirate, designs)
        fp64 vs = strengthOf(passer, designs)
        events.append(
            TickEvent(
                "ambush",
                pirate.id,
                pirate.edgeLo(),
                pirate.ownerId,
                passer.id))
        int64 pirateOwner = pirate.ownerId
        int64 passerOwner = passer.ownerId
        if (ps >= vs) {
            fp64 lootW = pirate.lootWealth + passer.cargoWealth
            fp64 lootR = pirate.lootResources + passer.cargoResources
            pirate.lootWealth = lootW
            pirate.lootResources = lootR
            passer.cargoWealth = 0.0
            passer.cargoResources = 0.0
            pirate = shrinkHulls(
                pirate,
                1.0 - scenario.pirateAttrition)
            pirate = forceRecall(scenario, players, pirate)
            fleets[pirateIdx] = pirate
            passer = wipeFleet(passer)
            fleets[passerIdx] = passer
            events.append(
                TickEvent(
                    "ambush_win",
                    pirate.id,
                    pirate.senderPlanetId,
                    pirate.ownerId,
                    passer.id))
            events.append(
                TickEvent(
                    "recall",
                    pirate.id,
                    pirate.senderPlanetId,
                    pirate.ownerId,
                    pirate.eta))
            applyIdentify(
                scenario,
                players,
                agreements,
                events,
                rng,
                pirateOwner,
                passerOwner)
        } else {
            # Non-pirate winner takes any loot the pirate carried.
            fp64 takeW = pirate.lootWealth + pirate.cargoWealth
            fp64 takeR = pirate.lootResources + pirate.cargoResources
            passer.lootWealth = passer.lootWealth + takeW
            passer.lootResources = passer.lootResources + takeR
            pirate.lootWealth = 0.0
            pirate.lootResources = 0.0
            pirate.cargoWealth = 0.0
            pirate.cargoResources = 0.0
            pirate = wipeFleet(pirate)
            fleets[pirateIdx] = pirate
            fleets[passerIdx] = passer
            events.append(
                TickEvent(
                    "ambush_lose",
                    pirate.id,
                    passer.edgeLo(),
                    passer.ownerId,
                    passer.id))
            applyIdentify(
                scenario,
                players,
                agreements,
                events,
                rng,
                pirateOwner,
                passerOwner)
        }
    }

    /*
     * Roll identify for both sides; close pact on defender hit.
     *
     * Purpose: RULES §9 asymmetry + victim-only defender audience
     * (event playerId = victim). Attribution ends agreement.
     *
     * Parameters:
     *   attackerId / victimId — empire seats.
     *   plus scenario, players, agreements, events, rng.
     *
     * Returns: nothing.
     */
    void applyIdentify(
        Scenario scenario,
        list players,
        list agreements,
        list events,
        SeededRng rng,
        int64 attackerId,
        int64 victimId) {
        if (attackerId < 0
            or attackerId >= players.length
            or victimId < 0
            or victimId >= players.length) {
            return()
        }
        Player attacker = players[attackerId]
        Player victim = players[victimId]
        if (identify.rollAttacker(scenario, attacker, rng)) {
            events.append(
                TickEvent(
                    "identify_attacker",
                    -1,
                    -1,
                    attackerId,
                    victimId))
        }
        if (identify.rollDefender(scenario, victim, rng)) {
            events.append(
                TickEvent(
                    "identify_defender",
                    -1,
                    -1,
                    victimId,
                    attackerId))
            closePact(agreements, attackerId, victimId, events)
        }
    }

    /*
     * Close a live agreement between two empires if present.
     *
     * Purpose: attributed attack ends trade (RULES §9).
     *
     * Parameters:
     *   agreements — mutable list.
     *   a / b — empire ids.
     *   events — log.
     *
     * Returns: nothing.
     */
    void closePact(
        list agreements,
        int64 a,
        int64 b,
        list events) {
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.isLive() and pact.involves(a) and pact.involves(b)) {
                pact.close()
                agreements[index] = pact
                events.append(
                    TickEvent(
                        "agreement_closed",
                        -1,
                        -1,
                        a,
                        pact.id))
            }
            index = index + 1
        }
    }

    /*
     * Force-recall pirates whose idle countdown expired (§7.8).
     *
     * Purpose: idle timeout while waiting on ambush.
     *
     * Parameters:
     *   scenario — teleport for return ETA.
     *   players — seats.
     *   fleets — mutable list.
     *   events — log.
     *
     * Returns: nothing.
     */
    void idleTimeout(
        Scenario scenario,
        list players,
        list fleets,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ambushInPosition and fleet.hullCount > 0) {
                if (fleet.ambushIdleLeft > 0) {
                    fleet.ambushIdleLeft = fleet.ambushIdleLeft - 1
                }
                if (fleet.ambushIdleLeft <= 0) {
                    fleet = forceRecall(scenario, players, fleet)
                    fleets[index] = fleet
                    events.append(
                        TickEvent(
                            "pirate_idle",
                            fleet.id,
                            fleet.senderPlanetId,
                            fleet.ownerId,
                            fleet.eta))
                    events.append(
                        TickEvent(
                            "recall",
                            fleet.id,
                            fleet.senderPlanetId,
                            fleet.ownerId,
                            fleet.eta))
                } else {
                    fleets[index] = fleet
                }
            }
            index = index + 1
        }
    }
}
