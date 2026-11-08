/*
 * src/server/presence.cw — AFK≠drop handshake and pause gate (F).
 *
 * Handshake / keep-alive proves the session is alive. Missing
 * policy PUTs alone are AFK (last policy). Handshake failure is a
 * drop — unless the seat is intentionally suspended (client AFK /
 * menu-open flag), which keeps the seat connected for presence and
 * skips handshake_miss drop while normal AFK production shrink
 * still applies. Pause is offered only with exactly one human
 * (RULES §2 / PLAN §4.F). Opaque reconnect tokens let a dropped
 * seat reclaim itself; empty handshake cannot steal a token-held
 * seat.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial presence book and pause helper.
 *   2026-11-08  Intentional suspended flag skips handshake_miss.
 *   2026-11-08  Server allocates free seats on connect (no client
 *               seat claim); keep-alive only when already connected.
 *   2026-11-08  Opaque 16-byte reconnect tokens on allocate;
 *               drop keeps token; quit clears it.
 */

include "../lib/player.cw"
include "../lib/rng.cw"

/*
 * PresenceSeat tracks live contact for one empire.
 *
 * connected means the TCP session / handshake is alive. Idle
 * policy while connected is AFK (last policy + optional
 * production shrink). suspended is an intentional client flag
 * (menu open / marked AFK): seat stays connected and
 * handshake_miss does not drop it. missLimitMs is how long
 * without handshake before drop when not suspended.
 * reconnectToken is opaque TOKEN_BYTES issued on allocate; empty
 * means the seat is free for a new empty-body allocate. Drop
 * clears connected but keeps the token until quit / game end.
 */
class PresenceSeat {
    int64 playerId
    bool connected
    bool suspended
    uint64 lastHandshakeMs
    uint64 missLimitMs
    buffer reconnectToken

    /*
     * Construct a disconnected presence seat.
     *
     * Purpose: pre-size the book with the handshake miss window.
     *
     * Parameters:
     *   seat — empire id.
     *   missMs — drop after this many ms without handshake.
     *
     * Returns: PresenceSeat with connected false, suspended false,
     * and an empty reconnect token.
     */
    PresenceSeat(int64 seat, uint64 missMs) {
        playerId = seat
        connected = false
        suspended = false
        lastHandshakeMs = 0u
        missLimitMs = missMs
        reconnectToken = buffer[]
    }
}

/*
 * PresenceBook owns handshake, drop detection, pause rules, and
 * opaque reconnect tokens.
 *
 * Does not store policy — that is PolicyTable. Call scanDrops with
 * the current clock before cadence fire. TOKEN_BYTES is the fixed
 * wire length for reconnect tokens (opaque; not printable).
 */
class PresenceBook {
    list seats
    uint64 defaultMissMs
    SeededRng tokenRng

    enum {
        TOKEN_BYTES = 16
    }

    /*
     * Construct an empty presence book.
     *
     * Purpose: fill via ensureSeats after State start.
     *
     * Parameters:
     *   missMs — default handshake miss window (milliseconds).
     *
     * Returns: PresenceBook with no seats and a seeded token RNG.
     */
    PresenceBook(uint64 missMs) {
        seats = []
        defaultMissMs = missMs
        # Deterministic stream so unit tests stay reproducible; the
        # seed advances on each mint via nextU64.
        tokenRng = SeededRng(0xc01a7e75u)
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
     * True when the seat is intentionally suspended (AFK flag).
     *
     * Purpose: status menu / tests; suspended seats skip
     * handshake_miss drop while remaining connected.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: suspended flag, or false when out of range.
     */
    bool isSuspended(int64 playerId) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        return(seat.suspended)
    }

    /*
     * Set or clear the intentional suspended / AFK flag.
     *
     * Purpose: client menu-open or human AFK mark. Marks the seat
     * connected and refreshes lastHandshakeMs so clearing the flag
     * restarts a full miss window. Does not itself drop or quit.
     *
     * Parameters:
     *   playerId — empire id.
     *   wantSuspended — true to hold the seat past handshake_miss.
     *   nowMs — current server clock (handshake refresh).
     *
     * Returns: true when the seat exists and was updated.
     */
    bool setSuspended(
        int64 playerId,
        bool wantSuspended,
        uint64 nowMs) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        seat.connected = true
        seat.suspended = wantSuspended
        seat.lastHandshakeMs = nowMs
        seats[playerId] = seat
        return(true)
    }

    /*
     * Force a drop (lost contact) on one seat.
     *
     * Purpose: TCP close / scanDrops path; last policy continues
     * for the live remainder. Clears suspended and connected but
     * keeps reconnectToken so the same client can reclaim.
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
        seat.suspended = false
        seats[playerId] = seat
        return(was)
    }

    /*
     * True when two opaque token buffers are byte-identical.
     *
     * Purpose: reclaim / keep-alive match without string codecs.
     *
     * Parameters:
     *   left — first token (may be empty).
     *   right — second token (may be empty).
     *
     * Returns: true when both have the same length and bytes.
     */
    bool tokensEqual(buffer left, buffer right) {
        if (left.length != right.length) {
            return(false)
        }
        int64 index = 0
        while (index < left.length) {
            if (left[index] != right[index]) {
                return(false)
            }
            index = index + 1
        }
        return(true)
    }

    /*
     * Mint a fresh TOKEN_BYTES opaque reconnect token.
     *
     * Purpose: issue on allocate so only the holder can reclaim
     * after drop. Not cryptographic — live-process opacity only.
     *
     * Parameters: none (advances tokenRng).
     *
     * Returns: buffer of length TOKEN_BYTES.
     */
    buffer mintToken() {
        buffer token = buffer[]
        while (token.length < TOKEN_BYTES) {
            token.append(int64(tokenRng.nextBounded(256u)))
        }
        return(token)
    }

    /*
     * Store a reconnect token on a seat (allocate path).
     *
     * Purpose: bind the opaque token issued in the handshake ack.
     *
     * Parameters:
     *   playerId — empire id.
     *   token — TOKEN_BYTES opaque bytes.
     *
     * Returns: true when the seat exists and token was stored.
     */
    bool setReconnectToken(int64 playerId, buffer token) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        if (token.length != TOKEN_BYTES) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        seat.reconnectToken = token
        seats[playerId] = seat
        return(true)
    }

    /*
     * Clear the reconnect token (quit / game-end path).
     *
     * Purpose: seat is no longer reclaimable; a later empty
     * handshake may treat it as free only when also not quit.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when the seat exists.
     */
    bool clearReconnectToken(int64 playerId) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        seat.reconnectToken = buffer[]
        seats[playerId] = seat
        return(true)
    }

    /*
     * Copy the reconnect token for a seat (ack / client store).
     *
     * Purpose: handshake response trailing TOKEN_BYTES.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: token copy, or empty when missing / out of range.
     */
    buffer reconnectToken(int64 playerId) {
        buffer empty = buffer[]
        if (playerId < 0 or playerId >= seats.length) {
            return(empty)
        }
        PresenceSeat seat = seats[playerId]
        buffer out = buffer[]
        int64 index = 0
        while (index < seat.reconnectToken.length) {
            out.append(seat.reconnectToken[index])
            index = index + 1
        }
        return(out)
    }

    /*
     * True when the seat holds an outstanding reclaim token.
     *
     * Purpose: empty allocate must not steal token-held seats.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when token length is TOKEN_BYTES.
     */
    bool hasReconnectToken(int64 playerId) {
        if (playerId < 0 or playerId >= seats.length) {
            return(false)
        }
        PresenceSeat seat = seats[playerId]
        return(seat.reconnectToken.length == TOKEN_BYTES)
    }

    /*
     * Find the seat that owns this reconnect token.
     *
     * Purpose: reclaim path — client sends token, not playerId.
     *
     * Parameters:
     *   token — opaque TOKEN_BYTES from the client.
     *
     * Returns: seat id, or -1 when unknown / wrong length.
     */
    int64 findSeatByToken(buffer token) {
        if (token.length != TOKEN_BYTES) {
            return(-1)
        }
        int64 index = 0
        while (index < seats.length) {
            PresenceSeat seat = seats[index]
            if (tokensEqual(seat.reconnectToken, token)) {
                return(seat.playerId)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Drop seats whose handshake is older than missLimitMs.
     *
     * Purpose: distinguish AFK (connected, idle policy — including
     * intentional suspended) from drop (lost contact). Suspended
     * seats are skipped so menu-open / marked-AFK clients are not
     * handshake_miss dropped. Appends dropped player ids to outIds.
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
            if (seat.connected and not seat.suspended) {
                uint64 age = nowMs - seat.lastHandshakeMs
                if (nowMs < seat.lastHandshakeMs
                    or age >= seat.missLimitMs) {
                    seat.connected = false
                    seat.suspended = false
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
