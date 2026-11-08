/*
 * src/lib/endgame.cw — closed eliminate-all and humans-quit (D5).
 *
 * Closed games end when one player has eliminated all others.
 * Dropped / AFK last-policy seats (“zombies”) use the same rules
 * — no consistent zombie-win path. If all human players quit or
 * drop, the server registers end of game (RULES §2 / §15).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial end-of-game checks for Phase D5.
 *   2026-11-08  Unseated (no homeGranted) seats skip elimination
 *               and do not count as living / closed-win blockers.
 *   2026-11-08  Only allocated seats (players[]) count; soft-max
 *               expected slots that never connected do not exist.
 */

include "event.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"

/*
 * EndGame owns elimination marking and closed / quit end checks.
 *
 * TickDriver calls run after contact. Outputs land on endedOut /
 * endReasonOut / winnerIdOut for State to copy.
 */
class EndGame {
    bool endedOut
    String endReasonOut
    int64 winnerIdOut

    /*
     * Construct a stateless end-game helper.
     *
     * Purpose: match other tick phase objects.
     *
     * Parameters: none.
     *
     * Returns: EndGame ready for run.
     */
    EndGame() {
        endedOut = false
        endReasonOut = ""
        winnerIdOut = -1
    }

    /*
     * Mark eliminations and maybe end a closed or empty-human game.
     *
     * Purpose: RULES §7.9 / §15 — eliminate seats with no planets;
     * closed mode wins when one living seat remains; all humans
     * gone ends the live game (no AI-only zombie match).
     *
     * Parameters:
     *   scenario — mode (closed vs future ongoing).
     *   planets — ownership scan.
     *   players — mutable seats.
     *   events — log.
     *   alreadyEnded — skip when the game already ended.
     *
     * Returns: true when the game is ended after this call.
     */
    bool run(
        Scenario scenario,
        list planets,
        list players,
        list events,
        bool alreadyEnded) {
        endedOut = alreadyEnded
        endReasonOut = ""
        winnerIdOut = -1
        if (alreadyEnded) {
            return(true)
        }
        markEliminations(planets, players, events)
        if (allHumansGone(players)) {
            endedOut = true
            endReasonOut = "all_humans_quit"
            winnerIdOut = -1
            events.append(
                TickEvent(
                    "game_end",
                    -1,
                    -1,
                    -1,
                    0))
            return(true)
        }
        if (scenario.isClosed() and players.length > 1) {
            int64 living = countLiving(players)
            int64 unseated = countUnseated(players)
            # Only seats that have been allocated exist in players[].
            # Unseated = allocated but not yet homeGranted (fixture
            # pre-create / rare grant failure). Soft-max expected
            # slots that never connected are not in the list — go
            # and eliminate-all use whoever was actually seated.
            if (living == 1 and unseated == 0) {
                int64 win = firstLiving(players)
                endedOut = true
                endReasonOut = "eliminate_all"
                winnerIdOut = win
                events.append(
                    TickEvent(
                        "game_end",
                        -1,
                        -1,
                        win,
                        1))
                return(true)
            }
            if (living == 0 and unseated == 0) {
                endedOut = true
                endReasonOut = "eliminate_all"
                winnerIdOut = -1
                events.append(
                    TickEvent(
                        "game_end",
                        -1,
                        -1,
                        -1,
                        0))
                return(true)
            }
        }
        return(false)
    }

    /*
     * Mark seated seats with zero owned planets as eliminated.
     *
     * Purpose: closed eliminate-all uses planet ownership as the
     * living test. Seats that have never received a home (not yet
     * connected) are skipped. Zombies are not spared (RULES §15).
     * Disconnect does not revoke homeGranted — homes stay in place.
     *
     * Parameters:
     *   planets — ownership.
     *   players — mutable seats.
     *   events — log.
     *
     * Returns: nothing.
     */
    void markEliminations(
        list planets,
        list players,
        list events) {
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (seat.homeGranted and not seat.eliminated) {
                int64 owned = countOwnedPlanets(planets, seat.id)
                if (owned == 0) {
                    seat.eliminated = true
                    players[index] = seat
                    events.append(
                        TickEvent(
                            "eliminated",
                            -1,
                            -1,
                            seat.id,
                            0))
                }
            }
            index = index + 1
        }
    }

    /*
     * Count planets owned by one empire.
     *
     * Purpose: elimination predicate helper.
     *
     * Parameters:
     *   planets — galaxy.
     *   ownerId — empire id.
     *
     * Returns: number of rocks with matching ownerId.
     */
    int64 countOwnedPlanets(list planets, int64 ownerId) {
        int64 found = 0
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            if (rock.ownerId == ownerId) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Count seated, non-eliminated empires.
     *
     * Purpose: closed win when exactly one living seated seat
     * remains. Unseated seats are ignored.
     *
     * Parameters:
     *   players — seats.
     *
     * Returns: living count.
     */
    int64 countLiving(list players) {
        int64 found = 0
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (seat.homeGranted and not seat.eliminated) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Count allocated seats that have never received a home.
     *
     * Purpose: closed eliminate-all waits until every **allocated**
     * seat has connected at least once (or a fixture seated them).
     * Soft-max expected seats that were never allocated do not
     * appear in players[] and do not block the end check.
     *
     * Parameters:
     *   players — allocated seats.
     *
     * Returns: number of players with homeGranted == false.
     */
    int64 countUnseated(list players) {
        int64 found = 0
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (not seat.homeGranted) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Return the first living seated seat id.
     *
     * Purpose: closed-game winner when living == 1.
     *
     * Parameters:
     *   players — seats.
     *
     * Returns: player id, or −1 when nobody is living.
     */
    int64 firstLiving(list players) {
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (seat.homeGranted and not seat.eliminated) {
                return(seat.id)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * True when no human seat remains in the live game.
     *
     * Purpose: leave / drop with no human remaining ends the
     * instance — do not leave an AI-only zombie match (RULES §2).
     *
     * Parameters:
     *   players — seats.
     *
     * Returns: true when at least one human seat existed and every
     * human has quit or dropped. Pure AI fixtures (zero humans)
     * do not trip this end.
     */
    bool allHumansGone(list players) {
        int64 humans = 0
        int64 gone = 0
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (seat.human) {
                humans = humans + 1
                if (seat.quit or seat.dropped or not seat.present) {
                    gone = gone + 1
                }
            }
            index = index + 1
        }
        if (humans == 0) {
            return(false)
        }
        return(gone == humans)
    }
}
