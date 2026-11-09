/*
 * src/server/serveMenuGate.cw — on-demand status menu during serve.
 *
 * Between accept cycles, polls stdin non-blocking. A lone `m` line
 * opens the read-only StatusMenu, forcing pause for a consistent
 * snapshot and restoring the prior pause flag when the operator quits
 * the menu with `q`. A lone `g` line leaves lobby (operator go) so
 * wall ticks may advance.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial serve-time menu gate (stdin m, pause-while-open).
 *   2026-11-08  Operator go via stdin `g` (lobby → running).
 *   2026-11-09  Drain stray/empty stdin lines so a junk key then m
 *               still opens the menu; blank Enter is not EOF.
 */

include "stdinPoll.cw"
include "statusMenu.cw"

/*
 * ServeMenuGate watches stdin during ServerListen.serve().
 *
 * Disabled until enable() binds live StatusViews. After stdin EOF,
 * further polls are skipped so a closed pipe cannot spin the menu.
 */
class ServeMenuGate {
    StatusViews views
    GameDriver driver
    bool enabled
    bool stdinEof
    Sys.StandardIO io
    StdinPoll poller

    /*
     * Construct a disabled gate (no-op until enable).
     *
     * Purpose: ServerListen can own a gate field before the server
     * wires views; tests leave it disabled.
     *
     * Parameters: none.
     *
     * Returns: ServeMenuGate with enabled=false.
     */
    ServeMenuGate() {
        views = null
        driver = null
        enabled = false
        stdinEof = false
        io = Sys.StandardIO()
        poller = StdinPoll()
    }

    /*
     * Bind live views/driver and start watching stdin for `m`.
     *
     * Purpose: cplanets-server --serve path; menu stays hidden until
     * the operator types m.
     *
     * Parameters:
     *   liveViews — StatusViews over the same GameDriver as serve.
     *   liveDriver — sole writer (pause flag mutated while menu open).
     *
     * Returns: nothing.
     */
    void enable(StatusViews liveViews, GameDriver liveDriver) {
        views = liveViews
        driver = liveDriver
        enabled = true
        stdinEof = false
    }

    /*
     * If stdin has lines, handle operator console commands.
     *
     * Purpose: non-blocking serve-thread watcher. Consumes every
     * complete line currently pending so a stray keystroke (or a
     * bare Enter) cannot sit ahead of a later `m`/`g` and permanently
     * disable the gate. `m` opens the status menu; `g` leaves lobby
     * (same go path as menu Go / PUT /admin/go). Unknown lines are
     * discarded with a one-line hint. Only a null readLine (true EOF)
     * sets stdinEof — empty/whitespace lines are ignored.
     *
     * Parameters: none.
     *
     * Returns: true when a command was handled (menu or go).
     */
    bool pollOnce() {
        if (not enabled or stdinEof or views == null or driver == null) {
            return(false)
        }
        if (not poller.pending()) {
            return(false)
        }
        bool handled = false
        bool hinted = false
        # Drain/process all complete lines ready now. Stop after m
        # (menu reads further stdin) or when the buffer is empty.
        while (poller.pending()) {
            String line = io.readLine()
            if (line == null) {
                stdinEof = true
                return(handled)
            }
            line = line.trim()
            if (line.length == 0) {
                # Bare Enter / whitespace — flush and keep watching.
                continue
            }
            if (line.equals("m") or line.equals("M")) {
                openMenuPaused()
                return(true)
            }
            if (line.equals("g") or line.equals("G")) {
                operatorGo()
                handled = true
                # Keep draining so a following m in the same burst
                # can still open the menu after go.
                continue
            }
            if (not hinted) {
                print("serve> unknown console line (type m = status ")
                print("menu, g = go / leave lobby; stray keys are ")
                print("flushed).\n")
                io.flush()
                hinted = true
            }
        }
        return(handled)
    }

    /*
     * Leave lobby via the shared go() path.
     *
     * Purpose: operator console `g`+Enter. Prints PHASE= lines so
     * harnesses and humans can see the transition.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void operatorGo() {
        bool changed = driver.go()
        if (changed) {
            print("GO=1\n")
            print("PHASE=running\n")
        } else (driver.running) {
            print("GO=0 (already running)\n")
            print("PHASE=running\n")
        } else {
            print("GO=0 (rejected)\n")
            print("PHASE=lobby\n")
        }
        io.flush()
    }

    /*
     * Pause ticks, run the read-only menu, restore prior pause.
     *
     * Purpose: consistent operator snapshot; clients can wait. Uses
     * the raw paused flag (not setPaused) so the menu works even when
     * the one-human pause chrome gate would reject. Lobby Go inside
     * the menu returns here after driver.go() so pause is restored
     * and wall ticks may advance — clients are not left held with
     * the menu still open.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void openMenuPaused() {
        bool priorPaused = driver.paused
        driver.paused = true
        driver.republishWithoutTick()
        print("MENU_OPEN=1 (ticks paused; q resumes prior pause; ")
        print("lobby g starts game and closes menu)\n")
        io.flush()
        StatusMenu menu = StatusMenu(views)
        menu.runInteractive()
        driver.paused = priorPaused
        driver.republishWithoutTick()
        print("MENU_OPEN=0\n")
        if (driver.running) {
            print("PHASE=running\n")
        } else {
            print("PHASE=lobby\n")
        }
        if (priorPaused) {
            print("PAUSE_RESTORED=1\n")
        } else {
            print("PAUSE_RESTORED=0\n")
        }
        io.flush()
        # Drop any type-ahead that arrived while the menu ran and was
        # not consumed as a prompt line, so the next poll sees a clean
        # console (stray key then m still works).
        flushPendingLines()
    }

    /*
     * Discard complete stdin lines that are already pending.
     *
     * Purpose: after the status menu closes (q or lobby g), clear
     * leftover type-ahead so the next operator `m`/`g` is not
     * shadowed by junk. Does not treat empty lines as EOF. Stops on
     * true EOF (null readLine) or when poll says nothing remains.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void flushPendingLines() {
        if (stdinEof) {
            return()
        }
        while (poller.pending()) {
            String line = io.readLine()
            if (line == null) {
                stdinEof = true
                return()
            }
            # Intentionally discard (including empty); keep draining.
        }
    }
}
