/*
 * tests/unit/unit_xdgDefaults.cw — XDG default pack creation.
 *
 * Seeds a temp HOME and asserts ensureDefaults writes server.cfg,
 * human.cfg, and ai-{soft,mid,hard}.cfg without overwriting an
 * existing file (CPL-115).
 *
 * Created: 2026-11-11
 * Author: Auto
 *
 * Changelog:
 *   2026-11-11  Initial XDG defaults unit.
 *   2026-11-11  CPL-116: assert full server.cfg key coverage.
 */

import system as Sys

include "lib/xdgDefaults.cw"

start {
    bool ok = true
    Sys.FileSystem fs = Sys.FileSystem()
    Sys.Process proc = Sys.Process()
    String base = fs.join(fs.tempDir(), "cplanets-xdg-unit")
    if (not fs.exists(base)) {
        if (not fs.mkdir(base)) {
            ok = false
        }
    }
    String priorHome = proc.getEnv("HOME")
    String priorXdg = proc.getEnv("XDG_CONFIG_HOME")
    proc.setEnv("HOME", base)
    proc.setEnv("XDG_CONFIG_HOME", "")
    XdgDefaults xdg = XdgDefaults()
    if (not xdg.ensureDefaults()) {
        ok = false
    }
    String dir = xdg.configDir()
    if (ok and not fs.isDir(dir)) {
        ok = false
    }
    if (ok and not fs.isFile(fs.join(dir, "server.cfg"))) {
        ok = false
    }
    if (ok and not fs.isFile(fs.join(dir, "human.cfg"))) {
        ok = false
    }
    if (ok and not fs.isFile(fs.join(dir, "ai-soft.cfg"))) {
        ok = false
    }
    if (ok and not fs.isFile(fs.join(dir, "ai-mid.cfg"))) {
        ok = false
    }
    if (ok and not fs.isFile(fs.join(dir, "ai-hard.cfg"))) {
        ok = false
    }
    # Marker file: ensureDefaults must not overwrite.
    String humanPath = fs.join(dir, "human.cfg")
    Sys.File stamp = Sys.File(humanPath, "w")
    stamp.write("# stamped\n")
    stamp.close()
    if (not xdg.ensureDefaults()) {
        ok = false
    }
    Sys.File check = Sys.File(humanPath, "r")
    String body = check.readAll()
    check.close()
    if (ok and not body.startsWith("# stamped")) {
        ok = false
    }
    Sys.File serverIn = Sys.File(fs.join(dir, "server.cfg"), "r")
    String serverText = serverIn.readAll()
    serverIn.close()
    if (ok and not serverText.contains("ai-client = \"Alex\"")) {
        ok = false
    }
    if (ok and not serverText.contains("ai-client = \"Bethany\"")) {
        ok = false
    }
    if (ok and not serverText.contains("ai-client = \"Cameron\"")) {
        ok = false
    }
    # CPL-116: formerly omitted keys must appear with defaults.
    if (ok and not serverText.contains("seat_hard_cap =")) {
        ok = false
    }
    if (ok and not serverText.contains("verbose_capture_lines =")) {
        ok = false
    }
    if (ok and not serverText.contains("recv_buffer_bytes =")) {
        ok = false
    }
    if (ok and not serverText.contains("tick_auto_config_from_ai_lag =")) {
        ok = false
    }
    if (ok and not serverText.contains(
        "yard_build_extra_hull_time_frac =")) {
        ok = false
    }
    if (ok and not serverText.contains("productive_rate =")) {
        ok = false
    }
    if (ok and not serverText.contains("wealth_upkeep_tick_rate =")) {
        ok = false
    }
    if (ok and not serverText.contains("design_scout_speed =")) {
        ok = false
    }
    if (ok and not serverText.contains("livability_display_max =")) {
        ok = false
    }
    if (ok and not serverText.contains("rare_mineral_weight =")) {
        ok = false
    }
    if (ok and not serverText.contains("start_wealth =")) {
        ok = false
    }
    if (ok and not serverText.contains("galaxy_radius =")) {
        ok = false
    }
    if (priorHome.length > 0) {
        proc.setEnv("HOME", priorHome)
    }
    proc.setEnv("XDG_CONFIG_HOME", priorXdg)

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
