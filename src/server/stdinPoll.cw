/*
 * src/server/stdinPoll.cw — Cwhip binding for non-blocking stdin poll.
 *
 * Wraps native cplanets_stdin_pending so the serve loop can detect an
 * operator line without blocking TCP accept forever.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial StdinPoll binding.
 */

/*
 * StdinPoll exposes a zero-timeout readiness check on stdin.
 *
 * Construct a throwaway instance and call pending() between accept
 * cycles. Does not consume input; the caller still uses StandardIO
 * readLine when pending is true.
 */
class StdinPoll {
    /*
     * Construct the poll helper.
     *
     * Purpose: host the native pending() binding (no instance state).
     *
     * Parameters: none.
     *
     * Returns: StdinPoll instance.
     */
    StdinPoll() {
    }

    /*
     * True when stdin has at least one byte ready (non-blocking).
     *
     * Purpose: serve-loop stdin watcher without blocking accept.
     *
     * Parameters: none.
     *
     * Returns: true when poll(POLLIN) on stdin succeeds with data.
     */
    bool pending()
}

bool StdinPoll.pending() from "cplanets_stdin_pending"
