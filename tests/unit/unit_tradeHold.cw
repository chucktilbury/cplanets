/*
 * tests/unit/unit_tradeHold.cw — S=100 needs 10×10 cargo holds.
 *
 * Freighter hold 10: nine hulls fail dispatch; ten hulls depart
 * (PLAN D2 / RULES §5.1 / §8.1).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial hold-cover unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    bool ok = true
    Design sample = Design(0)
    sample.makeFreighter(10.0, 10.0, 1.0, 2.0)
    if (sample.coversTradeSize(9, 100.0)) {
        ok = false
    }
    if (not sample.coversTradeSize(10, 100.0)) {
        ok = false
    }
    if (sample.holdCapacity(10) != 100.0) {
        ok = false
    }

    State game = State()
    game.startClosed(43u, 2)
    game.setRole(0, "trader")
    game.setRole(1, "trader")
    # Partner owns planet 1; teleport so ETA is 0.
    Planet rock = game.galaxy.planets[1]
    rock.ownerId = 1
    rock.qualityKnown = true
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
    freighter.makeFreighter(game.scenario.scoutRange, 10.0, 1.0, 2.0)
    game.designs.append(freighter)
    int64 fid = game.designs.length - 1

    int64 pactId = game.proposeAgreement(0, 1, 100.0)
    game.acceptAgreement(pactId, 0)
    game.acceptAgreement(pactId, 1)

    game.fleets.clear()
    game.fleets.append(Fleet(1, 0, 0, fid, 9))
    if (not game.issueTrade(1, 1, pactId, -1, 0)) {
        ok = false
    }
    list evFail = game.tick()
    Fleet stuck = game.findFleet(1)
    if (stuck.departed) {
        ok = false
    }
    bool fail = false
    int64 index = 0
    while (index < evFail.length) {
        TickEvent ev = evFail[index]
        if (ev.kind.equals("depart_fail")) {
            fail = true
        }
        if (ev.kind.equals("depart")) {
            ok = false
        }
        index = index + 1
    }
    if (not fail) {
        ok = false
    }

    State rich = State()
    rich.startClosed(43u, 2)
    rich.setRole(0, "trader")
    rich.setRole(1, "trader")
    Planet r1 = rich.galaxy.planets[1]
    r1.ownerId = 1
    r1.qualityKnown = true
    rich.galaxy.planets[1] = r1
    Player ra = rich.players[0]
    ra.tech = rich.scenario.techTeleportThreshold
    ra.wealth = 100000.0
    ra.resources = 100000.0
    rich.players[0] = ra
    Player rb = rich.players[1]
    rb.wealth = 100000.0
    rb.resources = 100000.0
    rich.players[1] = rb
    Design f2 = Design(rich.nextDesignId)
    rich.nextDesignId = rich.nextDesignId + 1
    f2.makeFreighter(rich.scenario.scoutRange, 10.0, 1.0, 2.0)
    rich.designs.append(f2)
    int64 fid2 = rich.designs.length - 1
    int64 pact2 = rich.proposeAgreement(0, 1, 100.0)
    rich.acceptAgreement(pact2, 0)
    rich.acceptAgreement(pact2, 1)
    rich.fleets.clear()
    rich.fleets.append(Fleet(1, 0, 0, fid2, 10))
    if (not rich.issueTrade(1, 1, pact2, -1, 0)) {
        ok = false
    }
    list evOk = rich.tick()
    bool departed = false
    index = 0
    while (index < evOk.length) {
        TickEvent ev = evOk[index]
        if (ev.kind.equals("depart")) {
            departed = true
        }
        if (ev.kind.equals("depart_fail")) {
            ok = false
        }
        index = index + 1
    }
    if (not departed) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
