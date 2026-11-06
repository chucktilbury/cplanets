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
 * User-facing argv uses stdlib `cli` (including --help / -h).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase G: list debugger, TCP, GTK panes.
 *   2026-11-06  TUNING B: wire pause / dispatch / recall actions.
 *   2026-11-06  Migrate argv to stdlib cli (+ generated --help).
 */

import cli as Cli
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
 * HumanMain parses argv via Cli and runs smoke, once, pull, or GUI.
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
     * Build the registered Cli.CommandLine for this binary.
     *
     * Purpose: declare every operator flag once so parseArgv and
     * helpText stay in sync (stdlib cli).
     *
     * Parameters: none.
     *
     * Returns: configured CommandLine (not yet parsed).
     */
    Cli.CommandLine buildCli() {
        Cli.CommandLine commandLine = Cli.CommandLine(
            "cplanets",
            "CPlanets human list debugger (never ticks).",
            "0.1.0")
        Cli.Option help = Cli.Option()
        help.shortName = "h"
        help.longName = "help"
        help.name = "help"
        help.description = "show this help"
        help.action = Cli.Action().HELP
        commandLine.addOption(help)
        Cli.Option config = Cli.Option()
        config.longName = "config"
        config.name = "config"
        config.description = "human settings file (not AI config)"
        config.valueType = Cli.ValueType().STRING
        commandLine.addOption(config)
        Cli.Option host = Cli.Option()
        host.longName = "host"
        host.name = "host"
        host.description = "override dial host"
        host.valueType = Cli.ValueType().STRING
        commandLine.addOption(host)
        Cli.Option port = Cli.Option()
        port.longName = "port"
        port.name = "port"
        port.description = "override dial port (> 0 for TCP)"
        port.valueType = Cli.ValueType().NUMBER
        commandLine.addOption(port)
        Cli.Option player = Cli.Option()
        player.longName = "player"
        player.name = "player"
        player.description = "seat id"
        player.valueType = Cli.ValueType().NUMBER
        commandLine.addOption(player)
        Cli.Option once = Cli.Option()
        once.longName = "once"
        once.name = "once"
        once.description = "in-process closed galaxy; print lists"
        once.valueType = Cli.ValueType().FLAG
        commandLine.addOption(once)
        Cli.Option pull = Cli.Option()
        pull.longName = "pull"
        pull.name = "pull"
        pull.description = "TCP GET state + digest summary"
        pull.valueType = Cli.ValueType().FLAG
        commandLine.addOption(pull)
        Cli.Option gui = Cli.Option()
        gui.longName = "gui"
        gui.name = "gui"
        gui.description = "GTK notebook debugger"
        gui.valueType = Cli.ValueType().FLAG
        commandLine.addOption(gui)
        Cli.Option test = Cli.Option()
        test.longName = "test"
        test.name = "test"
        test.description = "GTK path that auto-quits (test mode)"
        test.valueType = Cli.ValueType().FLAG
        commandLine.addOption(test)
        return(commandLine)
    }

    /*
     * Parse argv; print help or an error and exit when needed.
     *
     * Purpose: single parse path; unknown flags fail loud.
     *
     * Parameters:
     *   commandLine — registered CommandLine from buildCli().
     *
     * Returns: true when the caller should continue; false when this
     * method already exited the process (help / parse error).
     */
    bool parseOrExit(Cli.CommandLine commandLine) {
        String problem = ""
        try {
            commandLine.parseArgv()
        } except() as error {
            problem = format("{}", error)
        }
        if (commandLine.currentAction() == Cli.Action().HELP) {
            print(commandLine.helpText())
            Sys.Process().exit(0)
            return(false)
        }
        if (problem.length > 0) {
            print(format("cplanets: {}\n", problem))
            print("Try 'cplanets --help' for usage.\n")
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Load HumanConfig from --config with host/port/player overlays.
     *
     * Purpose: own settings file; argv may override dial / seat.
     * Overlays apply only when the option was provided.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: clamped HumanConfig (defaults when no --config).
     */
    HumanConfig loadConfig(Cli.CommandLine commandLine) {
        HumanConfig cfg = HumanConfig()
        if (commandLine.wasProvided("config")) {
            String path = commandLine.value("config")
            if (path.length > 0) {
                Sys.File input = Sys.File(path, "r")
                String text = input.readAll()
                input.close()
                HumanConfigParse parser = HumanConfigParse()
                cfg = parser.parseText(text)
            }
        }
        if (commandLine.wasProvided("host")) {
            String host = commandLine.value("host")
            if (host.length > 0) {
                cfg.host = host
            }
        }
        if (commandLine.wasProvided("port")) {
            int64 port = commandLine.value("port").toInt64()
            if (port >= 0) {
                cfg.port = port
            }
        }
        if (commandLine.wasProvided("player")) {
            int64 seat = commandLine.value("player").toInt64()
            if (seat >= 0) {
                cfg.playerId = seat
            }
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
        gui.dispatchAction = gui.onDispatch
        gui.recallAction = gui.onRecall
        gui.pauseAction = gui.onPauseToggled
        gui.testAction = gui.onTest
        app.onActivate(gui.activateAction)
        app.run()
        app.shutdown()
    }

    /*
     * Dispatch smoke / once / pull / gui from a parsed CommandLine.
     *
     * Purpose: single entry used by start {}. Smoke when no mode
     * flags; gui/test beat pull; pull needs port > 0.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
        bool wantConfig = commandLine.wasProvided("config")
        bool wantOnce = commandLine.switchValue("once")
        bool wantPull = commandLine.switchValue("pull")
        bool wantGui = commandLine.switchValue("gui")
        bool wantTest = commandLine.switchValue("test")
        if (not wantConfig and not wantOnce and not wantPull
            and not wantGui and not wantTest) {
            printSmoke()
            return()
        }
        HumanConfig cfg = loadConfig(commandLine)
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
    HumanMain main = HumanMain()
    Cli.CommandLine commandLine = main.buildCli()
    if (main.parseOrExit(commandLine)) {
        main.run(commandLine)
    }
}
