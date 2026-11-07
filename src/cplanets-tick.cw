/*
 * src/cplanets-tick.cw — headless N-tick host stub (Phase A).
 *
 * --config PATH is mandatory. Missing or empty path prints help
 * and exits 2. Optional CLI that will call lib-only tick for
 * unit/fn tests so they need not link GTK or SQLite (PLAN §1).
 * For now loads the config file (no keys yet) and prints the
 * program name + lib identity. User-facing argv uses stdlib
 * `cli` (including --help / -h); no advance-N flags yet.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase C: still identity smoke; lib tick is covered
 *               by unit/fn programs (CLI advance-N later).
 *   2026-11-06  Migrate argv to stdlib cli (+ generated --help).
 *   2026-11-07  --config mandatory; missing prints help, exit 2.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"

/*
 * TickMain parses argv via Cli and runs the identity smoke path.
 *
 * Kept as a class so method comments stay with entry logic
 * (CODING.md). Advance-N flags will register here later.
 */
class TickMain {
    /*
     * Construct the entry helper.
     *
     * Purpose: host argv parsing without free functions.
     *
     * Parameters: none.
     *
     * Returns: TickMain instance.
     */
    TickMain() {
    }

    /*
     * Print the smoke identity lines.
     *
     * Purpose: keep smoke_cplanets-tick green (name + lib id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSmoke() {
        Machine machine = Machine()
        print("cplanets-tick\n")
        print(machine.identity())
        print("\n")
    }

    /*
     * Build the registered Cli.CommandLine for this binary.
     *
     * Purpose: declare --config (required) and help now;
     * advance-N options land later.
     *
     * Parameters: none.
     *
     * Returns: configured CommandLine (not yet parsed).
     */
    Cli.CommandLine buildCli() {
        Cli.CommandLine commandLine = Cli.CommandLine(
            "cplanets-tick",
            "CPlanets headless tick host stub (lib-only; no TCP/GTK).",
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
            "required: tick host config (placeholder; no keys yet)")
        config.valueType = Cli.ValueType().STRING
        commandLine.addOption(config)
        return(commandLine)
    }

    /*
     * Parse argv; print help or an error and exit when needed.
     *
     * Purpose: single parse path; unknown flags fail loud.
     * --config PATH is mandatory (non-empty); missing path prints
     * the same help as -h and exits 2.
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
            print(format("cplanets-tick: {}\n", problem))
            print("Try 'cplanets-tick --help' for usage.\n")
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
     * Open the required config path (fail loud if unreadable).
     *
     * Purpose: tick has no keys yet; still require a real file so
     * the mandatory --config contract matches the other bins.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine with non-empty config.
     *
     * Returns: true when the file opened; false after exit(1).
     */
    bool loadConfig(Cli.CommandLine commandLine) {
        String path = commandLine.value("config")
        try {
            Sys.File input = Sys.File(path, "r")
            input.readAll()
            input.close()
        } except() as error {
            print(format("cplanets-tick: config error: {}\n", error))
            Sys.Process().exit(1)
            return(false)
        }
        return(true)
    }

    /*
     * Dispatch the identity smoke path after a successful parse.
     *
     * Purpose: current stub behavior; advance-N will use config
     * keys later.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
        if (not loadConfig(commandLine)) {
            return()
        }
        printSmoke()
    }
}

start {
    TickMain main = TickMain()
    Cli.CommandLine commandLine = main.buildCli()
    if (main.parseOrExit(commandLine)) {
        main.run(commandLine)
    }
}
