/*
 * src/cplanets-server.cw — server executable (Phase F / TUNING A).
 *
 * --config PATH is mandatory (unified process + §14 scenario
 * knobs). Missing or empty path prints help and exits 2. Unopenable
 * or unreadable config is a hard error (exit 1) — no silent
 * Scenario() fallback. --serve [--host ADDR] [--port N]
 * [--players N] [--seed N] [--verbosity N] [--injectable]
 * [--cycles N] [--handshake-miss-ms N] [--accept-poll-ms N]:
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
 *   2026-11-08  players soft max (0=unlimited); seats grow on connect.
 *   2026-11-09  Banner: menu Go closes menu; stray stdin keys flushed.
 *   2026-11-09  Fold scenario into --config; drop --setup / setup=.
 *   2026-11-09  Hard error on unopenable config; new process knobs.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"
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
            "required: unified server+scenario config")
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
        players.description = (
            "soft max seats (0=unlimited; grow on connect)")
        players.valueType = Cli.ValueType().NUMBER
        players.hasDefault = true
        players.defaultValue = "0"
        commandLine.addOption(players)
        Cli.Option seed = Cli.Option()
        seed.longName = "seed"
        seed.name = "seed"
        seed.description = "PRNG seed for the start galaxy"
        seed.valueType = Cli.ValueType().NUMBER
        seed.hasDefault = true
        seed.defaultValue = "7"
        commandLine.addOption(seed)
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
        Cli.Option handshakeMiss = Cli.Option()
        handshakeMiss.longName = "handshake-miss-ms"
        handshakeMiss.name = "handshake-miss-ms"
        handshakeMiss.description = (
            "presence drop window without handshake (ms)")
        handshakeMiss.valueType = Cli.ValueType().NUMBER
        handshakeMiss.hasDefault = true
        handshakeMiss.defaultValue = "5000"
        commandLine.addOption(handshakeMiss)
        Cli.Option acceptPoll = Cli.Option()
        acceptPoll.longName = "accept-poll-ms"
        acceptPoll.name = "accept-poll-ms"
        acceptPoll.description = (
            "accept/recv poll timeout / cadence grain (ms)")
        acceptPoll.valueType = Cli.ValueType().NUMBER
        acceptPoll.hasDefault = true
        acceptPoll.defaultValue = "50"
        commandLine.addOption(acceptPoll)
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
     * Purpose: process/network and §14 scenario defaults live in
     * one server config file. --config PATH is the only flag with
     * no in-file key. Missing/unopenable path is a hard error
     * (exit 1) with a message — no silent closed-default start.
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
        String text = ""
        try {
            Sys.File input = Sys.File(path, "r")
            text = input.readAll()
            input.close()
        } except() as error {
            print(format(
                "cplanets-server: cannot open config '{}': {}\n",
                path,
                error))
            Sys.Process().exit(1)
        }
        ServerConfigParse parser = ServerConfigParse()
        cfg = parser.parseText(text)
        if (not parser.ok) {
            print("cplanets-server: config error: ")
            print(parser.lastError)
            print("\n")
            Sys.Process().exit(1)
        }
        cfg.configPath = path
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
        cfg.handshakeMissMs = resolveInt(
            commandLine, "handshake-miss-ms", cfg.handshakeMissMs)
        cfg.acceptPollMs = resolveInt(
            commandLine, "accept-poll-ms", cfg.acceptPollMs)
        cfg.serve = resolveFlag(commandLine, "serve", cfg.serve)
        cfg.injectable = resolveFlag(
            commandLine, "injectable", cfg.injectable)
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Start a State from the unified ServerConfig scenario.
     *
     * Purpose: one authoritative world bootstrap for --serve.
     * Always starts with **zero** empire seats; handshake allocate
     * grows seats as clients connect. cfg.players is the soft max
     * applied on the GameDriver after construct, not a pre-size.
     * Scenario knobs come from the config file (Scenario() defaults
     * plus overlays) — there is no separate setup path.
     *
     * Parameters:
     *   cfg — clamped ServerConfig (scenario / seed / players soft
     *         max / verbosity already overlaid).
     *
     * Returns: started State.
     */
    State startGame(ServerConfig cfg) {
        State game = State()
        game.seatHardCap = cfg.seatHardCap
        # 0 seats: grow on connect. Soft max is driver.softMaxPlayers.
        game.startFromScenario(cfg.scenario, uint64(cfg.seed), 0)
        # Verbosity is a process key: apply after scenario load so a
        # leftover scenario.verbosity from older fixtures cannot win.
        game.scenario.verbosity = cfg.verbosity
        game.scenario.clampVerbosity()
        return(game)
    }

    /*
     * Run the TCP server loop on an existing GameDriver.
     *
     * Purpose: Phase F listen path. Prints HOST= / PORT= / CONFIG= /
     * SCENARIO_MODE= / SEED= / PLAYERS= / CYCLES= / VERBOSITY= /
     * INJECTABLE= / MENU_KEY= for operators and Python tests.
     * Enables the stdin `m` status menu gate on the listen loop.
     *
     * Parameters:
     *   driver — sole writer already wrapping the live State.
     *   cfg — clamped ServerConfig (host/port/cycles/accept poll /
     *         recv buffer).
     *
     * Returns: process exit code (0 ok, 1 bind failure).
     */
    int64 runServeDriver(GameDriver driver, ServerConfig cfg) {
        ServerHandler handler = ServerHandler(driver)
        ServerListen listener = ServerListen(
            handler,
            driver,
            cfg.acceptPollMs,
            cfg.cycles,
            cfg.recvBufferBytes)
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
        print(format("CONFIG={}\n", cfg.configPath))
        print(format(
            "SCENARIO_MODE={}\n", driver.game.scenario.scenarioMode))
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
            "Type g then Enter to start (or status-menu Go, ")
        print(
            "which also closes the menu). ")
        print(
            "Status menu: type m then Enter ")
        print(
            "(ticks pause while open; q resumes prior pause; ")
        print(
            "stray keys are flushed).\n")
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
     * unified server config file; flags present on argv override
     * silently. §14 galaxy knobs live in the same file. With
     * serve=false, print smoke identity. With serve=true, bind TCP;
     * operator may open the read-only status menu anytime via
     * stdin `m`.
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
        GameDriver driver = GameDriver(
            game,
            cfg.injectable,
            "",
            true,
            uint64(cfg.handshakeMissMs))
        # players config / --players: soft max (0 = unlimited).
        driver.softMaxPlayers = cfg.players
        driver.verbose.maxLines = cfg.verboseCaptureLines

        return(runServeDriver(driver, cfg))
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
