/*
 * tests/unit/unit_setupLoad.cw — unit program for SetupParse overlays.
 *
 * Loads application text onto closed defaults; checks named knobs,
 * tick-period clamp, and loud failure on unknown keys. No file I/O
 * required (embedded text). Process/network keys belong to the
 * server config surface (unit_serverConfig), not setup.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial setup-load unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-06  Unknown keys fail loud (TUNING A2).
 *   2026-11-07  Assert verbosity setup key.
 *   2026-11-07  Assert process CLI mirror keys.
 *   2026-11-07  Drop process-key asserts; reject them as unknown.
 *   2026-11-07  Assert production/galaxy/design template overlays.
 *   2026-11-11  Assert CPL-113 upkeep tick rate overlays.
 *   2026-11-11  Assert CPL-114 productive_rate overlay.
 */

include "lib/setupParse.cw"

start {
    String text = ""
    text.append("scenario_mode = closed\n")
    text.append("tick_period_seconds = 12\n")
    text.append("world_count = 18\n")
    text.append("identify_attacker_base = 0.4\n")
    text.append("identify_defender_base = 0.15\n")
    text.append("tech_teleport_threshold = 9.5\n")
    text.append("productive_inherent_defense = 1.5\n")
    text.append("production_tick_rate = 0.02\n")
    text.append("wealth_upkeep_tick_rate = 0.004\n")
    text.append("resources_upkeep_tick_rate = 0.005\n")
    text.append("productive_rate = 2.5\n")
    text.append("yard_build_cost_per_size = 12.0\n")
    text.append("design_develop_cost_per_size = 55.0\n")
    text.append("colony_hop_fraction = 0.4\n")
    text.append("home_spawn_min_radius_fraction = 0.3\n")
    text.append("design_scout_speed = 2.5\n")
    text.append("attack_bump = 1.25\n")
    text.append("livability_display_max = 10\n")
    text.append("tick_period_seconds = 40\n")
    SetupParse parser = SetupParse()
    Scenario s = parser.parseText(text)
    bool ok = true
    if (not parser.ok) {
        ok = false
    }
    if (not s.isClosed()) {
        ok = false
    }
    if (s.tickPeriodSeconds != 30) {
        ok = false
    }
    if (s.worldCount != 18) {
        ok = false
    }
    if (s.identifyAttackerBase != 0.4f64) {
        ok = false
    }
    if (s.identifyDefenderBase != 0.15f64) {
        ok = false
    }
    if (s.techTeleportThreshold != 9.5f64) {
        ok = false
    }
    if (s.productiveInherentDefense != 1.5f64) {
        ok = false
    }
    if (s.productionTickRate != 0.02f64) {
        ok = false
    }
    if (s.wealthUpkeepTickRate != 0.004f64) {
        ok = false
    }
    if (s.resourcesUpkeepTickRate != 0.005f64) {
        ok = false
    }
    if (s.productiveRate != 2.5f64) {
        ok = false
    }
    if (s.yardBuildCostPerSize != 12.0f64) {
        ok = false
    }
    if (s.designDevelopCostPerSize != 55.0f64) {
        ok = false
    }
    if (s.colonyHopFraction != 0.4f64) {
        ok = false
    }
    if (s.homeSpawnMinRadiusFraction != 0.3f64) {
        ok = false
    }
    if (s.designScoutSpeed != 2.5f64) {
        ok = false
    }
    if (s.attackBump != 1.25f64) {
        ok = false
    }
    if (s.livabilityDisplayMax != 10) {
        ok = false
    }
    if (s.scoutRange != 3.0f64) {
        ok = false
    }

    String bad = ""
    bad.append("world_count = 10\n")
    bad.append("not_a_real_knob = 1\n")
    SetupParse badParser = SetupParse()
    Scenario partial = badParser.parseText(bad)
    if (badParser.ok) {
        ok = false
    }
    if (not badParser.lastError.startsWith("unknown setup key:")) {
        ok = false
    }
    if (partial.worldCount != 10) {
        ok = false
    }

    # Former process keys must fail loud on the scenario surface.
    SetupParse processParser = SetupParse()
    processParser.parseText("port = 7700\n")
    if (processParser.ok) {
        ok = false
    }
    if (not processParser.lastError.startsWith("unknown setup key:")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
