/*
 * src/cplanets.cw — human GTK client (Phase G + I map).
 *
 * --config PATH is optional. When omitted, use (and create if
 * missing) ~/.config/cplanets/human.cfg (CPL-115). Explicit empty
 * --config still prints help and exits 2.
 * --once: fill a closed galaxy in-process and print lists (no TCP,
 * no GTK). --pull: TCP GET state+digest summary. --gui / --test:
 * GTK map canvas + top-level menubar panel dialogs (planets,
 * fleets, ships, digest, policy) + explored dialog. Never ticks;
 * never opens the universe DB (RULES §2 / PLAN §4.G / §4.I).
 * User-facing argv uses stdlib `cli` (including --help / -h).
 * With all modes false from file/argv, prints smoke identity.
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
 *   2026-11-07  Wire Ships tab design / build / reclaim actions.
 *   2026-11-07  Config defaults for every CLI flag but --config.
 *   2026-11-07  --config mandatory; missing prints help, exit 2.
 *   2026-11-07  Phase I: map canvas panel in --gui / --test.
 *   2026-11-07  Wire budget + compose Send actions.
 *   2026-11-07  Map pick-to-dispatch + ContextMenu budget.
 *   2026-11-07  Connect failure: print host:port; exit 1;
 *               GUI AlertDialog (no silent empty session).
 *   2026-11-08  Wire AFK CheckButton → PUT /suspended.
 *   2026-11-08  --player is offline-only; TCP seats from handshake.
 *   2026-11-09  Wire fleet / design Examine dialog actions.
 *   2026-11-09  View-menu panel dialogs (GuiPanelHost).
 *   2026-11-09  Panel openers → top-level menubar (not View).
 *   2026-11-09  Wire GUI presence keep-alive action.
 *   2026-11-09  refresh_ms / --refresh-ms GUI state+digest poll.
 *   2026-11-10  Wire CPL-101 create fleet / assign / reclaim-stock.
 *   2026-11-11  CPL-115: XDG default human.cfg when --config omitted.
 */

import cli as Cli
import gtk
import system as Sys

include "lib/machine.cw"
include "lib/state.cw"
include "lib/xdgDefaults.cw"
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
        config.description = (
            "human settings (default: ~/.config/cplanets/human.cfg)")
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
        player.description = (
            "offline seat id (--once / port 0); TCP seats are server-assigned on handshake")
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
        Cli.Option refreshMs = Cli.Option()
        refreshMs.longName = "refresh-ms"
        refreshMs.name = "refresh-ms"
        refreshMs.description = (
            "GUI GET /state+/digest poll ms (0=off; config refresh_ms)")
        refreshMs.valueType = Cli.ValueType().NUMBER
        refreshMs.hasDefault = true
        refreshMs.defaultValue = "1000"
        commandLine.addOption(refreshMs)
        return(commandLine)
    }

    /*
     * Parse argv; print help or an error and exit when needed.
     *
     * Purpose: single parse path; unknown flags fail loud.
     * --config may be omitted (XDG human.cfg); an explicit empty
     * value still prints help and exits 2.
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
        if (commandLine.wasProvided("config")
            and commandLine.value("config").length == 0) {
            print(commandLine.helpText())
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Resolve a FLAG option: file default unless argv provided.
     *
     * Purpose: silent CLI override of human config mode keys.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (once / pull / gui / test).
     *   fromFile — value from HumanConfig.
     *
     * Returns: switchValue when wasProvided, else fromFile.
     */
    bool resolveFlag(
        Cli.CommandLine commandLine,
        String name,
        bool fromFile) {
        if (commandLine.wasProvided(name)) {
            return(commandLine.switchValue(name))
        }
        return(fromFile)
    }

    /*
     * Load HumanConfig from --config or the XDG default pack.
     *
     * Purpose: own settings file; argv may override dial / seat /
     * mode flags / refresh_ms. Overlays apply only when the option
     * was provided. When --config is omitted, ensure and load
     * ~/.config/cplanets/human.cfg (creating the XDG pack when
     * missing). No GUI server-config dialog yet — file only.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: clamped HumanConfig from the file + argv overlays.
     */
    HumanConfig loadConfig(Cli.CommandLine commandLine) {
        HumanConfig cfg = HumanConfig()
        String path = resolveConfigPath(commandLine)
        Sys.File input = Sys.File(path, "r")
        String text = input.readAll()
        input.close()
        HumanConfigParse parser = HumanConfigParse()
        cfg = parser.parseText(text)
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
        if (commandLine.wasProvided("once")) {
            cfg.once = commandLine.switchValue("once")
        }
        if (commandLine.wasProvided("pull")) {
            cfg.pull = commandLine.switchValue("pull")
        }
        if (commandLine.wasProvided("gui")) {
            cfg.gui = commandLine.switchValue("gui")
        }
        if (commandLine.wasProvided("test")) {
            cfg.test = commandLine.switchValue("test")
        }
        if (commandLine.wasProvided("refresh-ms")) {
            cfg.refreshMs = (
                commandLine.value("refresh-ms").toInt64())
        }
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Resolve the human config path (CLI or XDG default).
     *
     * Purpose: keep --config as an override; when omitted, seed
     * ~/.config/cplanets/ and return human.cfg.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: readable config path (exits 1 on XDG failure).
     */
    String resolveConfigPath(Cli.CommandLine commandLine) {
        if (commandLine.wasProvided("config")
            and commandLine.value("config").length > 0) {
            return(commandLine.value("config"))
        }
        XdgDefaults xdg = XdgDefaults()
        if (not xdg.ensureDefaults()) {
            print(format(
                "cplanets: cannot create default config: {}\n",
                xdg.lastError))
            Sys.Process().exit(1)
        }
        String path = xdg.humanConfigPath()
        if (path.length < 1) {
            print("cplanets: cannot resolve default config path\n")
            Sys.Process().exit(1)
        }
        print(format("cplanets: using default config {}\n", path))
        return(path)
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
        cfg.ensureOfflineSeat()
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
     * Purpose: --pull without GTK. Connect / pull failure prints
     * a clear host:port error and exits non-zero (never silent).
     *
     * Parameters:
     *   cfg — loaded human config with host/port.
     *
     * Returns: nothing (exits 1 on failure).
     */
    void runPull(HumanConfig cfg) {
        AppCore core = AppCore(cfg)
        if (not core.pullRemote()) {
            print(format("cplanets: {}\n", core.lastError))
            Sys.Process().exit(1)
            return()
        }
        core.printSummary()
    }

    /*
     * Run the GTK list debugger.
     *
     * Purpose: --gui / --test. Prefills from in-process galaxy
     * when offline (port 0); pulls when port > 0. A failed pull
     * sets GuiMain.startupError so activate shows AlertDialog.
     *
     * Parameters:
     *   cfg — loaded human config.
     *   testMode — auto-quit after a short schedule.
     *
     * Returns: nothing.
     */
    void runGui(HumanConfig cfg, bool testMode) {
        AppCore core = AppCore(cfg)
        String startupError = ""
        if (cfg.port > 0) {
            if (not core.pullRemote()) {
                startupError = core.lastError
                print(format("cplanets: {}\n", startupError))
            }
        } else {
            cfg.ensureOfflineSeat()
            State game = State()
            game.startClosed(11u, 2)
            PolicyTable policies = PolicyTable()
            policies.ensureSeats(game.players.length)
            core.fillFromGame(game, policies)
        }
        Gtk.Application app = Gtk.Application("org.cplanets.Client")
        GuiMain gui = GuiMain(core)
        gui.testMode = testMode
        gui.startupError = startupError
        gui.activateAction = gui.activate
        gui.refreshAction = gui.onRefresh
        gui.applyAction = gui.onApply
        gui.closeAction = gui.onClose
        gui.dialogCloseAction = gui.onDialogClose
        gui.showExploredAction = gui.showFirstExplored
        gui.showMapExploredAction = gui.showMapExplored
        gui.examineFleetAction = gui.showFleetExamine
        gui.examineShipAction = gui.showShipExamine
        gui.createFleetAction = gui.onCreateFleet
        gui.assignAction = gui.onAssign
        gui.unassignAction = gui.onUnassign
        gui.dispatchAction = gui.onDispatch
        gui.recallAction = gui.onRecall
        gui.developAction = gui.onDevelop
        gui.buildAction = gui.onBuild
        gui.reclaimStockAction = gui.onReclaimStock
        gui.reclaimAction = gui.onReclaimHulls
        gui.budgetAction = gui.onBudget
        gui.sendAction = gui.onSendMessage
        gui.empireApplyAction = gui.onEmpireApply
        gui.pauseAction = gui.onPauseToggled
        gui.afkAction = gui.onAfkToggled
        gui.testAction = gui.onTest
        gui.keepAliveAction = gui.onPresenceKeepAlive
        gui.refreshPollAction = gui.onRefreshPoll
        gui.mapPickAction = gui.onMapPlanetPicked
        gui.mapDispatchAction = gui.onMapDispatchHere
        gui.mapBudgetAction = gui.onMapBudgetHere
        app.onActivate(gui.activateAction)
        app.run()
        app.shutdown()
    }

    /*
     * Dispatch smoke / once / pull / gui from a parsed CommandLine.
     *
     * Purpose: single entry used by start {}. --config may come
     * from argv or the XDG default. Mode defaults come from the
     * settings file; argv overrides silently. gui/test beat pull;
     * pull needs port > 0; once (or pull with port 0) prints lists;
     * all modes false → smoke identity.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
        HumanConfig cfg = loadConfig(commandLine)
        bool wantOnce = resolveFlag(commandLine, "once", cfg.once)
        bool wantPull = resolveFlag(commandLine, "pull", cfg.pull)
        bool wantGui = resolveFlag(commandLine, "gui", cfg.gui)
        bool wantTest = resolveFlag(commandLine, "test", cfg.test)
        if (wantGui or wantTest) {
            runGui(cfg, wantTest)
            return()
        }
        if (wantPull and cfg.port > 0) {
            runPull(cfg)
            return()
        }
        if (wantOnce or wantPull) {
            runOnce(cfg)
            return()
        }
        printSmoke()
    }
}

start {
    HumanMain main = HumanMain()
    Cli.CommandLine commandLine = main.buildCli()
    if (main.parseOrExit(commandLine)) {
        main.run(commandLine)
    }
}
