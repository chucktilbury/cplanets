/*
 * tests/unit/unit_setupLoad.cw — unit program for SetupParse overlays.
 *
 * Loads application text onto closed defaults; checks named knobs,
 * tick-period clamp, and loud failure on unknown keys. No file I/O
 * required (embedded text).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial setup-load unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-06  Unknown keys fail loud (TUNING A2).
 *   2026-11-07  Assert verbosity setup key.
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
    text.append("livability_display_max = 10\n")
    text.append("verbosity = 2\n")
    text.append("tick_period_seconds = 40\n")
    SetupParse parser = SetupParse()
    Scenario s = parser.parseText(text)
    bool ok = true
    if (not parser.ok) {
        ok = false
    }
    if (s.verbosity != 2) {
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

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
