/*
 * tests/unit/unit_aiVerbose.cw — AI verbosity logger + config key.
 *
 * Checks AI config verbosity parse, 0–10 clamp, quiet default,
 * policy / seat / cycle emits at provisional decisionsAt (3), and
 * AiClient.setVerbosity overlay. Capture list is asserted; stdout
 * echo is off.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial AI verbosity unit program.
 *   2026-11-07  Remap asserts to 0–10 provisional thresholds + clamp.
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
    AiConfig loaded = parser.parseText("verbosity = 3\n")
    if (not parser.ok or loaded.verbosity != 3) {
        ok = false
    }

    # --- clamp out of range ---
    AiConfig high = parser.parseText("verbosity = 99\n")
    if (not parser.ok or high.verbosity != 10) {
        ok = false
    }
    AiConfig low = parser.parseText("verbosity = -3\n")
    if (not parser.ok or low.verbosity != 0) {
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

    # --- below decisionsAt: still quiet ---
    AiVerboseLog midLow = AiVerboseLog()
    midLow.echo = false
    midLow.setLevel(2)
    midLow.logPolicy(0, shape, "once")
    midLow.logSeat(0, true)
    if (midLow.lines.length != 0) {
        ok = false
    }

    # --- level decisionsAt (3): policy / seat / cycle ---
    AiVerboseLog decisions = AiVerboseLog()
    decisions.echo = false
    decisions.setLevel(3)
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

    # --- setLevel clamps + full gate ---
    decisions.setLevel(42)
    if (decisions.level != 10 or not decisions.fullEnabled()) {
        ok = false
    }
    decisions.setLevel(-1)
    if (decisions.level != 0) {
        ok = false
    }

    # --- AiClient copies config verbosity + setVerbosity ---
    AiConfig cfg = AiConfig()
    cfg.verbosity = 3
    cfg.surpriseRate = 0.0
    cfg.reactionLagTicks = 1
    cfg.reactionLagSeconds = 0.0
    cfg.clampAll()
    AiClient client = AiClient(cfg)
    client.verbose.echo = false
    if (client.verbose.level != 3) {
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
    client.setVerbosity(99)
    if (client.config.verbosity != 10 or client.verbose.level != 10) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
