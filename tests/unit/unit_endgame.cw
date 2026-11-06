/*
 * tests/unit/unit_endgame.cw — eliminate-all and all-humans-quit ends.
 *
 * Closed mode: stripping one seat's planets eliminates them and
 * crowns the other. All humans quit ends even when an AI remains
 * (PLAN D5 / RULES §15).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial end-game unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/state.cw"

start {
    bool ok = true

    # --- closed eliminate-all ---
    State closed = State()
    closed.startClosed(43u, 2)
    int64 index = 0
    while (index < closed.galaxy.planets.length) {
        Planet rock = closed.galaxy.planets[index]
        if (rock.ownerId == 1) {
            rock.ownerId = -1
            rock.productive = false
            rock.shipyard = false
            rock.population = 0.0
            closed.galaxy.planets[index] = rock
        }
        index = index + 1
    }
    list ev = closed.tick()
    if (not closed.ended) {
        ok = false
    }
    if (ok and not closed.endReason.equals("eliminate_all")) {
        ok = false
    }
    if (ok and closed.winnerId != 0) {
        ok = false
    }
    Player loser = closed.players[1]
    if (ok and not loser.eliminated) {
        ok = false
    }
    bool sawEnd = false
    index = 0
    while (index < ev.length) {
        TickEvent e = ev[index]
        if (e.kind.equals("game_end")) {
            sawEnd = true
        }
        index = index + 1
    }
    if (ok and not sawEnd) {
        ok = false
    }

    # --- all humans quit; AI left behind ---
    State quitGame = State()
    quitGame.startClosed(44u, 3)
    if (not quitGame.markPlayerAi(2)) {
        ok = false
    }
    if (not quitGame.quitPlayer(0)) {
        ok = false
    }
    if (quitGame.ended) {
        # one human still present
        ok = false
    }
    if (not quitGame.quitPlayer(1)) {
        ok = false
    }
    if (ok and not quitGame.ended) {
        ok = false
    }
    if (ok and not quitGame.endReason.equals("all_humans_quit")) {
        ok = false
    }
    if (ok and quitGame.winnerId != -1) {
        ok = false
    }
    Player ai = quitGame.players[2]
    if (ok and ai.eliminated) {
        # AI is not auto-eliminated; game simply ends.
        ok = false
    }

    # --- zombie drop while another human remains: game continues ---
    State zombie = State()
    zombie.startClosed(45u, 2)
    if (not zombie.dropPlayer(1)) {
        ok = false
    }
    if (zombie.ended) {
        ok = false
    }
    Player z = zombie.players[1]
    if (ok and not z.dropped) {
        ok = false
    }
    if (ok and z.eliminated) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
