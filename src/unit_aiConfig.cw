/*
 * src/unit_aiConfig.cw — unit program for AiConfigParse.
 *
 * Overlays AI axes from application text; checks clamp and that
 * the AI config is not the scenario setup surface.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AI config unit program.
 */

include "ai/configParse.cw"

start {
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
    text.append("tick_period_seconds = 12\n")
    AiConfigParse parser = AiConfigParse()
    AiConfig cfg = parser.parseText(text)
    bool ok = true
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
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
