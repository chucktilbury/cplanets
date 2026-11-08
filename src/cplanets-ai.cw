/*
 * src/cplanets-ai.cw — stand-alone AI client (Phase H).
 *
 * --config PATH is mandatory (own AI config; not human settings).
 * Missing or empty path prints help and exits 2.
 * Optional --host / --port / --verbosity override; --once prints
 * one policy shape without TCP. --serve-loop dials and runs
 * maybePutPolicy for --cycles N. Never ticks; never opens the
 * universe DB (RULES §2 / PLAN §4.H).
 * User-facing argv uses stdlib `cli` (including --help / -h).
 * With all modes false from file/argv, prints smoke identity.
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
 *   2026-11-07  --config mandatory; missing prints help, exit 2.
 *   2026-11-08  On-demand status menu via stdin m during serve-loop.
 */

import cli as Cli
import system as Sys

include "lib/machine.cw"
include "ai/brain.cw"
include "ai/client.cw"
include "ai/config.cw"
include "ai/configParse.cw"
include "ai/menuGate.cw"
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
        config.description = (
            "required: AI config file (not human settings)")
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
            print(format("cplanets-ai: {}\n", problem))
            print("Try 'cplanets-ai --help' for usage.\n")
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
     * Load AiConfig from required --config with host/port/verbosity
     * overlays.
     *
     * Purpose: own config file path; argv may override dial and
     * verbosity. Overlays apply only when the option was provided.
     * Unknown config keys fail loud and exit(1). Caller already
     * required a non-empty --config path.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: clamped AiConfig from the file + argv overlays.
     */
    AiConfig loadConfig(Cli.CommandLine commandLine) {
        AiConfig cfg = AiConfig()
        String path = commandLine.value("config")
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
     * one handshake + policy attempt. Between cycles, stdin line
     * `m` opens the read-only status menu (decisions pause while
     * open; `q` resumes). Banner prints MENU_KEY=m.
     *
     * Parameters:
     *   cfg — loaded AI config with host/port.
     *   cycles — number of maybePutPolicy attempts (min 1).
     *
     * Returns: nothing.
     */
    void runLoop(AiConfig cfg, int64 cycles) {
        AiClient client = AiClient(cfg)
        AiMenuGate gate = AiMenuGate()
        gate.enable(client.explore)
        if (not client.dial()) {
            print("cplanets-ai\n")
            print(format("VERBOSITY={}\n", cfg.verbosity))
            print("dial_failed\n")
            return()
        }
        client.handshake()
        print("cplanets-ai\n")
        print(format("HOST={}\n", cfg.host))
        print(format("PORT={}\n", cfg.port))
        print(format("PLAYER={}\n", cfg.playerId))
        print(format("CYCLES={}\n", cycles))
        print(format("VERBOSITY={}\n", cfg.verbosity))
        print("MENU_KEY=m\n")
        print(
            "Status menu: type m then Enter on this console ")
        print(
            "(AI decisions pause while open; q resumes).\n")
        Sys.StandardIO().flush()
        int64 limit = cycles
        if (limit < 1) {
            limit = 1
        }
        int64 index = 0
        while (index < limit) {
            # Pull / decide first so a buffered stdin `m` opens the
            # menu against a decoded snapshot, not an empty bag.
            int64 tick = client.pullStateTick()
            if (tick < 0) {
                tick = 0
            }
            AiView view = client.explore.view
            view.publishedTick = tick
            client.maybePutPolicyAt(
                view, uint64(index * 1000), index)
            gate.pollOnce()
            index = index + 1
        }
        client.close()
        print(format("VERBOSITY={}\n", cfg.verbosity))
        print("ok\n")
    }

    /*
     * Dispatch smoke / once / loop from a parsed CommandLine.
     *
     * Purpose: single entry used by start {}. --config is required
     * upstream. Mode and cycles defaults come from the config file;
     * argv overrides silently when provided. serve-loop needs a
     * positive port; once (or loop with port 0) prints one local
     * policy; all modes false → smoke identity.
     *
     * Parameters:
     *   commandLine — parsed Cli.CommandLine.
     *
     * Returns: nothing.
     */
    void run(Cli.CommandLine commandLine) {
        AiConfig cfg = loadConfig(commandLine)
        bool wantOnce = resolveFlag(commandLine, "once", cfg.once)
        bool wantLoop = resolveFlag(
            commandLine, "serve-loop", cfg.serveLoop)
        if (wantLoop and cfg.port > 0) {
            runLoop(cfg, cfg.cycles)
            return()
        }
        if (wantOnce or wantLoop) {
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
