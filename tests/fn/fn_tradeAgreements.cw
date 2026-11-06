/*
 * tests/fn/fn_tradeAgreements.cw — Phase D2 trade / agreements cluster.
 *
 * Fixed seed: both-accept agreement; cargo full both ways + escorts
 * cycle; sender-only loading; self-trade cost-only; S=100 needs
 * 10×10 holds; closed agreement / role-off-trader breaks; same-tick
 * recall cancels (PLAN D2 / RULES §5 / §8).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase D2 function program.
 *   2026-11-05  Phase D5: strip sandbox homes in prepTraders so
 *               partner-rock wealth math stays deterministic.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

/*
 * FnTrade counts events and builds a two-seat trade sandbox.
 *
 * Purpose: keep the start block free of duplicated setup loops.
 */
class FnTrade {
    /*
     * Construct a stateless helper.
     *
     * Purpose: match other fn test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnTrade instance.
     */
    FnTrade() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert trade / depart / cancel counts.
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
     * Prepare two trader seats, partner rock, freighter, teleport.
     *
     * Purpose: shared sandbox for agreement trade hops (ETA 0).
     *
     * Parameters:
     *   game — mutable state already startClosed(…, 2).
     *   hulls — freighter hull count.
     *   hold — hold per hull.
     *
     * Returns: freighter design index in game.designs.
     */
    int64 prepTraders(State game, int64 hulls, fp64 hold) {
        game.setRole(0, "trader")
        game.setRole(1, "trader")
        # D5 gives seat 1 a productive sandbox home. Clear it so the
        # partner rock below is the only p1 possession (wealth math
        # assumes no receiver home production).
        int64 index = 0
        while (index < game.galaxy.planets.length) {
            Planet prior = game.galaxy.planets[index]
            if (prior.ownerId == 1) {
                prior.ownerId = -1
                prior.productive = false
                prior.shipyard = false
                prior.population = 0.0
                game.galaxy.planets[index] = prior
            }
            index = index + 1
        }
        Planet rock = game.galaxy.planets[1]
        rock.ownerId = 1
        rock.qualityKnown = true
        rock.productive = false
        rock.shipyard = false
        rock.population = 0.0
        rock.partitionId = 1
        game.galaxy.planets[1] = rock
        Player a = game.players[0]
        a.tech = game.scenario.techTeleportThreshold
        a.wealth = 100000.0
        a.resources = 100000.0
        game.players[0] = a
        Player b = game.players[1]
        b.wealth = 100000.0
        b.resources = 100000.0
        game.players[1] = b
        Design freighter = Design(game.nextDesignId)
        game.nextDesignId = game.nextDesignId + 1
        freighter.makeFreighter(game.scenario.scoutRange, hold)
        game.designs.append(freighter)
        int64 fid = game.designs.length - 1
        game.fleets.clear()
        game.fleets.append(Fleet(1, 0, 0, fid, hulls))
        return(fid)
    }
}

start {
    FnTrade check = FnTrade()
    bool ok = true
    # --- happy path: exchange + return profit + recycle; escorts ---
    State game = State()
    game.startClosed(47u, 2)
    int64 cargoDesign = check.prepTraders(game, 10, 10.0)
    Design escort = Design(game.nextDesignId)
    game.nextDesignId = game.nextDesignId + 1
    escort.makeEscort(game.scenario.scoutRange)
    game.designs.append(escort)
    int64 escortDesign = game.designs.length - 1
    int64 pactId = game.proposeAgreement(0, 1, 100.0)
    if (not game.acceptAgreement(pactId, 0)
        or not game.acceptAgreement(pactId, 1)) {
        ok = false
    }
    if (ok and not game.findAgreement(pactId).isLive()) {
        ok = false
    }
    Player sender0 = game.players[0]
    Player recv0 = game.players[1]
    fp64 sw0 = sender0.wealth
    fp64 sr0 = sender0.resources
    fp64 rw0 = recv0.wealth
    if (ok and not game.issueTrade(1, 1, pactId, escortDesign, 2)) {
        ok = false
    }
    Fleet pending = game.findFleet(1)
    if (ok
        and (pending.escortHullCount != 2
            or pending.tradeSize != 100.0)) {
        ok = false
    }
    list ev1 = game.tick()
    # Teleport outbound: depart, arrive far, exchange, bounce.
    # Return leg ETA 0 lands on the next tick.
    if (ok and check.countKind(ev1, "depart") < 1) {
        ok = false
    }
    if (ok and check.countKind(ev1, "trade_exchange") != 1) {
        ok = false
    }
    if (ok and check.countKind(ev1, "trade_bounce") != 1) {
        ok = false
    }
    list ev2 = game.tick()
    if (ok and check.countKind(ev2, "trade_profit") != 1) {
        ok = false
    }
    if (ok and check.countKind(ev2, "trade_recycle") != 1) {
        ok = false
    }
    Player sender1 = game.players[0]
    Player recv1 = game.players[1]
    Dispatch bill = Dispatch()
    Fleet probe = Fleet(99, 0, 0, cargoDesign, 10)
    probe.escortDesignId = escortDesign
    probe.escortHullCount = 2
    fp64 dcost = bill.fleetDispatchCost(
        game.scenario,
        game.designs,
        probe)
    fp64 load = 100.0
    Planet home = game.galaxy.planets[0]
    fp64 prodW = home.livability * game.scenario.coverFactor * 0.01
    fp64 prodR = home.resources * game.scenario.coverFactor * 0.01
    # Two ticks of home production; one dispatch+loading; return
    # profit. Receiver inbound bump only — sender-only loading.
    fp64 inbound = 100.0 * (game.scenario.tradeBump - 1.0) * 0.5
    fp64 profit = 100.0 * (game.scenario.tradeBump - 1.0)
    fp64 expectS = sw0 + 2.0 * prodW - dcost - load + profit
    fp64 ds = sender1.wealth - expectS
    if (ds < 0.0) {
        ds = 0.0 - ds
    }
    if (ok and ds > 0.01) {
        ok = false
    }
    fp64 expectR = rw0 + inbound
    fp64 dr = recv1.wealth - expectR
    if (dr < 0.0) {
        dr = 0.0 - dr
    }
    if (ok and dr > 0.01) {
        ok = false
    }
    fp64 expectRes = sr0 - load + 2.0 * prodR
    fp64 dres = sender1.resources - expectRes
    if (dres < 0.0) {
        dres = 0.0 - dres
    }
    if (ok and dres > 0.01) {
        ok = false
    }
    # Receiver resources untouched by sender loading (no home yard).
    if (ok and recv1.resources != recv0.resources) {
        ok = false
    }
    Fleet cycled = game.findFleet(1)
    if (ok
        and (not cycled.pendingDeparture
            or cycled.escortHullCount != 2
            or not cycled.tradeOutbound)) {
        ok = false
    }

    # --- S=100 with 9×10 holds fails to leave ---
    State thin = State()
    thin.startClosed(47u, 2)
    check.prepTraders(thin, 9, 10.0)
    int64 thinPact = thin.proposeAgreement(0, 1, 100.0)
    thin.acceptAgreement(thinPact, 0)
    thin.acceptAgreement(thinPact, 1)
    if (ok and not thin.issueTrade(1, 1, thinPact, -1, 0)) {
        ok = false
    }
    list evThin = thin.tick()
    if (ok and check.countKind(evThin, "depart_fail") != 1) {
        ok = false
    }
    if (ok and check.countKind(evThin, "depart") != 0) {
        ok = false
    }

    # --- self-trade: cost-only, no exchange / profit ---
    State self = State()
    self.startClosed(47u, 1)
    Player sp = self.players[0]
    sp.tech = self.scenario.techTeleportThreshold
    sp.wealth = 100000.0
    sp.resources = 100000.0
    self.players[0] = sp
    Design sf = Design(self.nextDesignId)
    self.nextDesignId = self.nextDesignId + 1
    sf.makeFreighter(self.scenario.scoutRange, 10.0)
    self.designs.append(sf)
    int64 sfid = self.designs.length - 1
    self.fleets.clear()
    self.fleets.append(Fleet(1, 0, 0, sfid, 5))
    # Own planet 1 for self-trade destination.
    Planet own = self.galaxy.planets[1]
    own.ownerId = 0
    own.qualityKnown = true
    self.galaxy.planets[1] = own
    Player selfBefore = self.players[0]
    fp64 selfW0 = selfBefore.wealth
    if (ok and not self.issueTrade(1, 1, -1, -1, 0)) {
        ok = false
    }
    list evSelf = self.tick()
    if (ok and check.countKind(evSelf, "trade_self") < 1) {
        ok = false
    }
    if (ok and check.countKind(evSelf, "trade_exchange") != 0) {
        ok = false
    }
    list evSelf2 = self.tick()
    if (ok and check.countKind(evSelf2, "trade_profit") != 0) {
        ok = false
    }
    if (ok and check.countKind(evSelf2, "trade_stop") < 1) {
        ok = false
    }
    Player afterSelf = self.players[0]
    if (ok and afterSelf.wealth >= selfW0) {
        ok = false
    }

    # --- closed agreement: finish hop, no exchange ---
    State closed = State()
    closed.startClosed(47u, 2)
    check.prepTraders(closed, 10, 10.0)
    int64 cPact = closed.proposeAgreement(0, 1, 100.0)
    closed.acceptAgreement(cPact, 0)
    closed.acceptAgreement(cPact, 1)
    if (ok and not closed.issueTrade(1, 1, cPact, -1, 0)) {
        ok = false
    }
    if (ok and not closed.closeAgreement(cPact)) {
        ok = false
    }
    list evClosed = closed.tick()
    if (ok and check.countKind(evClosed, "trade_break") < 1) {
        ok = false
    }
    if (ok and check.countKind(evClosed, "trade_exchange") != 0) {
        ok = false
    }
    list evClosed2 = closed.tick()
    if (ok and check.countKind(evClosed2, "trade_profit") != 0) {
        ok = false
    }
    if (ok and check.countKind(evClosed2, "trade_stop") < 1) {
        ok = false
    }

    # --- role-off-trader: break like closed pact ---
    State role = State()
    role.startClosed(47u, 2)
    check.prepTraders(role, 10, 10.0)
    int64 rPact = role.proposeAgreement(0, 1, 100.0)
    role.acceptAgreement(rPact, 0)
    role.acceptAgreement(rPact, 1)
    if (ok and not role.issueTrade(1, 1, rPact, -1, 0)) {
        ok = false
    }
    role.setRole(0, "conqueror")
    list evRole = role.tick()
    if (ok and check.countKind(evRole, "trade_break") < 1) {
        ok = false
    }
    if (ok and check.countKind(evRole, "trade_exchange") != 0) {
        ok = false
    }
    list evRole2 = role.tick()
    if (ok and check.countKind(evRole2, "trade_stop") < 1) {
        ok = false
    }

    # --- same-tick recall cancels (no dispatch) ---
    State cancel = State()
    cancel.startClosed(47u, 2)
    check.prepTraders(cancel, 10, 10.0)
    int64 kPact = cancel.proposeAgreement(0, 1, 100.0)
    cancel.acceptAgreement(kPact, 0)
    cancel.acceptAgreement(kPact, 1)
    Player cancelBefore = cancel.players[0]
    fp64 cw0 = cancelBefore.wealth
    if (ok and not cancel.issueTrade(1, 1, kPact, -1, 0)) {
        ok = false
    }
    if (ok and not cancel.recallFleet(1)) {
        ok = false
    }
    list evCancel = cancel.tick()
    if (ok and check.countKind(evCancel, "cancel") != 1) {
        ok = false
    }
    if (ok and check.countKind(evCancel, "depart") != 0) {
        ok = false
    }
    Planet ch = cancel.galaxy.planets[0]
    fp64 cprod = ch.livability * cancel.scenario.coverFactor * 0.01
    Player cancelAfter = cancel.players[0]
    fp64 cdelta = cancelAfter.wealth - (cw0 + cprod)
    if (cdelta < 0.0) {
        cdelta = 0.0 - cdelta
    }
    if (ok and cdelta > 0.01) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
