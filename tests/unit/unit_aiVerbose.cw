/*
 * tests/unit/unit_aiVerbose.cw — AI verbosity logger + config key.
 *
 * Checks AI config verbosity parse, quiet default, policy / seat /
 * cycle emits at level 1, and AiClient.setVerbosity overlay.
 * Capture list is asserted; stdout echo is off.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial AI verbosity unit program.
 */

include "ai/client.cw"
include "ai/configParse.cw"
include "ai/policyShape.cw"
include "ai/verboseLog.cw"
include "ai/view.cw"

start {
    bool ok = true

    # --- config key ---
    AiConfigParse parser = AiConfigParse()
    AiConfig loaded = parser.parseText("verbosity = 1\n")
    if (not parser.ok or loaded.verbosity != 1) {
        ok = false
    }

    # --- quiet default ---
    AiConfig quietCfg = AiConfig()
    if (quietCfg.verbosity != 0) {
        ok = false
    }

    # --- quiet: no policy line ---
    AiVerboseLog quiet = AiVerboseLog()
    quiet.echo = false
    quiet.setLevel(0)
    AiPolicyShape shape = AiPolicyShape()
    shape.roleName = "trader"
    shape.expansionPct = 40
    shape.escortPct = 50
    shape.agreementS = 10
    shape.techBiasPct = 60
    quiet.logPolicy(0, shape, "once")
    quiet.logSeat(0, true)
    quiet.logCycle(0, 3, 0, "put")
    if (quiet.lines.length != 0) {
        ok = false
    }

    # --- level 1: policy / seat / cycle ---
    AiVerboseLog decisions = AiVerboseLog()
    decisions.echo = false
    decisions.setLevel(1)
    decisions.logPolicy(2, shape, "put")
    if (not decisions.linesContain("verbosity: policy player=2")) {
        ok = false
    }
    if (not decisions.linesContain("via=put")) {
        ok = false
    }
    if (not decisions.linesContain("role=trader")) {
        ok = false
    }
    if (not decisions.linesContain("expansion=40")) {
        ok = false
    }
    decisions.clearLines()
    decisions.logSeat(2, false)
    if (not decisions.linesContain(
        "verbosity: seat player=2 handshake=fail")) {
        ok = false
    }
    decisions.clearLines()
    decisions.logCycle(1, 7, 2, "skip")
    if (not decisions.linesContain(
        "verbosity: cycle index=1 tick=7 player=2 action=skip")) {
        ok = false
    }

    # --- AiClient copies config verbosity + setVerbosity ---
    AiConfig cfg = AiConfig()
    cfg.verbosity = 1
    cfg.surpriseRate = 0.0
    cfg.reactionLagTicks = 1
    cfg.reactionLagSeconds = 0.0
    cfg.clampAll()
    AiClient client = AiClient(cfg)
    client.verbose.echo = false
    if (client.verbose.level != 1) {
        ok = false
    }
    AiView view = AiView(cfg.playerId)
    view.currentRole = "neutral"
    view.publishedTick = 0
    AiPolicyShape local = client.generateLocal(view, 0u)
    if (local.version < 1) {
        ok = false
    }
    if (not client.verbose.linesContain("via=local")) {
        ok = false
    }
    client.verbose.clearLines()
    client.setVerbosity(0)
    if (client.config.verbosity != 0 or client.verbose.level != 0) {
        ok = false
    }
    view.publishedTick = 10
    AiPolicyShape again = client.generateLocal(view, 1000u)
    if (again.version < 1) {
        ok = false
    }
    if (client.verbose.lines.length != 0) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
