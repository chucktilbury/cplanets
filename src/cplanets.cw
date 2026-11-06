/*
 * src/cplanets.cw — human GTK list debugger (Phase G).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --config PATH: load human settings (not AI config).
 * --once: fill a closed galaxy in-process and print lists (no TCP,
 * no GTK). --pull: TCP GET state+digest summary. --gui / --test:
 * GTK notebook (planets, fleets, digest, policy) + explored dialog.
 * Never ticks; never opens the universe DB (RULES §2 / PLAN §4.G).
 * No map canvas / DrawingArea (PLAN §4.I).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase G: list debugger, TCP, GTK panes.
 */

import gtk
import system as Sys

include "lib/machine.cw"
include "lib/state.cw"
include "server/policyTable.cw"
include "client/appCore.cw"
include "client/config.cw"
include "client/configParse.cw"
include "client/guiMain.cw"

/*
 * HumanMain parses argv and runs smoke, once, pull, or GUI modes.
 */
class HumanMain {
    /*
     * Construct the entry helper.
     *
     * Purpose: host argv parsing without free functions.
     *
     * Parameters: none.
     *
     * Returns: HumanMain instance.
     */
    HumanMain() {
    }

    /*
     * Print the smoke identity lines.
     *
     * Purpose: keep smoke_cplanets green (name + lib id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSmoke() {
        Machine machine = Machine()
        print("cplanets\n")
        print(machine.identity())
        print("\n")
    }

    /*
     * Read a string flag value following a name, or default.
     *
     * Purpose: parse --config / --host without Cli.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--config".
     *   fallback — value when missing.
     *
     * Returns: next argv token or fallback.
     */
    String flagString(list args, String name, String fallback) {
        int64 index = 1
        while (index + 1 < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                return(args[index + 1])
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * Read an int64 flag value following a name, or default.
     *
     * Purpose: parse --port.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--port".
     *   fallback — value when missing / bad.
     *
     * Returns: parsed int64 or fallback.
     */
    int64 flagInt(list args, String name, int64 fallback) {
        int64 index = 1
        while (index + 1 < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                String text = args[index + 1]
                return(text.toInt64())
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * True when argv contains a bare flag name.
     *
     * Purpose: gate --once / --pull / --gui / --test.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--once".
     *
     * Returns: true when present.
     */
    bool hasFlag(list args, String name) {
        int64 index = 1
        while (index < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Load HumanConfig from --config path with host/port overlays.
     *
     * Purpose: own settings file; argv may override dial.
     *
     * Parameters:
     *   args — argv list.
     *
     * Returns: clamped HumanConfig (defaults when no --config).
     */
    HumanConfig loadConfig(list args) {
        String path = flagString(args, "--config", "")
        HumanConfig cfg = HumanConfig()
        if (path.length > 0) {
            Sys.File input = Sys.File(path, "r")
            String text = input.readAll()
            input.close()
            HumanConfigParse parser = HumanConfigParse()
            cfg = parser.parseText(text)
        }
        String host = flagString(args, "--host", "")
        if (host.length > 0) {
            cfg.host = host
        }
        int64 port = flagInt(args, "--port", -1)
        if (port >= 0) {
            cfg.port = port
        }
        int64 seat = flagInt(args, "--player", -1)
        if (seat >= 0) {
            cfg.playerId = seat
        }
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Fill an in-process closed galaxy and print list summary.
     *
     * Purpose: --once path without TCP or display.
     *
     * Parameters:
     *   cfg — loaded human config (seat selects visibility).
     *
     * Returns: nothing.
     */
    void runOnce(HumanConfig cfg) {
        State game = State()
        game.startClosed(11u, 2)
        if (cfg.playerId < game.players.length) {
            Player seat = game.players[cfg.playerId]
            seat.human = true
        }
        PolicyTable policies = PolicyTable()
        policies.ensureSeats(game.players.length)
        AppCore core = AppCore(cfg)
        core.fillFromGame(game, policies)
        core.printSummary()
    }

    /*
     * Dial the server and print GET state + digest summary.
     *
     * Purpose: --pull without GTK.
     *
     * Parameters:
     *   cfg — loaded human config with host/port.
     *
     * Returns: nothing.
     */
    void runPull(HumanConfig cfg) {
        AppCore core = AppCore(cfg)
        if (not core.pullRemote()) {
            print("cplanets\n")
            print("pull_failed\n")
            return()
        }
        core.printSummary()
    }

    /*
     * Run the GTK list debugger.
     *
     * Purpose: --gui / --test. Prefills from in-process galaxy
     * when offline; pulls when port > 0.
     *
     * Parameters:
     *   cfg — loaded human config.
     *   testMode — auto-quit after a short schedule.
     *
     * Returns: nothing.
     */
    void runGui(HumanConfig cfg, bool testMode) {
        AppCore core = AppCore(cfg)
        if (cfg.port > 0) {
            core.pullRemote()
        } else {
            State game = State()
            game.startClosed(11u, 2)
            PolicyTable policies = PolicyTable()
            policies.ensureSeats(game.players.length)
            core.fillFromGame(game, policies)
        }
        Gtk.Application app = Gtk.Application("org.cplanets.Client")
        GuiMain gui = GuiMain(core)
        gui.testMode = testMode
        gui.activateAction = gui.activate
        gui.refreshAction = gui.onRefresh
        gui.applyAction = gui.onApply
        gui.closeAction = gui.onClose
        gui.dialogCloseAction = gui.onDialogClose
        gui.showExploredAction = gui.showFirstExplored
        gui.testAction = gui.onTest
        app.onActivate(gui.activateAction)
        app.run()
        app.shutdown()
    }

    /*
     * Dispatch smoke / once / pull / gui from argv.
     *
     * Purpose: single entry used by start {}.
     *
     * Parameters:
     *   args — Sys.Process argv.
     *
     * Returns: nothing.
     */
    void run(list args) {
        bool wantConfig = hasFlag(args, "--config")
        bool wantOnce = hasFlag(args, "--once")
        bool wantPull = hasFlag(args, "--pull")
        bool wantGui = hasFlag(args, "--gui")
        bool wantTest = hasFlag(args, "--test")
        if (not wantConfig and not wantOnce and not wantPull
            and not wantGui and not wantTest) {
            printSmoke()
            return()
        }
        HumanConfig cfg = loadConfig(args)
        if (wantGui or wantTest) {
            runGui(cfg, wantTest)
            return()
        }
        if (wantPull and cfg.port > 0) {
            runPull(cfg)
            return()
        }
        runOnce(cfg)
    }
}

start {
    Sys.Process proc = Sys.Process()
    HumanMain main = HumanMain()
    main.run(proc.argv())
}
