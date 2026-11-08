/*
 * tests/unit/unit_aiConfig.cw — unit program for AiConfigParse.
 *
 * Overlays AI axes from application text; checks clamp and that
 * unknown keys (including scenario-only knobs) fail loud.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AI config unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-06  Unknown keys fail loud (TUNING A2).
 *   2026-11-07  Assert verbosity config key.
 *   2026-11-07  Assert cycles / once / serve_loop keys.
 *   2026-11-08  cycles 0 default; negative clamps to 0.
 */

include "ai/configParse.cw"

start {
    AiConfig baseline = AiConfig()
    bool ok = true
    if (baseline.cycles != 0) {
        ok = false
    }
    baseline.cycles = -3
    baseline.clampAll()
    if (baseline.cycles != 0) {
        ok = false
    }

    String text = ""
    text.append("aggression = 0.9\n")
    text.append("role_stickiness = 0.2\n")
    text.append("expansion = 0.75\n")
    text.append("escort = 0.1\n")
    text.append("agreement_appetite = 0.8\n")
    text.append("tech_vs_hulls = 0.3\n")
    text.append("reaction_lag_ticks = 3\n")
    text.append("reaction_lag_seconds = 4.5\n")
    text.append("surprise_rate = 1.5\n")
    text.append("seed = 99\n")
    text.append("player_id = 2\n")
    text.append("host = 10.0.0.2\n")
    text.append("port = 7777\n")
    text.append("verbosity = 2\n")
    text.append("cycles = 5\n")
    text.append("once = true\n")
    text.append("serve_loop = true\n")
    AiConfigParse parser = AiConfigParse()
    AiConfig cfg = parser.parseText(text)
    if (not parser.ok) {
        ok = false
    }
    if (cfg.aggression != 0.9f64) {
        ok = false
    }
    if (cfg.roleStickiness != 0.2f64) {
        ok = false
    }
    if (cfg.expansion != 0.75f64) {
        ok = false
    }
    if (cfg.escort != 0.1f64) {
        ok = false
    }
    if (cfg.agreementAppetite != 0.8f64) {
        ok = false
    }
    if (cfg.techVsHulls != 0.3f64) {
        ok = false
    }
    if (cfg.reactionLagTicks != 3) {
        ok = false
    }
    if (cfg.reactionLagSeconds != 4.5f64) {
        ok = false
    }
    if (cfg.surpriseRate != 1.0f64) {
        ok = false
    }
    if (cfg.seed != 99u) {
        ok = false
    }
    if (cfg.playerId != 2) {
        ok = false
    }
    if (not cfg.host.equals("10.0.0.2")) {
        ok = false
    }
    if (cfg.port != 7777) {
        ok = false
    }
    if (cfg.verbosity != 2) {
        ok = false
    }
    if (cfg.cycles != 5) {
        ok = false
    }
    if (not cfg.once) {
        ok = false
    }
    if (not cfg.serveLoop) {
        ok = false
    }

    # Scenario-only keys must not silently no-op on the AI surface.
    String bad = ""
    bad.append("aggression = 0.5\n")
    bad.append("tick_period_seconds = 12\n")
    AiConfigParse badParser = AiConfigParse()
    AiConfig ignored = badParser.parseText(bad)
    if (badParser.ok) {
        ok = false
    }
    if (not badParser.lastError.startsWith("unknown AI config key:")) {
        ok = false
    }
    if (ignored.aggression != 0.5f64) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
