/*
 * tests/unit/unit_identify.cw — identify asymmetry chance helpers.
 *
 * Asserts separate attacker/defender knobs, attacker advantage in
 * the closed fixture, attribute scaling, and clamp (PLAN D3 /
 * RULES §9).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial identify unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/identify.cw"
include "lib/player.cw"
include "lib/scenario.cw"

start {
    Identify id = Identify()
    Scenario scenario = Scenario()
    bool ok = true

    if (scenario.identifyAttackerBase
        <= scenario.identifyDefenderBase) {
        ok = false
    }

    Player weak = Player(0)
    weak.tech = 0.0
    Player strong = Player(1)
    strong.tech = 10.0

    fp64 a0 = id.attackerChance(scenario, weak)
    fp64 a1 = id.attackerChance(scenario, strong)
    fp64 d0 = id.defenderChance(scenario, weak)
    fp64 d1 = id.defenderChance(scenario, strong)
    if (a0 != scenario.identifyAttackerBase) {
        ok = false
    }
    if (d0 != scenario.identifyDefenderBase) {
        ok = false
    }
    if (a1 <= a0 or d1 <= d0) {
        ok = false
    }
    if (a0 <= d0) {
        ok = false
    }

    Scenario hot = Scenario()
    hot.identifyAttackerBase = 2.0
    hot.identifyDefenderBase = -1.0
    if (id.attackerChance(hot, weak) != 1.0) {
        ok = false
    }
    if (id.defenderChance(hot, weak) != 0.0) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
