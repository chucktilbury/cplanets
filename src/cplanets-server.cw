/*
 * src/cplanets-server.cw — server executable (Phase F / TUNING A).
 *
 * --config PATH is mandatory (process/network defaults; not the
 * scenario). Missing or empty path prints help and exits 2.
 * --serve [--host ADDR] [--port N] [--players N] [--seed N]
 * [--setup PATH] [--verbosity N] [--injectable] [--cycles N]:
 * bind TCP and run accept + cadence. While serving, stdin line `m`
 * opens the read-only in-process status console on the same State
 * (ticks pause while the menu is open). Verbosity is 0–10 (clamped;
 * stdout). Stand-alone and online share this driver (RULES §2 /
 * PLAN §4.F). Knob edits take effect on process restart (no mid-game
 * retune). User-facing argv uses stdlib `cli` (including --help / -h).
 * With serve=false from file/argv, prints smoke identity (name + lib).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase F: TCP serve + injectable driver entry.
 *   2026-11-06  --setup PATH + --seed; fail loud on bad setup.
 *   2026-11-06  Migrate argv to stdlib cli (+ generated --help).
 *   2026-11-07  --verbosity N (overlay setup verbosity key).
 *   2026-11-07  Verbosity scale 0–10; clamp out-of-range.
 *   2026-11-07  Process keys in setup; CLI silent overlay.
 *   2026-11-07  --config server runtime file; --setup scenario only.
 *   2026-11-07  --config mandatory; missing prints help, exit 2.
 *   2026-11-07  handshake_miss_ms / accept_poll_ms from server cfg.
 *   2026-11-07  CLI port help default 7700 (0 still ephemeral).
 *   2026-11-08  --menu read-only status console (pause-and-inspect).
 *   2026-11-08  Drop --menu; on-demand status via stdin m while serving.
 *   2026-11-08  Lobby until operator go (stdin g); reconnect tokens.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"
include "lib/setupParse.cw"
include "lib/state.cw"
include "server/config.cw"
include "server/configParse.cw"
include "server/driver.cw"
include "server/handler.cw"
include "server/listen.cw"
include "server/statusViews.cw"

/*
 * ServerMain parses argv via Cli and runs smoke or serve mode.
 *
 * Kept as a class so method comments stay with the entry logic
 * (CODING.md).
 */
class ServerMain {
    /*
     * Construct the entry helper.
     *
     * Purpose: host argv parsing without free functions.
     *
     * Parameters: none.
     *
     * Returns: ServerMain instance.
     */
    ServerMain() {
    }

    /*
     * Print the smoke identity lines and exit path.
     *
     * Purpose: keep smoke_cplanets-server green (name + lib id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSmoke() {
        Machine machine = Machine()
        print("cplanets-server\n")
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
            "cplanets-server",
            "CPlanets galaxy server (sole writer; TCP + tick cadence).",
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
            "required: server runtime config (not the scenario)")
        config.valueType = Cli.ValueType().STRING
        commandLine.addOption(config)
        Cli.Option serve = Cli.Option()
        serve.longName = "serve"
        serve.name = "serve"
        serve.description = (
            "bind TCP; lobby until g=go; m=status menu")
        serve.valueType = Cli.ValueType().FLAG
        commandLine.addOption(serve)
        Cli.Option host = Cli.Option()
        host.longName = "host"
        host.name = "host"
        host.description = (
            "listen bind address (config key host/address)")
        host.valueType = Cli.ValueType().STRING
        host.hasDefault = true
        host.defaultValue = "127.0.0.1"
        commandLine.addOption(host)
        Cli.Option port = Cli.Option()
        port.longName = "port"
        port.name = "port"
        port.description = (
            "listen port (sample 7700; 0 = ephemeral)")
        port.valueType = Cli.ValueType().NUMBER
        port.hasDefault = true
        port.defaultValue = "7700"
        commandLine.addOption(port)
        Cli.Option players = Cli.Option()
        players.longName = "players"
        players.name = "players"
        players.description = "seat count for the closed start galaxy"
        players.valueType = Cli.ValueType().NUMBER
        players.hasDefault = true
        players.defaultValue = "2"
        commandLine.addOption(players)
        Cli.Option seed = Cli.Option()
        seed.longName = "seed"
        seed.name = "seed"
        seed.description = "PRNG seed for the start galaxy"
        seed.valueType = Cli.ValueType().NUMBER
        seed.hasDefault = true
        seed.defaultValue = "7"
        commandLine.addOption(seed)
        Cli.Option setup = Cli.Option()
        setup.longName = "setup"
        setup.name = "setup"
        setup.description = (
            "scenario file (§14 knobs); overlays config setup key")
        setup.valueType = Cli.ValueType().STRING
        setup.hasDefault = true
        setup.defaultValue = ""
        commandLine.addOption(setup)
        Cli.Option injectable = Cli.Option()
        injectable.longName = "injectable"
        injectable.name = "injectable"
        injectable.description = "test clock (admin advance)"
        injectable.valueType = Cli.ValueType().FLAG
        commandLine.addOption(injectable)
        Cli.Option cycles = Cli.Option()
        cycles.longName = "cycles"
        cycles.name = "cycles"
        cycles.description = "cap accept/serve iterations (0 = until stop)"
        cycles.valueType = Cli.ValueType().NUMBER
        cycles.hasDefault = true
        cycles.defaultValue = "0"
        commandLine.addOption(cycles)
        Cli.Option verbosity = Cli.Option()
        verbosity.longName = "verbosity"
        verbosity.name = "verbosity"
        verbosity.description = (
            "stdout log level 0-10 (0 errors, 3 settings, 6 combat, 10 full; clamped)")
        verbosity.valueType = Cli.ValueType().NUMBER
        verbosity.hasDefault = true
        verbosity.defaultValue = "0"
        commandLine.addOption(verbosity)
        return(commandLine)
    }

    /*
     * Parse argv; print help or an error and exit when needed.
     *
     * Purpose: single parse path for smoke and serve; unknown flags
     * fail loud via stdlib cli. --config PATH is mandatory (non-empty);
     * missing path prints the same help as -h and exits 2.
     *
     * Parameters:
     *   commandLine — registered CommandLine from buildCli().
     *
     * Returns: true when the caller should continue; false when this
     * method already exited the process (help / parse / missing config).
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
            print(format("cplanets-server: {}\n", problem))
            print("Try 'cplanets-server --help' for usage.\n")
            Sys.Process().exit(2)
            return(false)
        }
        if (not commandLine.wasProvided("config")
            or commandLine.value("config").length == 0) {
            print(commandLine.helpText())
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Resolve an int64 option: file default unless argv provided.
     *
     * Purpose: silent CLI override of server config keys.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (port / players / seed / cycles / verbosity).
     *   fromFile — value from ServerConfig (or CLI default).
     *
     * Returns: argv value when wasProvided, else fromFile.
     */
    int64 resolveInt(
        Cli.CommandLine commandLine,
        String name,
        int64 fromFile) {
        if (commandLine.wasProvided(name)) {
            return(commandLine.value(name).toInt64())
        }
        return(fromFile)
    }

    /*
     * Resolve a FLAG option: file default unless argv provided.
     *
     * Purpose: silent CLI override of server config bool keys.
     * Presence of the flag on argv forces true (stdlib FLAG).
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (serve / injectable).
     *   fromFile — value from ServerConfig.
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
     * Load ServerConfig from required --config; overlay every CLI
     * flag but path.
     *
     * Purpose: process/network defaults live in the server config
     * file (like AI/human). --config PATH is the only flag with no
     * in-file key. --setup overlays the setup key when provided.
     * Unknown config keys fail loud and exit(1). Caller already
     * required a non-empty --config path.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: clamped ServerConfig from the file + argv overlays.
     */
    ServerConfig loadConfig(Cli.CommandLine commandLine) {
        ServerConfig cfg = ServerConfig()
        String path = commandLine.value("config")
        Sys.File input = Sys.File(path, "r")
        String text = input.readAll()
        input.close()
        ServerConfigParse parser = ServerConfigParse()
        cfg = parser.parseText(text)
        if (not parser.ok) {
            print("cplanets-server: config error: ")
            print(parser.lastError)
            print("\n")
            Sys.Process().exit(1)
        }
        if (commandLine.wasProvided("setup")) {
            cfg.setup = commandLine.value("setup")
        }
        if (commandLine.wasProvided("host")) {
            String host = commandLine.value("host")
            if (host.length > 0) {
                cfg.host = host
            }
        }
        cfg.port = resolveInt(commandLine, "port", cfg.port)
        cfg.players = resolveInt(commandLine, "players", cfg.players)
        cfg.seed = resolveInt(commandLine, "seed", cfg.seed)
        cfg.cycles = resolveInt(commandLine, "cycles", cfg.cycles)
        cfg.verbosity = resolveInt(
            commandLine, "verbosity", cfg.verbosity)
        cfg.serve = resolveFlag(commandLine, "serve", cfg.serve)
        cfg.injectable = resolveFlag(
            commandLine, "injectable", cfg.injectable)
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Load scenario text and start a State for serve.
     *
     * Purpose: one authoritative world bootstrap for --serve.
     *
     * Parameters:
     *   cfg — clamped ServerConfig (setup / seed / players /
     *         verbosity already overlaid).
     *
     * Returns: started State, or null when setup parse failed
     * (error already printed).
     */
    State startGame(ServerConfig cfg) {
        String setupPath = cfg.setup
        Scenario loaded = Scenario()
        bool haveSetup = false
        if (setupPath.length > 0) {
            SetupParse parser = SetupParse()
            Sys.File input = Sys.File(setupPath, "r")
            String text = input.readAll()
            input.close()
            loaded = parser.parseText(text)
            if (not parser.ok) {
                print("cplanets-server: setup error: ")
                print(parser.lastError)
                print("\n")
                return(null)
            }
            haveSetup = true
        }

        State game = State()
        if (haveSetup) {
            game.startFromScenario(
                loaded, uint64(cfg.seed), cfg.players)
        } else {
            game.startClosed(uint64(cfg.seed), cfg.players)
        }
        # Verbosity is a process key: apply after scenario load so a
        # leftover scenario.verbosity from older fixtures cannot win.
        game.scenario.verbosity = cfg.verbosity
        game.scenario.clampVerbosity()
        return(game)
    }

    /*
     * Run the TCP server loop on an existing GameDriver.
     *
     * Purpose: Phase F listen path. Prints HOST= / PORT= / SETUP= /
     * SEED= / PLAYERS= / CYCLES= / VERBOSITY= / INJECTABLE= /
     * MENU_KEY= for operators and Python tests. Enables the stdin
     * `m` status menu gate on the listen loop.
     *
     * Parameters:
     *   setupPath — path used for SETUP= (may be empty → builtin).
     *   driver — sole writer already wrapping the live State.
     *   cfg — clamped ServerConfig (host/port/cycles/accept poll).
     *
     * Returns: process exit code (0 ok, 1 bind failure).
     */
    int64 runServeDriver(
        String setupPath,
        GameDriver driver,
        ServerConfig cfg) {
        String setupLabel = "builtin"
        if (setupPath.length > 0) {
            setupLabel = setupPath
        }

        ServerHandler handler = ServerHandler(driver)
        ServerListen listener = ServerListen(
            handler, driver, cfg.acceptPollMs, cfg.cycles)
        StatusViews views = StatusViews(driver, cfg)
        listener.menuGate.enable(views, driver)
        if (not listener.listenOn(cfg.host, cfg.port)) {
            print("cplanets-server: bind failed\n")
            driver.close()
            return(1)
        }
        print("cplanets-server\n")
        print(format("HOST={}\n", cfg.host))
        print(format("PORT={}\n", listener.getPort()))
        print(format("SETUP={}\n", setupLabel))
        print(format("SEED={}\n", cfg.seed))
        print(format("PLAYERS={}\n", cfg.players))
        print(format("CYCLES={}\n", cfg.cycles))
        print(format(
            "VERBOSITY={}\n", driver.game.scenario.verbosity))
        if (cfg.injectable) {
            print("INJECTABLE=1\n")
        } else {
            print("INJECTABLE=0\n")
        }
        print("MENU_KEY=m\n")
        print("GO_KEY=g\n")
        if (driver.inLobby()) {
            print("PHASE=lobby\n")
        } else {
            print("PHASE=running\n")
        }
        print(
            "Lobby: wall ticks do not advance until go. ")
        print(
            "Type g then Enter to start (or status-menu Go). ")
        print(
            "Status menu: type m then Enter ")
        print(
            "(ticks pause while open; q resumes prior pause).\n")
        # Flush so Python functional tests see PORT= before accept.
        Sys.StandardIO().flush()
        listener.serve()
        listener.close()
        driver.close()
        return(0)
    }

    /*
     * Dispatch smoke or serve from resolved config.
     *
     * Purpose: every CLI flag except --config may come from the
     * server config file; flags present on argv override silently.
     * Scenario/setup holds §14 galaxy knobs only. With serve=false,
     * print smoke identity. With serve=true, bind TCP; operator may
     * open the read-only status menu anytime via stdin `m`.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: process exit code (0 for smoke / serve ok).
     */
    int64 run(Cli.CommandLine commandLine) {
        ServerConfig cfg = loadConfig(commandLine)

        if (not cfg.serve) {
            printSmoke()
            return(0)
        }

        State game = startGame(cfg)
        if (game == null) {
            return(1)
        }

        GameDriver driver = GameDriver(
            game,
            cfg.injectable,
            "",
            true,
            uint64(cfg.handshakeMissMs))

        return(runServeDriver(cfg.setup, driver, cfg))
    }
}

start {
    ServerMain main = ServerMain()
    Cli.CommandLine commandLine = main.buildCli()
    if (main.parseOrExit(commandLine)) {
        int64 code = main.run(commandLine)
        if (code != 0) {
            Sys.Process().exit(code)
        }
    }
}
