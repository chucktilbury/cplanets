/*
 * src/unit_contact.cw — explore couples partitions; known competitors.
 *
 * Two seats start in separate sandboxes. Exploring a foreign
 * partition rock couples them and fills known competitors
 * (PLAN D5 / RULES §2 / §13).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial contact unit program.
 */

include "lib/state.cw"

start {
    State game = State()
    game.startClosed(41u, 2)
    bool ok = true
    Player p0 = game.players[0]
    Player p1 = game.players[1]
    if (p0.partitionId == p1.partitionId) {
        ok = false
    }
    if (p0.knownCompetitors.length != 0) {
        ok = false
    }
    int64 foreign = -1
    int64 index = 0
    while (index < game.galaxy.planets.length) {
        Planet rock = game.galaxy.planets[index]
        if (rock.partitionId == p1.partitionId and rock.ownerId < 0) {
            foreign = rock.id
        }
        index = index + 1
    }
    if (foreign < 0) {
        # Fall back to p1 home itself for explore.
        index = 0
        while (index < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[index]
            if (rock.ownerId == 1) {
                foreign = rock.id
            }
            index = index + 1
        }
    }
    if (foreign < 0) {
        ok = false
    }
    Design scout = game.designs[0]
    scout.hopReach = 1000.0
    game.designs[0] = scout
    Player seat0 = game.players[0]
    seat0.tech = game.scenario.techTeleportThreshold
    game.players[0] = seat0
    if (ok and not game.issueOrder(1, "explore", foreign)) {
        ok = false
    }
    list events = game.tick()
    p0 = game.players[0]
    p1 = game.players[1]
    if (ok and p0.partitionId != p1.partitionId) {
        ok = false
    }
    if (ok and not p0.knowsCompetitor(1)) {
        ok = false
    }
    if (ok and not p1.knowsCompetitor(0)) {
        ok = false
    }
    bool sawExplore = false
    bool sawContact = false
    index = 0
    while (index < events.length) {
        TickEvent ev = events[index]
        if (ev.kind.equals("explore")) {
            sawExplore = true
        }
        if (ev.kind.equals("contact")) {
            sawContact = true
        }
        index = index + 1
    }
    if (ok and not sawExplore) {
        ok = false
    }
    if (ok and not sawContact) {
        ok = false
    }
    Planet explored = game.galaxy.planets[foreign]
    if (ok and not explored.qualityKnown) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
