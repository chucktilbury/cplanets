/*
 * tests/fn/fn_contactEnd.cw — Phase D5 contact / end function suite.
 *
 * Fixed seeds: contact couples partitions + known competitors;
 * closed eliminate-all; all-humans-quit ends; zombies fall to
 * normal play; empire pool only; setup lock in progress; stranded
 * moves after N (PLAN D5 checklist).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Phase D5 function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

/*
 * FnContact counts events and builds D5 sandboxes.
 *
 * Purpose: keep the start block free of duplicated loops.
 */
class FnContact {
    /*
     * Construct a stateless helper.
     *
     * Purpose: match other fn test helpers.
     *
     * Parameters: none.
     *
     * Returns: FnContact instance.
     */
    FnContact() {
    }

    /*
     * Count events of one kind in a tick log.
     *
     * Purpose: assert contact / end / stranded kinds.
     *
     * Parameters:
     *   events — TickEvent list.
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
     * Find first planet id in a partition owned by ownerId (or any).
     *
     * Purpose: pick explore / strip targets without scanning at
     * every call site.
     *
     * Parameters:
     *   game — state.
     *   partitionId — partition to match.
     *   ownerId — required owner, or −2 to ignore ownership.
     *
     * Returns: planet id or −1.
     */
    int64 findPlanet(
        State game,
        int64 partitionId,
        int64 ownerId) {
        int64 index = 0
        while (index < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[index]
            if (rock.partitionId == partitionId) {
                if (ownerId == -2 or rock.ownerId == ownerId) {
                    return(rock.id)
                }
            }
            index = index + 1
        }
        return(-1)
    }
}

start {
    FnContact check = FnContact()
    bool ok = true

    # --- setup lock in progress ---
    State lockGame = State()
    lockGame.startClosed(50u, 1)
    lockGame.ensureAllSeatHomes()
    if (lockGame.locked) {
        ok = false
    }
    lockGame.tick()
    if (ok and not lockGame.locked) {
        ok = false
    }

    # --- empire pool only (production credits player, not planet) ---
    State poolGame = State()
    poolGame.startClosed(51u, 1)
    poolGame.ensureAllSeatHomes()
    Player before = poolGame.primaryPlayer()
    fp64 w0 = before.wealth
    poolGame.tick()
    Player after = poolGame.primaryPlayer()
    if (ok and after.wealth <= w0) {
        ok = false
    }
    Planet home = poolGame.galaxy.planets[0]
    # Planet has no wealth field — ownership + population only.
    if (ok and home.ownerId != 0) {
        ok = false
    }

    # --- contact couples partitions; known competitors ---
    State contactGame = State()
    contactGame.startClosed(52u, 2)
    contactGame.ensureAllSeatHomes()
    Player a = contactGame.players[0]
    Player b = contactGame.players[1]
    if (a.partitionId == b.partitionId) {
        ok = false
    }
    int64 foreign = check.findPlanet(
        contactGame,
        b.partitionId,
        -1)
    if (foreign < 0) {
        foreign = check.findPlanet(contactGame, b.partitionId, 1)
    }
    Design scout = contactGame.designs[0]
    scout.hopReach = 1000.0
    contactGame.designs[0] = scout
    Player seat0 = contactGame.players[0]
    seat0.tech = contactGame.scenario.techTeleportThreshold
    contactGame.players[0] = seat0
    if (ok and foreign >= 0) {
        if (not contactGame.issueOrder(1, "explore", foreign)) {
            ok = false
        } else {
            list cev = contactGame.tick()
            a = contactGame.players[0]
            b = contactGame.players[1]
            if (a.partitionId != b.partitionId) {
                ok = false
            }
            if (not a.knowsCompetitor(1) or not b.knowsCompetitor(0)) {
                ok = false
            }
            if (check.countKind(cev, "contact") < 1) {
                ok = false
            }
        }
    } else {
        ok = false
    }

    # --- closed eliminate-all ---
    State endGame = State()
    endGame.startClosed(53u, 2)
    endGame.ensureAllSeatHomes()
    int64 i = 0
    while (i < endGame.galaxy.planets.length) {
        Planet rock = endGame.galaxy.planets[i]
        if (rock.ownerId == 1) {
            rock.ownerId = -1
            rock.productive = false
            rock.shipyard = false
            rock.population = 0.0
            endGame.galaxy.planets[i] = rock
        }
        i = i + 1
    }
    list eev = endGame.tick()
    if (ok and not endGame.ended) {
        ok = false
    }
    if (ok and not endGame.endReason.equals("eliminate_all")) {
        ok = false
    }
    if (ok and endGame.winnerId != 0) {
        ok = false
    }
    if (ok and check.countKind(eev, "eliminated") < 1) {
        ok = false
    }

    # --- all humans quit ends game (AI remains) ---
    State quitGame = State()
    quitGame.startClosed(54u, 3)
    quitGame.ensureAllSeatHomes()
    quitGame.markPlayerAi(2)
    quitGame.quitPlayer(0)
    if (quitGame.ended) {
        ok = false
    }
    quitGame.quitPlayer(1)
    if (ok and not quitGame.ended) {
        ok = false
    }
    if (ok and not quitGame.endReason.equals("all_humans_quit")) {
        ok = false
    }

    # --- zombies fall to normal play (no special win path) ---
    State zombieGame = State()
    zombieGame.startClosed(55u, 2)
    zombieGame.ensureAllSeatHomes()
    zombieGame.dropPlayer(1)
    if (zombieGame.ended) {
        ok = false
    }
    i = 0
    while (i < zombieGame.galaxy.planets.length) {
        Planet rock = zombieGame.galaxy.planets[i]
        if (rock.ownerId == 1) {
            rock.ownerId = -1
            rock.productive = false
            rock.shipyard = false
            rock.population = 0.0
            zombieGame.galaxy.planets[i] = rock
        }
        i = i + 1
    }
    zombieGame.tick()
    if (ok and not zombieGame.ended) {
        ok = false
    }
    if (ok and not zombieGame.endReason.equals("eliminate_all")) {
        ok = false
    }
    if (ok and zombieGame.winnerId != 0) {
        ok = false
    }
    Player zombie = zombieGame.players[1]
    if (ok and not zombie.eliminated) {
        ok = false
    }
    if (ok and not zombie.dropped) {
        ok = false
    }

    # --- stranded moves after N ticks ---
    State strandGame = State()
    strandGame.startClosed(56u, 1)
    strandGame.ensureAllSeatHomes()
    Fleet colony = Fleet(1, 0, 0, 1, 1)
    strandGame.fleets.clear()
    strandGame.fleets.append(colony)
    int64 farId = strandGame.scenario.worldCount - 1
    if (not strandGame.issueOrder(1, "move", farId)) {
        ok = false
    }
    list sev = strandGame.tick()
    Fleet sf = strandGame.findFleet(1)
    if (ok and not sf.stranded) {
        ok = false
    }
    if (ok and check.countKind(sev, "stranded") != 1) {
        ok = false
    }
    int64 wait = sf.strandedLeft
    int64 step = 0
    while (step < wait) {
        strandGame.tick()
        step = step + 1
    }
    sf = strandGame.findFleet(1)
    if (ok and sf.stranded) {
        ok = false
    }
    if (ok and not strandGame.issueOrder(1, "move", 1)) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
