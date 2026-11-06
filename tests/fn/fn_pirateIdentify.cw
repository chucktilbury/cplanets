/*
 * tests/fn/fn_pirateIdentify.cw — Phase D3 pirate / identify cluster.
 *
 * Fixed seed: ambush only after half hop; loot credits on pirate
 * return; two-pirate war (passer lives); forced recall; idle
 * timeout; identify asymmetry with separate knobs and victim-only
 * defender audience (PLAN D3 / RULES §6 / §9 / §10).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase D3 function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

/*
 * FnPirate counts events and builds pirate/trader sandboxes.
 *
 * Purpose: keep the start block free of duplicated setup loops.
 */
class FnPirate {
    /*
     * Construct a stateless helper.
     *
     * Purpose: match other fn test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnPirate instance.
     */
    FnPirate() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert ambush / loot / identify counts.
     *
     * Parameters:
     *   events — TickEvent list from State.tick.
     *   kind — kind string to count.
     *
     * Returns: number of matching events.
     */
    int64 countKind(list events, String kind) {
        int64 found = 0
        int64 index = 0
        while (index < events.length) {
            TickEvent ev = events[index]
            if (ev.kind.equals(kind)) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Place planet 1 at a fixed distance for ETA control.
     *
     * Purpose: freighter speed 1.0 over distance 10 ⇒ ETA 10.
     *
     * Parameters:
     *   game — mutable state.
     *   x — planet-1 x coordinate.
     *
     * Returns: nothing.
     */
    void placeFar(State game, fp64 x) {
        Planet rock = game.galaxy.planets[1]
        rock.x = x
        rock.y = 0.0
        game.galaxy.planets[1] = rock
    }

    /*
     * Prepare pirate seat 0, trader seat 1, war + freighter hulls.
     *
     * Purpose: shared sandbox for midpoint ambush tests. Both
     * seats stay below teleport so ETA 10 / half 5 is observable.
     *
     * Parameters:
     *   game — mutable state already startClosed/startFromText.
     *   pirateHulls — ambush fleet size.
     *
     * Returns: freighter design index.
     */
    int64 prepPirateTrade(State game, int64 pirateHulls) {
        game.setRole(0, "pirate")
        game.setRole(1, "trader")
        placeFar(game, 10.0)
        Planet rock = game.galaxy.planets[1]
        rock.ownerId = 1
        rock.qualityKnown = true
        game.galaxy.planets[1] = rock
        Player pirate = game.players[0]
        pirate.tech = 1.0
        pirate.wealth = 100000.0
        pirate.resources = 100000.0
        game.players[0] = pirate
        Player trader = game.players[1]
        trader.tech = 1.0
        trader.wealth = 100000.0
        trader.resources = 100000.0
        game.players[1] = trader
        Design war = Design(game.nextDesignId)
        game.nextDesignId = game.nextDesignId + 1
        war.makeEscort(20.0)
        war.speed = 1.0
        game.designs.append(war)
        int64 warId = game.designs.length - 1
        Design freighter = Design(game.nextDesignId)
        game.nextDesignId = game.nextDesignId + 1
        freighter.makeFreighter(20.0, 10.0)
        game.designs.append(freighter)
        int64 fid = game.designs.length - 1
        game.fleets.clear()
        game.fleets.append(Fleet(1, 0, 0, warId, pirateHulls))
        game.fleets.append(Fleet(2, 1, 1, fid, 10))
        game.nextFleetId = 3
        return(fid)
    }
}

start {
    FnPirate check = FnPirate()
    bool ok = true

    # --- ambush only after half ETA; loot on return; identify ---
    String setup = ""
    setup.append("identify_attacker_base = 1.0\n")
    setup.append("identify_attacker_per_attr = 0.0\n")
    setup.append("identify_defender_base = 1.0\n")
    setup.append("identify_defender_per_attr = 0.0\n")
    setup.append("pirate_attrition = 0.0\n")
    setup.append("pirate_idle_ticks = 50\n")
    State game = State()
    game.startFromText(setup, 47u, 2)
    # Escort size 3 ⇒ need enough hulls to beat 10× freighter size 2.
    check.prepPirateTrade(game, 20)
    int64 pactId = game.proposeAgreement(0, 1, 100.0)
    if (not game.acceptAgreement(pactId, 0)
        or not game.acceptAgreement(pactId, 1)) {
        ok = false
    }
    if (ok and not game.issueAmbush(1, 1)) {
        ok = false
    }
    # Non-pirate cannot ambush.
    if (ok and game.issueAmbush(2, 0)) {
        ok = false
    }
    if (ok and not game.issueTrade(2, 0, pactId, -1, 0)) {
        ok = false
    }
    Fleet pendingPirate = game.findFleet(1)
    if (ok and pendingPirate.eta != 5) {
        # half of full hop ETA 10
        ok = false
    }
    Fleet pendingTrade = game.findFleet(2)
    if (ok and pendingTrade.eta != 10) {
        ok = false
    }
    # Ticks 1–4: approach only — no ready, no robbery.
    # Pirate role stuck while ambush fleets are outstanding.
    if (ok and game.setRole(0, "neutral")) {
        ok = false
    }
    int64 early = 0
    while (early < 4) {
        list evEarly = game.tick()
        if (check.countKind(evEarly, "ambush_ready") > 0
            or check.countKind(evEarly, "ambush_win") > 0) {
            ok = false
        }
        early = early + 1
    }
    # Tick 5: pirate in position and trader at midpoint.
    list evMid = game.tick()
    if (ok and check.countKind(evMid, "ambush_ready") != 1) {
        ok = false
    }
    if (ok and check.countKind(evMid, "ambush_win") != 1) {
        ok = false
    }
    if (ok and check.countKind(evMid, "identify_attacker") != 1) {
        ok = false
    }
    if (ok and check.countKind(evMid, "identify_defender") != 1) {
        ok = false
    }
    if (ok and check.countKind(evMid, "agreement_closed") != 1) {
        ok = false
    }
    if (ok and check.countKind(evMid, "recall") < 1) {
        ok = false
    }
    Fleet after = game.findFleet(1)
    if (ok and (not after.order.equals("recall") or not after.hasLoot())) {
        ok = false
    }
    # Return leg: pirate had ticksTraveled=5 at ambush → ETA 5.
    Player beforeLoot = game.players[0]
    fp64 wealthBefore = beforeLoot.wealth
    int64 homeStep = 0
    bool credited = false
    while (homeStep < 8 and not credited) {
        list evHome = game.tick()
        if (check.countKind(evHome, "loot_credit") > 0) {
            credited = true
        }
        homeStep = homeStep + 1
    }
    if (ok and not credited) {
        ok = false
    }
    Player afterLoot = game.players[0]
    if (ok and afterLoot.wealth < wealthBefore + 99.0) {
        ok = false
    }
    Fleet home = game.findFleet(1)
    if (ok and (home.hasLoot() or not home.sitting)) {
        ok = false
    }
    # Ambush resolved; role may change.
    if (ok and not game.setRole(0, "neutral")) {
        ok = false
    }

    # --- two pirates war; passer lives ---
    String setup2 = ""
    setup2.append("identify_attacker_base = 0.0\n")
    setup2.append("identify_defender_base = 0.0\n")
    setup2.append("pirate_leftover = 0.5\n")
    setup2.append("pirate_idle_ticks = 50\n")
    State war = State()
    war.startFromText(setup2, 99u, 3)
    war.setRole(0, "pirate")
    war.setRole(1, "pirate")
    war.setRole(2, "trader")
    check.placeFar(war, 10.0)
    Planet rock2 = war.galaxy.planets[1]
    rock2.ownerId = 2
    rock2.qualityKnown = true
    war.galaxy.planets[1] = rock2
    Player p0 = war.players[0]
    p0.tech = war.scenario.techTeleportThreshold
    p0.wealth = 100000.0
    p0.resources = 100000.0
    war.players[0] = p0
    Player p1 = war.players[1]
    p1.tech = war.scenario.techTeleportThreshold
    p1.wealth = 100000.0
    p1.resources = 100000.0
    war.players[1] = p1
    Player p2 = war.players[2]
    p2.tech = 1.0
    p2.wealth = 100000.0
    p2.resources = 100000.0
    war.players[2] = p2
    Design warA = Design(war.nextDesignId)
    war.nextDesignId = war.nextDesignId + 1
    warA.makeEscort(20.0)
    war.designs.append(warA)
    int64 wa = war.designs.length - 1
    Design warB = Design(war.nextDesignId)
    war.nextDesignId = war.nextDesignId + 1
    warB.makeEscort(20.0)
    war.designs.append(warB)
    int64 wb = war.designs.length - 1
    Design freight = Design(war.nextDesignId)
    war.nextDesignId = war.nextDesignId + 1
    freight.makeFreighter(20.0, 10.0)
    war.designs.append(freight)
    int64 ff = war.designs.length - 1
    war.fleets.clear()
    war.fleets.append(Fleet(1, 0, 0, wa, 8))
    war.fleets.append(Fleet(2, 1, 0, wb, 2))
    war.fleets.append(Fleet(3, 2, 1, ff, 10))
    war.nextFleetId = 4
    if (ok and not war.issueAmbush(1, 1)) {
        ok = false
    }
    if (ok and not war.issueAmbush(2, 1)) {
        ok = false
    }
    Fleet pass = war.findFleet(3)
    bool traded = pass.issueTravel("trade", 0, 10)
    if (ok and not traded) {
        ok = false
    }
    pass.outboundEta = 10
    pass.cargoWealth = 100.0
    pass.cargoResources = 100.0
    pass.tradeSize = 100.0
    war.storeFleet(pass)
    list w1 = war.tick()
    if (ok and check.countKind(w1, "pirate_war") != 1) {
        ok = false
    }
    if (ok and check.countKind(w1, "ambush_win") != 0) {
        ok = false
    }
    Fleet passerAlive = war.findFleet(3)
    if (ok
        and (passerAlive.hullCount != 10
            or passerAlive.cargoWealth != 100.0)) {
        ok = false
    }
    # Advance passer through midpoint; still unharmed (no sole pirate).
    int64 s2 = 0
    while (s2 < 6) {
        list we = war.tick()
        if (check.countKind(we, "ambush") > 0) {
            ok = false
        }
        s2 = s2 + 1
    }
    Fleet passerStill = war.findFleet(3)
    if (ok and passerStill.hullCount != 10) {
        ok = false
    }

    # --- idle timeout forces recall ---
    String setup3 = ""
    setup3.append("pirate_idle_ticks = 2\n")
    setup3.append("identify_attacker_base = 0.0\n")
    setup3.append("identify_defender_base = 0.0\n")
    State idle = State()
    idle.startFromText(setup3, 7u, 2)
    idle.setRole(0, "pirate")
    check.placeFar(idle, 10.0)
    Player ip = idle.players[0]
    ip.tech = idle.scenario.techTeleportThreshold
    ip.wealth = 100000.0
    ip.resources = 100000.0
    idle.players[0] = ip
    Design iw = Design(idle.nextDesignId)
    idle.nextDesignId = idle.nextDesignId + 1
    iw.makeEscort(20.0)
    idle.designs.append(iw)
    int64 iwid = idle.designs.length - 1
    idle.fleets.clear()
    idle.fleets.append(Fleet(1, 0, 0, iwid, 3))
    idle.nextFleetId = 2
    if (ok and not idle.issueAmbush(1, 1)) {
        ok = false
    }
    list i1 = idle.tick()
    if (ok and check.countKind(i1, "ambush_ready") != 1) {
        ok = false
    }
    # Entry tick also runs idleTimeout: 2 → 1. Next tick 1 → 0.
    list i2 = idle.tick()
    if (ok and check.countKind(i2, "pirate_idle") != 1) {
        ok = false
    }
    Fleet recalled = idle.findFleet(1)
    if (ok and not recalled.order.equals("recall")) {
        ok = false
    }
    if (ok and recalled.ambushInPosition) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
