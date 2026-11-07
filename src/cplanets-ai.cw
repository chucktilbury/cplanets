/*
 * src/cplanets-ai.cw — stand-alone AI client (Phase H).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --config PATH: load own AI config (not human settings).
 * Optional --host / --port / --verbosity override; --once prints
 * one policy shape without TCP. --serve-loop dials and runs
 * maybePutPolicy for --cycles N. Never ticks; never opens the
 * universe DB (RULES §2 / PLAN §4.H).
 * User-facing argv uses stdlib `cli` (including --help / -h).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase H: config load, local once, TCP loop.
 *   2026-11-06  Fail loud on unknown AI config keys (TUNING A).
 *   2026-11-06  Migrate argv to stdlib cli (+ generated --help).
 *   2026-11-07  --verbosity N (overlay AI config verbosity key).
 *   2026-11-07  Verbosity scale 0–10; clamp out-of-range.
 *   2026-11-07  Config defaults for every CLI flag but --config.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"
include "ai/brain.cw"
include "ai/client.cw"
include "ai/config.cw"
include "ai/configParse.cw"
include "ai/policyShape.cw"
include "ai/verboseLog.cw"
include "ai/view.cw"

/*
 * AiMain parses argv via Cli and runs smoke, once, or TCP modes.
 *
 * Kept as a class so method comments stay with entry logic
 * (CODING.md).
 */
class AiMain {
    /*
     * Construct the entry helper.
     *
     * Purpose: host argv parsing without free functions.
     *
     * Parameters: none.
     *
     * Returns: AiMain instance.
     */
    AiMain() {
    }

    /*
     * Print the smoke identity lines.
     *
     * Purpose: keep smoke_cplanets-ai green (name + lib id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSmoke() {
        Machine machine = Machine()
        print("cplanets-ai\n")
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
            "cplanets-ai",
            "CPlanets stand-alone AI client (never ticks).",
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
        config.description = "AI config file (not human settings)"
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
        Cli.Option once = Cli.Option()
        once.longName = "once"
        once.name = "once"
        once.description = "print one local policy shape (no TCP)"
        once.valueType = Cli.ValueType().FLAG
        commandLine.addOption(once)
        Cli.Option serveLoop = Cli.Option()
        serveLoop.longName = "serve-loop"
        serveLoop.name = "serve-loop"
        serveLoop.description = "dial and PUT policy for --cycles N"
        serveLoop.valueType = Cli.ValueType().FLAG
        commandLine.addOption(serveLoop)
        Cli.Option cycles = Cli.Option()
        cycles.longName = "cycles"
        cycles.name = "cycles"
        cycles.description = "loop attempts (config key cycles)"
        cycles.valueType = Cli.ValueType().NUMBER
        cycles.hasDefault = true
        cycles.defaultValue = "1"
        commandLine.addOption(cycles)
        Cli.Option verbosity = Cli.Option()
        verbosity.longName = "verbosity"
        verbosity.name = "verbosity"
        verbosity.description = (
            "stdout log level 0-10 (config key verbosity; clamped)")
        verbosity.valueType = Cli.ValueType().NUMBER
        verbosity.hasDefault = true
        verbosity.defaultValue = "0"
        commandLine.addOption(verbosity)
        return(commandLine)
    }

    /*
     * Resolve a FLAG option: file default unless argv provided.
     *
     * Purpose: silent CLI override of AI config mode keys.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *   name — option name (once / serve-loop).
     *   fromFile — value from AiConfig.
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
            print(format("cplanets-ai: {}\n", problem))
            print("Try 'cplanets-ai --help' for usage.\n")
            Sys.Process().exit(2)
            return(false)
        }
        return(true)
    }

    /*
     * Load AiConfig from --config with host/port/verbosity overlays.
     *
     * Purpose: own config file path; argv may override dial and
     * verbosity. Overlays apply only when the option was provided.
     * Unknown config keys fail loud and exit(1).
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: clamped AiConfig (defaults when no --config).
     */
    AiConfig loadConfig(Cli.CommandLine commandLine) {
        AiConfig cfg = AiConfig()
        if (commandLine.wasProvided("config")) {
            String path = commandLine.value("config")
            if (path.length > 0) {
                Sys.File input = Sys.File(path, "r")
                String text = input.readAll()
                input.close()
                AiConfigParse parser = AiConfigParse()
                cfg = parser.parseText(text)
                if (not parser.ok) {
                    print("cplanets-ai: config error: ")
                    print(parser.lastError)
                    print("\n")
                    Sys.Process().exit(1)
                }
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
        # CLI overlays config keys when the flag is present.
        if (commandLine.wasProvided("verbosity")) {
            cfg.verbosity = commandLine.value("verbosity").toInt64()
        }
        if (commandLine.wasProvided("cycles")) {
            cfg.cycles = commandLine.value("cycles").toInt64()
        }
        if (commandLine.wasProvided("once")) {
            cfg.once = commandLine.switchValue("once")
        }
        if (commandLine.wasProvided("serve-loop")) {
            cfg.serveLoop = commandLine.switchValue("serve-loop")
        }
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Generate and print one local policy shape.
     *
     * Purpose: --once path for debugging without TCP.
     *
     * Parameters:
     *   cfg — loaded AI config.
     *
     * Returns: nothing.
     */
    void runOnce(AiConfig cfg) {
        AiBrain brain = AiBrain(cfg)
        AiView view = AiView(cfg.playerId)
        view.currentRole = "neutral"
        view.publishedTick = 0
        AiPolicyShape shape = brain.generate(view)
        AiVerboseLog verbose = AiVerboseLog()
        verbose.setLevel(cfg.verbosity)
        verbose.logPolicy(cfg.playerId, shape, "once")
        print("cplanets-ai\n")
        print(format("VERBOSITY={}\n", cfg.verbosity))
        print(shape.roleName)
        print("\n")
        print(format("{}\n", shape.expansionPct))
        if (shape.surpriseApplied) {
            print("surprise\n")
        } else {
            print("plain\n")
        }
    }

    /*
     * Dial the server and run a short PUT loop.
     *
     * Purpose: same-protocol exercise; cycles clamped to at least
     * one handshake + policy attempt.
     *
     * Parameters:
     *   cfg — loaded AI config with host/port.
     *   cycles — number of maybePutPolicy attempts (min 1).
     *
     * Returns: nothing.
     */
    void runLoop(AiConfig cfg, int64 cycles) {
        AiClient client = AiClient(cfg)
        if (not client.dial()) {
            print("cplanets-ai\n")
            print(format("VERBOSITY={}\n", cfg.verbosity))
            print("dial_failed\n")
            return()
        }
        client.handshake()
        int64 limit = cycles
        if (limit < 1) {
            limit = 1
        }
        int64 index = 0
        while (index < limit) {
            int64 tick = client.pullStateTick()
            if (tick < 0) {
                tick = 0
            }
            AiView view = AiView(cfg.playerId)
            view.publishedTick = tick
            client.maybePutPolicyAt(
                view, uint64(index * 1000), index)
            index = index + 1
        }
        client.close()
        print("cplanets-ai\n")
        print(format("VERBOSITY={}\n", cfg.verbosity))
        print("ok\n")
    }

    /*
     * Dispatch smoke / once / loop from a parsed CommandLine.
     *
     * Purpose: single entry used by start {}. Smoke when no
     * AI flags and no config path; serve-loop needs a positive
     * port; otherwise once / config prints one local policy.
     * Mode and cycles defaults come from the config file;
     * argv overrides silently when provided.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
        bool wantConfig = commandLine.wasProvided("config")
        if (not wantConfig
            and not commandLine.wasProvided("once")
            and not commandLine.wasProvided("serve-loop")) {
            printSmoke()
            return()
        }
        AiConfig cfg = loadConfig(commandLine)
        bool wantOnce = resolveFlag(commandLine, "once", cfg.once)
        bool wantLoop = resolveFlag(
            commandLine, "serve-loop", cfg.serveLoop)
        if (wantLoop and cfg.port > 0) {
            runLoop(cfg, cfg.cycles)
            return()
        }
        if (wantOnce or wantConfig or wantLoop) {
            runOnce(cfg)
            return()
        }
        printSmoke()
    }
}

start {
    AiMain main = AiMain()
    Cli.CommandLine commandLine = main.buildCli()
    if (main.parseOrExit(commandLine)) {
        main.run(commandLine)
    }
}
