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
     * If stdin has a line, handle operator console commands.
     *
     * Purpose: non-blocking serve-thread watcher. `m` opens the
     * status menu; `g` leaves lobby (same go path as menu Go /
     * PUT /admin/go). Other lines print a short hint; EOF
     * disables further watches.
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
        String line = io.readLine()
        if (line == null) {
            stdinEof = true
            return(false)
        }
        line = line.trim()
        if (line.length == 0) {
            # poll said ready but no line → stdin EOF / closed pipe.
            stdinEof = true
            return(false)
        }
        if (line.equals("m") or line.equals("M")) {
            openMenuPaused()
            return(true)
        }
        if (line.equals("g") or line.equals("G")) {
            operatorGo()
            return(true)
        }
        print("serve> unknown console line (type m = status menu, ")
        print("g = go / leave lobby, or ignore).\n")
        io.flush()
        return(false)
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
     * the one-human pause chrome gate would reject.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void openMenuPaused() {
        bool priorPaused = driver.paused
        driver.paused = true
        driver.republishWithoutTick()
        print("MENU_OPEN=1 (ticks paused; q resumes prior pause)\n")
        io.flush()
        StatusMenu menu = StatusMenu(views)
        menu.runInteractive()
        driver.paused = priorPaused
        driver.republishWithoutTick()
        print("MENU_OPEN=0\n")
        if (priorPaused) {
            print("PAUSE_RESTORED=1\n")
        } else {
            print("PAUSE_RESTORED=0\n")
        }
        io.flush()
    }
}
