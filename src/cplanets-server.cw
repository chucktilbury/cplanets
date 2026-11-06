/*
 * src/cplanets-server.cw — server executable (Phase F / TUNING A).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --serve [--port N] [--players N] [--seed N] [--setup PATH]
 * [--injectable] [--cycles N]: bind TCP, load scenario from path
 * or closed builtins, run accept + cadence loop (sole writer).
 * Stand-alone and online share this driver (RULES §2 / PLAN §4.F).
 * Knob edits take effect on process restart (no mid-game retune).
 * User-facing argv uses stdlib `cli` (including --help / -h).
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
        Cli.Option serve = Cli.Option()
        serve.longName = "serve"
        serve.name = "serve"
        serve.description = "bind TCP and run accept + cadence loop"
        serve.valueType = Cli.ValueType().FLAG
        commandLine.addOption(serve)
        Cli.Option port = Cli.Option()
        port.longName = "port"
        port.name = "port"
        port.description = "listen port (0 = ephemeral)"
        port.valueType = Cli.ValueType().NUMBER
        port.hasDefault = true
        port.defaultValue = "0"
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
        setup.description = "scenario file (§14 knobs); empty = builtin"
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
     * Run the TCP server loop from a parsed CommandLine.
     *
     * Purpose: Phase F driver under --serve. Optional --setup
     * PATH loads §14 knobs from a fixture file (restart to
     * retune). Prints PORT= / SETUP= / SEED= for operators and
     * Python functional tests.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine with serve options.
     *
     * Returns: process exit code (0 ok, 1 bind/setup failure).
     */
    int64 runServe(Cli.CommandLine commandLine) {
        int64 port = commandLine.value("port").toInt64()
        int64 players = commandLine.value("players").toInt64()
        int64 cycles = commandLine.value("cycles").toInt64()
        int64 seedRaw = commandLine.value("seed").toInt64()
        String setupPath = commandLine.value("setup")
        bool injectable = commandLine.switchValue("injectable")
        if (players < 1) {
            players = 1
        }
        if (seedRaw < 0) {
            seedRaw = 0
        }
        uint64 seed = uint64(seedRaw)

        State game = State()
        String setupLabel = "builtin"
        if (setupPath.length > 0) {
            Sys.File input = Sys.File(setupPath, "r")
            String text = input.readAll()
            input.close()
            SetupParse parser = SetupParse()
            Scenario loaded = parser.parseText(text)
            if (not parser.ok) {
                print("cplanets-server: setup error: ")
                print(parser.lastError)
                print("\n")
                return(1)
            }
            game.startFromScenario(loaded, seed, players)
            setupLabel = setupPath
        } else {
            game.startClosed(seed, players)
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
     * Dispatch smoke or serve from a parsed CommandLine.
     *
     * Purpose: bare run stays smoke; --serve enters the TCP loop.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: process exit code (0 for smoke / serve ok).
     */
    int64 run(Cli.CommandLine commandLine) {
        if (not commandLine.switchValue("serve")) {
            printSmoke()
            return(0)
        }
        return(runServe(commandLine))
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
