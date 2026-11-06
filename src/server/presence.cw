/*
 * src/server/presence.cw — AFK≠drop handshake and pause gate (F).
 *
 * Handshake / keep-alive proves the session is alive. Missing
 * policy PUTs alone are AFK (last policy). Handshake failure is a
 * drop. Pause is offered only with exactly one human (RULES §2 /
 * PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial presence book and pause helper.
 */

include "../lib/player.cw"

/*
 * PresenceSeat tracks live contact for one empire.
 *
 * connected means the TCP session / handshake is alive. AFK is
 * derived as connected && idle policy — not a separate wire flag
 * here. missLimitMs is how long without handshake before drop.
 */
class PresenceSeat {
    int64 playerId
    bool connected
    uint64 lastHandshakeMs
    uint64 missLimitMs

    /*
     * Construct a disconnected presence seat.
     *
     * Purpose: pre-size the book with the handshake miss window.
     *
     * Parameters:
     *   seat — empire id.
     *   missMs — drop after this many ms without handshake.
     *
     * Returns: PresenceSeat with connected false.
     */
    PresenceSeat(int64 seat, uint64 missMs) {
        playerId = seat
        connected = false
        lastHandshakeMs = 0u
        missLimitMs = missMs
    }
}

/*
 * PresenceBook owns handshake, drop detection, and pause rules.
 *
 * Does not store policy — that is PolicyTable. Call scanDrops with
 * the current clock before cadence fire.
 */
class PresenceBook {
    list seats
    uint64 defaultMissMs

    /*
     * Construct an empty presence book.
     *
     * Purpose: fill via ensureSeats after State start.
     *
     * Parameters:
     *   missMs — default handshake miss window (milliseconds).
     *
     * Returns: PresenceBook with no seats.
     */
    PresenceBook(uint64 missMs) {
        seats = []
        defaultMissMs = missMs
    }

    /*
     * Grow the book to cover player ids 0..count-1.
     *
     * Purpose: match State.players. Keeps existing seats.
     *
     * Parameters:
     *   count — number of empire seats.
     *
     * Returns: nothing.
     */
    void ensureSeats(int64 count) {
        while (seats.length < count) {
            seats.append(
                PresenceSeat(seats.length, defaultMissMs))
        }
    }

    /*
     * Record a handshake for a seat at nowMs.
     *
     * Purpose: prove live contact so AFK ≠ drop (RULES §2).
     *
     * Parameters:
     *   playerId — empire id.
     *   nowMs — current server clock.
     *
     * Returns: true when the seat exists and was marked connected.
     */
    bool handshake(int64 playerId, uint64 nowMs) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        seat.connected = true
        seat.lastHandshakeMs = nowMs
        seats[playerId] = seat
        return(true)
    }

    /*
     * True when the seat currently has live contact.
     *
     * Purpose: tests and handler checks.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: connected flag, or false when out of range.
     */
    bool isConnected(int64 playerId) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        return(seat.connected)
    }

    /*
     * Force a drop (lost contact) on one seat.
     *
     * Purpose: TCP close / scanDrops path; last policy continues
     * for the live remainder (no rejoin in v1).
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when the seat existed and was connected.
     */
    bool markDrop(int64 playerId) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        bool was = seat.connected
        seat.connected = false
        seats[playerId] = seat
        return(was)
    }

    /*
     * Drop seats whose handshake is older than missLimitMs.
     *
     * Purpose: distinguish AFK (connected, idle policy) from drop
     * (lost contact). Appends dropped player ids to outIds.
     *
     * Parameters:
     *   nowMs — current server clock.
     *   outIds — list to append newly dropped player ids.
     *
     * Returns: number of newly dropped seats.
     */
    int64 scanDrops(uint64 nowMs, list outIds) {
        int64 dropped = 0
        int64 index = 0
        while (index < seats.length) {
            PresenceSeat seat = seats[index]
            if (seat.connected) {
                uint64 age = nowMs - seat.lastHandshakeMs
                if (nowMs < seat.lastHandshakeMs
                    or age >= seat.missLimitMs) {
                    seat.connected = false
                    seats[index] = seat
                    outIds.append(seat.playerId)
                    dropped = dropped + 1
                }
            }
            index = index + 1
        }
        return(dropped)
    }

    /*
     * Count human seats still in the live game.
     *
     * Purpose: pause gate and all-humans-quit helpers.
     *
     * Parameters:
     *   players — State.players list of Player.
     *
     * Returns: humans who have not quit or dropped.
     */
    int64 countLiveHumans(list players) {
        int64 found = 0
        int64 index = 0
        while (index < players.length) {
            Player seat = players[index]
            if (seat.human
                and (not seat.quit)
                and (not seat.dropped)) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * True when pause may be offered.
     *
     * Purpose: RULES §2 — pause only with exactly one human.
     *
     * Parameters:
     *   players — State.players list of Player.
     *
     * Returns: true when countLiveHumans == 1.
     */
    bool pauseAllowed(list players) {
        return(countLiveHumans(players) == 1)
    }
}
