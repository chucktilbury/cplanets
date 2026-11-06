/*
 * tests/unit/unit_aiReaction.cw — reaction lag either-gate unit.
 *
 * First update always allowed; then tick lag and wall lag each
 * unlock independently (OR).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial reaction-lag unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "ai/config.cw"
include "ai/reaction.cw"

start {
    bool ok = true
    AiConfig cfg = AiConfig()
    cfg.reactionLagTicks = 3
    cfg.reactionLagSeconds = 5.0
    cfg.clampAll()
    ReactionLag lag = ReactionLag()

    if (not lag.shouldUpdate(cfg, 0, 0u)) {
        ok = false
    }
    lag.markUpdated(0, 0u)

    if (lag.shouldUpdate(cfg, 1, 1000u)) {
        ok = false
    }
    if (not lag.shouldUpdate(cfg, 3, 1000u)) {
        ok = false
    }
    lag.markUpdated(3, 1000u)

    if (lag.shouldUpdate(cfg, 4, 2000u)) {
        ok = false
    }
    if (not lag.shouldUpdate(cfg, 4, 6000u)) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
