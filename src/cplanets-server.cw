/*
 * src/cplanets-server.cw — server executable (Phase F / TUNING A).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --serve [--port N] [--players N] [--seed N] [--setup PATH]
 * [--verbosity N] [--injectable] [--cycles N]: bind TCP, load
 * scenario from path or closed builtins, run accept + cadence
 * loop (sole writer). Verbosity is 0–10 (clamped; stdout).
 * Every flag except --setup itself may also be set in the setup
 * file; argv present on the command line overrides silently.
 * Stand-alone and online share this driver (RULES §2 /
 * PLAN §4.F). Knob edits take effect on process restart (no
 * mid-game retune). User-facing argv uses stdlib `cli`
 * (including --help / -h).
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
 *   2026-11-07  Setup file defaults for every CLI flag but path.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"
include "lib/setupParse.cw"
include "lib/state.cw"
include "server/driver.cw"
include "server/handler.cw"
include "server/listen.cw"

/*
 * ServerMain parses argv via Cli and runs smoke or serve mode.
 *
 * Kept as a class so method comments stay with the entry logic
 * (CODING.md). Load --setup first when present, apply process
 * defaults from the file, then let wasProvided CLI flags win.
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
        Cli.Option serve = Cli.Option()
        serve.longName = "serve"
        serve.name = "serve"
        serve.description = "bind TCP and run accept + cadence loop"
        serve.valueType = Cli.ValueType().FLAG
        commandLine.addOption(serve)
        Cli.Option port = Cli.Option()
        port.longName = "port"
        port.name = "port"
        port.description = "listen port (0 = ephemeral; setup key port)"
        port.valueType = Cli.ValueType().NUMBER
        port.hasDefault = true
        port.defaultValue = "0"
        commandLine.addOption(port)
        Cli.Option players = Cli.Option()
        players.longName = "players"
        players.name = "players"
        players.description = "seat count (setup key players)"
        players.valueType = Cli.ValueType().NUMBER
        players.hasDefault = true
        players.defaultValue = "2"
        commandLine.addOption(players)
        Cli.Option seed = Cli.Option()
        seed.longName = "seed"
        seed.name = "seed"
        seed.description = "PRNG seed (setup key seed)"
        seed.valueType = Cli.ValueType().NUMBER
        seed.hasDefault = true
        seed.defaultValue = "7"
        commandLine.addOption(seed)
        Cli.Option setup = Cli.Option()
        setup.longName = "setup"
        setup.name = "setup"
        setup.description = "scenario file path (cannot come from the file)"
        setup.valueType = Cli.ValueType().STRING
        setup.hasDefault = true
        setup.defaultValue = ""
        commandLine.addOption(setup)
        Cli.Option injectable = Cli.Option()
        injectable.longName = "injectable"
        injectable.name = "injectable"
        injectable.description = "test clock (setup key injectable)"
        injectable.valueType = Cli.ValueType().FLAG
        commandLine.addOption(injectable)
        Cli.Option cycles = Cli.Option()
        cycles.longName = "cycles"
        cycles.name = "cycles"
        cycles.description = "cap accept/serve iterations (setup key cycles)"
        cycles.valueType = Cli.ValueType().NUMBER
        cycles.hasDefault = true
        cycles.defaultValue = "0"
        commandLine.addOption(cycles)
        Cli.Option verbosity = Cli.Option()
        verbosity.longName = "verbosity"
        verbosity.name = "verbosity"
        verbosity.description = (
            "stdout log level 0-10 (setup key verbosity; clamped)")
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
     * fail loud via stdlib cli.
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
            print(format("cplanets-server: {}\n", problem))
            print("Try 'cplanets-server --help' for usage.\n")
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Resolve an int64 option: file default unless argv provided.
     *
     * Purpose: silent CLI override of setup process keys.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (port / players / seed / cycles).
     *   fromFile — value from SetupParse (or CLI default).
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
     * Purpose: silent CLI override of setup bool process keys.
     * Presence of the flag on argv forces true (stdlib FLAG).
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (serve / injectable).
     *   fromFile — value from SetupParse.
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
     * Run the TCP server loop with resolved options.
     *
     * Purpose: Phase F driver under serve (CLI or setup). Optional
     * --setup PATH loads §14 knobs (restart to retune). Prints
     * PORT= / SETUP= / SEED= / PLAYERS= / CYCLES= / VERBOSITY= /
     * INJECTABLE= for operators and Python functional tests.
     *
     * Parameters:
     *   setupPath — path used for SETUP= (may be empty → builtin).
     *   loaded — Scenario already started into when setupPath set;
     *     ignored when setupPath is empty (caller passes fresh).
     *   haveSetup — true when setupPath was loaded successfully.
     *   game — State with startClosed / startFromScenario done.
     *   port — listen port (0 = ephemeral).
     *   players — seat count (banner only; already applied).
     *   seedRaw — PRNG seed for banner.
     *   cycles — accept/serve iteration cap.
     *   injectable — test clock.
     *
     * Returns: process exit code (0 ok, 1 bind failure).
     */
    int64 runServe(
        String setupPath,
        State game,
        int64 port,
        int64 players,
        int64 seedRaw,
        int64 cycles,
        bool injectable) {
        String setupLabel = "builtin"
        if (setupPath.length > 0) {
            setupLabel = setupPath
        }

        GameDriver driver = GameDriver(
            game,
            injectable,
            "",
            true,
            5000u)
        ServerHandler handler = ServerHandler(driver)
        ServerListen listener = ServerListen(
            handler, driver, 50, cycles)
        if (not listener.listenOn("127.0.0.1", port)) {
            print("cplanets-server: bind failed\n")
            driver.close()
            return(1)
        }
        print("cplanets-server\n")
        print(format("PORT={}\n", listener.getPort()))
        print(format("SETUP={}\n", setupLabel))
        print(format("SEED={}\n", seedRaw))
        print(format("PLAYERS={}\n", players))
        print(format("CYCLES={}\n", cycles))
        print(format(
            "VERBOSITY={}\n", game.scenario.verbosity))
        if (injectable) {
            print("INJECTABLE=1\n")
        } else {
            print("INJECTABLE=0\n")
        }
        # Flush so Python functional tests see PORT= before accept.
        Sys.StandardIO().flush()
        listener.serve()
        listener.close()
        driver.close()
        return(0)
    }

    /*
     * Dispatch smoke or serve: load setup, apply defaults, overlay.
     *
     * Purpose: every CLI flag except --setup may come from the
     * setup file; flags present on argv override silently. Bare
     * run stays smoke unless serve is true from file or argv.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: process exit code (0 for smoke / serve ok).
     */
    int64 run(Cli.CommandLine commandLine) {
        SetupParse parser = SetupParse()
        String setupPath = ""
        if (commandLine.wasProvided("setup")) {
            setupPath = commandLine.value("setup")
        }

        Scenario loaded = Scenario()
        bool haveSetup = false
        if (setupPath.length > 0) {
            Sys.File input = Sys.File(setupPath, "r")
            String text = input.readAll()
            input.close()
            loaded = parser.parseText(text)
            if (not parser.ok) {
                print("cplanets-server: setup error: ")
                print(parser.lastError)
                print("\n")
                return(1)
            }
            haveSetup = true
        }

        int64 port = resolveInt(commandLine, "port", parser.port)
        int64 players = resolveInt(
            commandLine, "players", parser.players)
        int64 seedRaw = resolveInt(commandLine, "seed", parser.seed)
        int64 cycles = resolveInt(
            commandLine, "cycles", parser.cycles)
        bool injectable = resolveFlag(
            commandLine, "injectable", parser.injectable)
        bool wantServe = resolveFlag(
            commandLine, "serve", parser.serve)

        if (players < 1) {
            players = 1
        }
        if (seedRaw < 0) {
            seedRaw = 0
        }

        if (not wantServe) {
            printSmoke()
            return(0)
        }

        State game = State()
        if (haveSetup) {
            game.startFromScenario(
                loaded, uint64(seedRaw), players)
        } else {
            game.startClosed(uint64(seedRaw), players)
        }

        # Verbosity: setup/scenario default, CLI overlays when given.
        if (commandLine.wasProvided("verbosity")) {
            game.scenario.verbosity = (
                commandLine.value("verbosity").toInt64())
        } else {
            if (not haveSetup) {
                game.scenario.verbosity = (
                    commandLine.value("verbosity").toInt64())
            }
        }
        game.scenario.clampVerbosity()

        return(runServe(
            setupPath,
            game,
            port,
            players,
            seedRaw,
            cycles,
            injectable))
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
