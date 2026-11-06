/*
 * tests/fn/fn_ai.cw — Phase H AI policy shape + surprise band.
 *
 * Given seed + config → known policy shape. Over N updates,
 * surprise fires within a rate band. Legal-only; seeded;
 * same-visibility view (PLAN §4.H).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AI function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "ai/brain.cw"
include "ai/client.cw"
include "ai/config.cw"
include "ai/configParse.cw"
include "ai/policyShape.cw"
include "ai/reaction.cw"
include "ai/tickSuggest.cw"
include "ai/view.cw"
include "lib/scenario.cw"

start {
    bool ok = true

    # --- seed + config → known policy shape ---
    AiConfig cfg = AiConfig()
    cfg.aggression = 0.9
    cfg.roleStickiness = 0.0
    cfg.expansion = 0.6
    cfg.escort = 0.4
    cfg.agreementAppetite = 0.3
    cfg.techVsHulls = 0.8
    cfg.surpriseRate = 0.0
    cfg.seed = 42u
    cfg.clampAll()
    AiBrain brain = AiBrain(cfg)
    AiView view = AiView(0)
    view.currentRole = "neutral"
    view.ambushLocked = false
    view.publishedTick = 0
    AiPolicyShape shape = brain.generate(view)
    if (not shape.roleName.equals("conqueror")) {
        ok = false
    }
    if (shape.expansionPct != 60) {
        ok = false
    }
    if (shape.escortPct != 40) {
        ok = false
    }
    if (shape.agreementS != 30) {
        ok = false
    }
    if (shape.techBiasPct != 80) {
        ok = false
    }
    if (shape.surpriseApplied) {
        ok = false
    }
    buffer blob = shape.encode()
    AiPolicyShape round = AiPolicyShape()
    if (not round.decode(blob)) {
        ok = false
    }
    if (not round.roleName.equals("conqueror")) {
        ok = false
    }
    if (round.expansionPct != 60) {
        ok = false
    }

    # Ambush lock: pirate may not flip off while locked.
    AiConfig sticky = AiConfig()
    sticky.aggression = 0.1
    sticky.roleStickiness = 0.0
    sticky.surpriseRate = 0.0
    sticky.seed = 7u
    sticky.clampAll()
    AiBrain pirateBrain = AiBrain(sticky)
    AiView locked = AiView(1)
    locked.currentRole = "pirate"
    locked.ambushLocked = true
    AiPolicyShape hold = pirateBrain.generate(locked)
    if (not hold.roleName.equals("pirate")) {
        ok = false
    }

    # --- surprise band over N updates ---
    AiConfig surp = AiConfig()
    surp.aggression = 0.5
    surp.roleStickiness = 1.0
    surp.expansion = 0.5
    surp.escort = 0.5
    surp.agreementAppetite = 0.5
    surp.techVsHulls = 0.5
    surp.surpriseRate = 0.20
    surp.seed = 12345u
    surp.clampAll()
    AiBrain bandBrain = AiBrain(surp)
    AiView bandView = AiView(0)
    bandView.currentRole = "neutral"
    int64 fires = 0
    int64 n = 200
    int64 i = 0
    while (i < n) {
        AiPolicyShape s = bandBrain.generate(bandView)
        if (s.surpriseApplied) {
            fires = fires + 1
        }
        i = i + 1
    }
    # Binomial mean ~40; allow a wide but non-trivial band.
    if (fires < 20 or fires > 70) {
        ok = false
    }

    # Reproducible: same seed → same fire count.
    AiBrain bandBrain2 = AiBrain(surp)
    int64 fires2 = 0
    i = 0
    while (i < n) {
        AiPolicyShape s2 = bandBrain2.generate(bandView)
        if (s2.surpriseApplied) {
            fires2 = fires2 + 1
        }
        i = i + 1
    }
    if (fires2 != fires) {
        ok = false
    }

    # --- reaction lag + local client generate ---
    AiConfig lagCfg = AiConfig()
    lagCfg.surpriseRate = 0.0
    lagCfg.reactionLagTicks = 2
    lagCfg.reactionLagSeconds = 100.0
    lagCfg.seed = 3u
    lagCfg.clampAll()
    AiClient local = AiClient(lagCfg)
    AiView v0 = AiView(0)
    v0.publishedTick = 0
    AiPolicyShape first = local.generateLocal(v0, 0u)
    if (first.version != 1) {
        ok = false
    }
    AiView v1 = AiView(0)
    v1.publishedTick = 1
    AiPolicyShape skipped = local.generateLocal(v1, 10u)
    if (skipped.version != 0) {
        ok = false
    }
    AiView v2 = AiView(0)
    v2.publishedTick = 2
    AiPolicyShape second = local.generateLocal(v2, 20u)
    if (second.version != 1) {
        ok = false
    }

    # --- tick auto-config still setup-tunable ---
    Scenario sc = Scenario()
    sc.tickAutoConfigFromAiLag = true
    sc.aiReactionLagSeconds = 6.0
    sc.tickPeriodSeconds = 2
    TickSuggest ts = TickSuggest()
    if (ts.applyToScenario(sc) != 6) {
        ok = false
    }
    sc.tickAutoConfigFromAiLag = false
    sc.tickPeriodSeconds = 9
    sc.aiReactionLagSeconds = 1.0
    if (ts.applyToScenario(sc) != 9) {
        ok = false
    }

    # Config parse path (axes only; scenario keys ignored).
    String text = "aggression = 0.2\nsurprise_rate = 0.0\nseed = 5\n"
    AiConfigParse parser = AiConfigParse()
    AiConfig parsed = parser.parseText(text)
    if (parsed.aggression != 0.2f64) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
