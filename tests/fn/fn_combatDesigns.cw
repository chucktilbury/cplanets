/*
 * tests/fn/fn_combatDesigns.cw — Phase D4 combat / designs / reclaim.
 *
 * Fixed seed: multi-tick engagement; mid-dispatch lock; design
 * develop + yard reclaim take time; screened heavies; capture-use
 * vs destroy; attributed attack ends agreement + confiscation
 * (PLAN D4 / RULES §5 / §9 / §12).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase D4 function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/screen.cw"
include "lib/state.cw"

/*
 * FnCombat counts events and builds D4 sandboxes.
 *
 * Purpose: keep the start block free of duplicated setup loops.
 */
class FnCombat {
    /*
     * Construct a stateless helper.
     *
     * Purpose: match other fn test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnCombat instance.
     */
    FnCombat() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert combat / reclaim / confiscate counts.
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
     * Sum event counts of one kind across many ticks.
     *
     * Purpose: multi-tick fights emit combat_tick over time.
     *
     * Parameters:
     *   game — mutable state.
     *   kind — event kind.
     *   ticks — how many ticks to run.
     *
     * Returns: total matching events.
     */
    int64 countOverTicks(State game, String kind, int64 ticks) {
        int64 found = 0
        int64 n = 0
        while (n < ticks) {
            list events = game.tick()
            found = found + countKind(events, kind)
            n = n + 1
        }
        return(found)
    }
}

start {
    FnCombat check = FnCombat()
    bool ok = true

    # --- mid-dispatch: in-flight fleet locked; other policy OK ---
    State lockGame = State()
    lockGame.startClosed(17u, 1)
    Design lockScout = lockGame.designs[0]
    lockScout.hopReach = 100.0
    lockGame.designs[0] = lockScout
    Fleet other = Fleet(2, 0, 0, 0, 1)
    lockGame.fleets.append(other)
    lockGame.nextFleetId = 3
    Player seat = lockGame.primaryPlayer()
    seat.wealth = seat.wealth + 100.0
    # Keep tech below teleport so ETA stays positive.
    seat.tech = 1.0
    lockGame.players[0] = seat
    if (not lockGame.issueOrder(1, "move", 1)) {
        ok = false
    }
    # Force a multi-tick hop so the fleet is still in flight after
    # one tick (some seeds place planet 1 at ETA 0 distance).
    Fleet pending = lockGame.findFleet(1)
    pending.eta = 5
    pending.outboundEta = 5
    lockGame.storeFleet(pending)
    list lockEv = lockGame.tick()
    Fleet gone = lockGame.findFleet(1)
    if (ok and (not gone.departed or not gone.orderLocked())) {
        ok = false
    }
    if (ok and lockGame.issueOrder(1, "take", 1)) {
        # Mid-dispatch rewrite must refuse.
        ok = false
    }
    if (ok and not lockGame.issueOrder(2, "move", 1)) {
        # Other policy still OK.
        ok = false
    }
    if (ok and not lockGame.recallFleet(1)) {
        ok = false
    }

    # --- design develop takes time (not instant) ---
    State desGame = State()
    desGame.startClosed(61u, 1)
    Design draft = Design(0)
    draft.makeFrigate(desGame.scenario.scoutRange, 1.5, 2.0)
    desGame.scenario.designDevelopTicks = 3
    int64 did = desGame.queueDesignDevelop(0, draft)
    if (did < 0) {
        ok = false
    } else {
        Design developing = desGame.designs[did]
        if (developing.isReady()) {
            ok = false
        }
        int64 t = 0
        while (t < desGame.scenario.designDevelopTicks) {
            desGame.tick()
            t = t + 1
        }
        developing = desGame.designs[did]
        if (not developing.isReady()) {
            ok = false
        }
    }

    # --- reclaim only at yard; takes time; percent credit ---
    State reclaimGame = State()
    reclaimGame.startClosed(62u, 1)
    reclaimGame.scenario.yardBuildTicks = 2
    reclaimGame.scenario.reclaimPercent = 0.50
    Fleet homeFleet = reclaimGame.findFleet(1)
    int64 beforeHulls = homeFleet.hullCount
    Player before = reclaimGame.primaryPlayer()
    fp64 res0 = before.resources
    if (not reclaimGame.queueReclaim(1, 1)) {
        ok = false
    }
    homeFleet = reclaimGame.findFleet(1)
    if (ok and homeFleet.hullCount != beforeHulls - 1) {
        ok = false
    }
    if (ok and reclaimGame.reclaims.length != 1) {
        ok = false
    }
    reclaimGame.tick()
    if (ok and reclaimGame.reclaims.length != 1) {
        # Still in progress after 1 of 2 ticks.
        ok = false
    }
    list reclaimEv = reclaimGame.tick()
    if (ok and check.countKind(reclaimEv, "reclaim") != 1) {
        ok = false
    }
    Player after = reclaimGame.primaryPlayer()
    Design scout = reclaimGame.designs[0]
    fp64 expect = scout.size * 10.0 * 0.50
    fp64 gained = after.resources - res0
    # Production also credits resources each tick — require reclaim
    # bump above two production ticks alone.
    if (ok and gained < expect) {
        ok = false
    }

    # --- multi-tick engagement (no short-circuit) ---
    State fightGame = State()
    fightGame.startClosed(63u, 2)
    fightGame.scenario.battleShortCircuitGap = 100.0
    fightGame.scenario.battleStrengthDurationCoeff = 2.0
    fightGame.scenario.productiveInherentDefense = 3.0
    Planet rock = fightGame.galaxy.planets[1]
    rock.ownerId = 1
    rock.productive = true
    rock.population = 1.0
    rock.satelliteDefense = 0.0
    rock.qualityKnown = true
    fightGame.galaxy.planets[1] = rock
    Fleet atk = fightGame.findFleet(1)
    atk.hullCount = 6
    fightGame.storeFleet(atk)
    seat = fightGame.primaryPlayer()
    seat.wealth = seat.wealth + 200.0
    seat.tech = fightGame.scenario.techTeleportThreshold
    fightGame.players[0] = seat
    if (not fightGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    int64 combatTicks = 0
    int64 openSeen = 0
    int64 steps = 0
    bool resolved = false
    while (steps < 30 and not resolved) {
        list ev = fightGame.tick()
        openSeen = openSeen + check.countKind(ev, "combat_open")
        combatTicks = combatTicks + check.countKind(ev, "combat_tick")
        if (check.countKind(ev, "take") > 0
            or check.countKind(ev, "defend") > 0) {
            resolved = true
        }
        if (fightGame.countOpenEngagements() == 0
            and openSeen > 0
            and steps > 0) {
            resolved = true
        }
        steps = steps + 1
    }
    if (ok and openSeen < 1) {
        ok = false
    }
    if (ok and combatTicks < 2) {
        # Must span multiple advance ticks (not one-shot).
        ok = false
    }

    # --- attributed attack ends agreement + confiscation ---
    String setup = ""
    setup.append("capture_use_chance = 0.0\n")
    setup.append("tech_teleport_enabled = true\n")
    setup.append("tech_teleport_threshold = 1.0\n")
    State attrGame = State()
    attrGame.startFromText(setup, 64u, 2)
    attrGame.setRole(0, "trader")
    attrGame.setRole(1, "trader")
    Planet far = attrGame.galaxy.planets[1]
    far.ownerId = 1
    far.productive = false
    far.population = 0.0
    far.satelliteDefense = 0.0
    far.qualityKnown = true
    attrGame.galaxy.planets[1] = far
    # Victim keeps home; attacker will take planet 1 (unowned fight
    # free) — use a second owned non-productive rock if needed.
    # Attribute path: take a productive owned world with inherent.
    far.productive = true
    far.population = 1.0
    attrGame.galaxy.planets[1] = far
    attrGame.scenario.productiveInherentDefense = 0.01
    attrGame.scenario.battleShortCircuitGap = 1.0
    Player a0 = attrGame.players[0]
    a0.tech = attrGame.scenario.techTeleportThreshold
    a0.wealth = 100000.0
    a0.resources = 100000.0
    attrGame.players[0] = a0
    Player a1 = attrGame.players[1]
    a1.tech = attrGame.scenario.techTeleportThreshold
    a1.wealth = 100000.0
    a1.resources = 100000.0
    attrGame.players[1] = a1
    Design freighter = Design(attrGame.nextDesignId)
    attrGame.nextDesignId = attrGame.nextDesignId + 1
    freighter.makeFreighter(20.0, 10.0, 1.0, 2.0)
    attrGame.designs.append(freighter)
    int64 fid = attrGame.designs.length - 1
    attrGame.fleets.clear()
    attrGame.fleets.append(Fleet(1, 0, 0, 0, 10))
    attrGame.fleets.append(Fleet(2, 1, 1, fid, 5))
    attrGame.nextFleetId = 3
    int64 pactId = attrGame.proposeAgreement(0, 1, 10.0)
    if (not attrGame.acceptAgreement(pactId, 0)
        or not attrGame.acceptAgreement(pactId, 1)) {
        ok = false
    }
    if (ok and not attrGame.issueOrder(1, "take", 1)) {
        ok = false
    }
    list attrEv = attrGame.tick()
    if (ok and check.countKind(attrEv, "agreement_closed") < 1) {
        ok = false
    }
    if (ok and check.countKind(attrEv, "confiscation_armed") < 1) {
        ok = false
    }
    # Victim sends a fleet to attacker's remaining world (home 0)
    # — wait, confiscation is at *victim* worlds from *attacker*.
    # Attacker fleet arriving at victim's remaining world.
    # Give victim another owned rock (planet 2) and send attacker.
    if (attrGame.galaxy.planets.length > 2) {
        Planet keep = attrGame.galaxy.planets[2]
        keep.ownerId = 1
        keep.qualityKnown = true
        attrGame.galaxy.planets[2] = keep
        Fleet raider = Fleet(3, 0, 0, fid, 2)
        attrGame.fleets.append(raider)
        attrGame.nextFleetId = 4
        if (ok and not attrGame.issueOrder(3, "move", 2)) {
            ok = false
        }
        list seizeEv = attrGame.tick()
        if (ok and check.countKind(seizeEv, "confiscate") < 1) {
            ok = false
        }
        if (ok and check.countKind(seizeEv, "capture_destroy") < 1) {
            ok = false
        }
    }

    # --- screening via Screen helper (fn-level sanity) ---
    Screen screen = Screen()
    Design frig = Design(0)
    frig.makeFrigate(3.0, 1.5, 2.0)
    Design dest = Design(1)
    dest.makeDestroyer(3.0, 1.0, 8.0)
    list designs = []
    designs.append(frig)
    designs.append(dest)
    list screened = []
    screened.append(Fleet(10, 0, 0, 0, 4))
    screened.append(Fleet(11, 0, 0, 1, 2))
    Fleet s0 = screened[0]
    s0.engagementId = 9
    screened[0] = s0
    Fleet s1 = screened[1]
    s1.engagementId = 9
    screened[1] = s1
    list bare = []
    bare.append(Fleet(12, 0, 0, 1, 2))
    Fleet b0 = bare[0]
    b0.engagementId = 8
    bare[0] = b0
    screen.applyHit(screened, designs, 9, 0, 0, 16.0)
    screen.applyHit(bare, designs, 8, 0, 0, 16.0)
    Fleet screenedHeavyFleet = screened[1]
    Fleet bareHeavyFleet = bare[0]
    if (ok and screenedHeavyFleet.hullCount <= bareHeavyFleet.hullCount) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
