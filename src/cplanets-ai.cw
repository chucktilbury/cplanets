/*
 * src/cplanets-ai.cw — stand-alone AI client (Phase H).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --config PATH: load own AI config (not human settings).
 * Optional --host / --port override; --once prints one policy
 * shape without TCP. --serve-loop dials and runs maybePutPolicy
 * for --cycles N. Never ticks; never opens the universe DB
 * (RULES §2 / PLAN §4.H).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase H: config load, local once, TCP loop.
 */

import system as Sys

include "lib/machine.cw"
include "ai/brain.cw"
include "ai/client.cw"
include "ai/config.cw"
include "ai/configParse.cw"
include "ai/policyShape.cw"
include "ai/view.cw"

/*
 * AiMain parses argv and runs smoke, once, or TCP modes.
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
     * Read a string flag value following a name, or default.
     *
     * Purpose: parse --config / --host without Cli.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--config".
     *   fallback — value when missing.
     *
     * Returns: next argv token or fallback.
     */
    String flagString(list args, String name, String fallback) {
        int64 index = 1
        while (index + 1 < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                return(args[index + 1])
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * Read an int64 flag value following a name, or default.
     *
     * Purpose: parse --port / --cycles.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--port".
     *   fallback — value when missing / bad.
     *
     * Returns: parsed int64 or fallback.
     */
    int64 flagInt(list args, String name, int64 fallback) {
        int64 index = 1
        while (index + 1 < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                String text = args[index + 1]
                return(text.toInt64())
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * True when argv contains a bare flag name.
     *
     * Purpose: gate --once / --serve-loop.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--once".
     *
     * Returns: true when present.
     */
    bool hasFlag(list args, String name) {
        int64 index = 1
        while (index < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Load AiConfig from --config path with host/port overlays.
     *
     * Purpose: own config file path; argv may override dial.
     *
     * Parameters:
     *   args — argv list.
     *
     * Returns: clamped AiConfig (defaults when no --config).
     */
    AiConfig loadConfig(list args) {
        String path = flagString(args, "--config", "")
        AiConfig cfg = AiConfig()
        if (path.length > 0) {
            Sys.File input = Sys.File(path, "r")
            String text = input.readAll()
            input.close()
            AiConfigParse parser = AiConfigParse()
            cfg = parser.parseText(text)
        }
        String host = flagString(args, "--host", "")
        if (host.length > 0) {
            cfg.host = host
        }
        int64 port = flagInt(args, "--port", -1)
        if (port >= 0) {
            cfg.port = port
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
        print("cplanets-ai\n")
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
            client.maybePutPolicy(view, uint64(index * 1000))
            index = index + 1
        }
        client.close()
        print("cplanets-ai\n")
        print("ok\n")
    }

    /*
     * Dispatch smoke / once / loop from argv.
     *
     * Purpose: single entry used by start {}. Smoke when no
     * AI flags; --serve-loop needs a positive port; otherwise
     * --once / --config prints one local policy.
     *
     * Parameters:
     *   args — Sys.Process argv.
     *
     * Returns: nothing.
     */
    void run(list args) {
        bool wantConfig = hasFlag(args, "--config")
        bool wantOnce = hasFlag(args, "--once")
        bool wantLoop = hasFlag(args, "--serve-loop")
        if (not wantConfig and not wantOnce and not wantLoop) {
            printSmoke()
            return()
        }
        AiConfig cfg = loadConfig(args)
        if (wantLoop and cfg.port > 0) {
            runLoop(cfg, flagInt(args, "--cycles", 1))
            return()
        }
        runOnce(cfg)
    }
}

start {
    Sys.Process proc = Sys.Process()
    AiMain main = AiMain()
    main.run(proc.argv())
}
