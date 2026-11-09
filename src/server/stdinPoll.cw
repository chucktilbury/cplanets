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
 *   2026-11-09  pending() also true for stdio-buffered bytes after
 *               a prior readLine (shared hook for serve/AI gates).
 */

/*
 * StdinPoll exposes a zero-timeout readiness check on stdin.
 *
 * Construct a throwaway instance and call pending() between accept
 * cycles. Does not consume input; the caller still uses StandardIO
 * readLine when pending is true. pending() covers both kernel POLLIN
 * and bytes already sitting in the stdio FILE buffer so a drain loop
 * can keep reading after the first line of a piped burst.
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
     * After one readLine(), later pipe lines often live only in the
     * stdio buffer while poll(2) is idle — this still returns true
     * so ServeMenuGate can drain through to a following `m`.
     *
     * Parameters: none.
     *
     * Returns: true when poll(POLLIN) fires or stdio can yield a byte
     * without blocking.
     */
    bool pending()
}

bool StdinPoll.pending() from "cplanets_stdin_pending"
