/*
 * src/ai/menuGate.cw — on-demand status menu during AI serve-loop.
 *
 * Between decision cycles, polls stdin non-blocking. A lone `m`
 * line opens the read-only AiStatusMenu, forcing decisionPaused
 * for a consistent client view and clearing it when the operator
 * quits with `q`. Reuses server StdinPoll native binding.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI serve-loop menu gate (stdin m, pause).
 */

include "../server/stdinPoll.cw"
include "exploreState.cw"
include "statusMenu.cw"
include "statusViews.cw"

/*
 * AiMenuGate watches stdin during AiMain.runLoop().
 *
 * Disabled until enable() binds live explore state. After stdin
 * EOF, further polls are skipped so a closed pipe cannot spin.
 */
class AiMenuGate {
    AiExploreState state
    bool enabled
    bool stdinEof
    Sys.StandardIO io
    StdinPoll poller

    /*
     * Construct a disabled gate (no-op until enable).
     *
     * Purpose: AiClient / AiMain can own a gate field before the
     * serve-loop wires explore state; tests leave it disabled.
     *
     * Parameters: none.
     *
     * Returns: AiMenuGate with enabled=false.
     */
    AiMenuGate() {
        state = null
        enabled = false
        stdinEof = false
        io = Sys.StandardIO()
        poller = StdinPoll()
    }

    /*
     * Bind live explore state and start watching stdin for `m`.
     *
     * Purpose: cplanets-ai --serve-loop path; menu stays hidden
     * until the operator types m.
     *
     * Parameters:
     *   live — AiExploreState shared with AiClient.
     *
     * Returns: nothing.
     */
    void enable(AiExploreState live) {
        state = live
        enabled = true
        stdinEof = false
    }

    /*
     * If stdin has a line and it is `m`, open the status menu.
     *
     * Purpose: non-blocking serve-loop watcher. Other lines print
     * a short hint; EOF disables further watches.
     *
     * Parameters: none.
     *
     * Returns: true when the menu ran (decisions were paused).
     */
    bool pollOnce() {
        if (not enabled or stdinEof or state == null) {
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
        print("ai> unknown console line (type m then Enter ")
        print("for status menu, or ignore).\n")
        io.flush()
        return(false)
    }

    /*
     * Pause decisions, run the read-only menu, clear pause.
     *
     * Purpose: consistent operator snapshot of client knowledge.
     * The serve-loop skips maybePutPolicy while decisionPaused
     * is true; this method blocks in the menu until q / EOF.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void openMenuPaused() {
        state.decisionPaused = true
        print("MENU_OPEN=1 (AI decisions paused; q resumes)\n")
        io.flush()
        AiStatusViews views = AiStatusViews(state)
        AiStatusMenu menu = AiStatusMenu(views)
        menu.runInteractive()
        state.decisionPaused = false
        print("MENU_OPEN=0\n")
        io.flush()
    }
}
