/*
 * src/ai/menuGate.cw — on-demand status menu during AI serve-loop.
 *
 * Between decision cycles, polls stdin non-blocking. A lone `m`
 * line opens the read-only AiStatusMenu, forcing decisionPaused
 * for a consistent client view and clearing it when the operator
 * quits with `q`. On open, PUT /suspended=1 so handshake_miss
 * does not drop the seat while decisions pause; on close, clear
 * the flag. Reuses server StdinPoll native binding.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI serve-loop menu gate (stdin m, pause).
 *   2026-11-08  Menu open/close sends PUT /suspended.
 */

include "../server/stdinPoll.cw"
include "client.cw"
include "exploreState.cw"
include "statusMenu.cw"
include "statusViews.cw"

/*
 * AiMenuGate watches stdin during AiMain.runLoop().
 *
 * Disabled until enable() binds live explore state and client.
 * After stdin EOF, further polls are skipped so a closed pipe
 * cannot spin.
 */
class AiMenuGate {
    AiExploreState state
    AiClient client
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
        client = null
        enabled = false
        stdinEof = false
        io = Sys.StandardIO()
        poller = StdinPoll()
    }

    /*
     * Bind live explore state + client and start watching stdin.
     *
     * Purpose: cplanets-ai --serve-loop path; menu stays hidden
     * until the operator types m. Client is used for PUT
     * /suspended around the menu.
     *
     * Parameters:
     *   live — AiExploreState shared with AiClient.
     *   liveClient — AiClient for presence suspended flag.
     *
     * Returns: nothing.
     */
    void enable(AiExploreState live, AiClient liveClient) {
        state = live
        client = liveClient
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
     * Suspend presence, pause decisions, run menu, then clear.
     *
     * Purpose: consistent operator snapshot of client knowledge.
     * The serve-loop skips maybePutPolicy while decisionPaused
     * is true; PUT /suspended holds the seat past handshake_miss
     * while the menu blocks. Clears suspended when q / EOF.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void openMenuPaused() {
        if (client != null) {
            client.putSuspended(true)
        }
        state.decisionPaused = true
        print("MENU_OPEN=1 (AI decisions paused; suspended=1; ")
        print("q resumes)\n")
        io.flush()
        AiStatusViews views = AiStatusViews(state)
        AiStatusMenu menu = AiStatusMenu(views)
        menu.runInteractive()
        state.decisionPaused = false
        if (client != null) {
            client.putSuspended(false)
        }
        print("MENU_OPEN=0 (suspended=0)\n")
        io.flush()
    }
}
