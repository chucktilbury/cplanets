/*
 * src/cplanets-tick.cw — headless N-tick host stub (Phase A).
 *
 * Optional CLI that will call lib-only tick for unit/fn tests so
 * they need not link GTK or SQLite (PLAN §1). Phase A only prints
 * the program name and lib identity. User-facing argv uses stdlib
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
     * Purpose: declare help now; advance-N options land later.
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
            print(format("cplanets-tick: {}\n", problem))
            print("Try 'cplanets-tick --help' for usage.\n")
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Dispatch the identity smoke path.
     *
     * Purpose: current stub behavior after a successful parse.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine (unused until advance-N).
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
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
