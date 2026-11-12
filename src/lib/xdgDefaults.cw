/*
 * src/lib/xdgDefaults.cw — ~/.config/cplanets default file pack.
 *
 * When --config is omitted (or the XDG pack is incomplete), create
 * server.cfg, human.cfg, and ai-{soft,mid,hard}.cfg under the
 * XDG config home. Human/AI files are never overwritten. A
 * generated server.cfg that is missing the CPL-116 full key set is
 * rewritten in place (auto-heal); hand-edited files without the
 * XDG header are left alone. Used by cplanets-server, cplanets,
 * and cplanets-ai (CPL-115/116/117).
 *
 * Created: 2026-11-11
 * Author: Auto
 *
 * Changelog:
 *   2026-11-11  CPL-115: XDG default config creation.
 *   2026-11-11  CPL-116: default server.cfg lists every server key.
 *   2026-11-12  CPL-117: auto-heal incomplete generated server.cfg.
 */

# Callers must `import system as Sys` (server / human / AI mains do).

/*
 * XdgDefaults resolves and seeds the operator config directory.
 *
 * Prefers $XDG_CONFIG_HOME/cplanets, else $HOME/.config/cplanets.
 * ensureDefaults creates missing files and rewrites an incomplete
 * generated server.cfg; lastError explains mkdir / HOME failures.
 */
class XdgDefaults {
    String lastError

    /*
     * Construct the XDG helper.
     *
     * Purpose: hold lastError for callers that ensure then load.
     *
     * Parameters: none.
     *
     * Returns: XdgDefaults with empty lastError.
     */
    XdgDefaults() {
        lastError = ""
    }

    /*
     * Resolve the cplanets config directory path.
     *
     * Purpose: honor XDG_CONFIG_HOME when set; otherwise
     * $HOME/.config/cplanets. Does not create the directory.
     *
     * Parameters: none.
     *
     * Returns: absolute-ish config dir string, or "" when HOME
     * and XDG_CONFIG_HOME are both empty (lastError set).
     */
    String configDir() {
        lastError = ""
        Sys.FileSystem fs = Sys.FileSystem()
        Sys.Process proc = Sys.Process()
        String xdg = proc.getEnv("XDG_CONFIG_HOME").trim()
        if (xdg.length > 0) {
            return(fs.join(xdg, "cplanets"))
        }
        String home = proc.getEnv("HOME").trim()
        if (home.length < 1) {
            lastError = "HOME and XDG_CONFIG_HOME are unset"
            return("")
        }
        return(fs.join(fs.join(home, ".config"), "cplanets"))
    }

    /*
     * Default server.cfg path under the XDG pack.
     *
     * Purpose: --config omit path for cplanets-server.
     *
     * Parameters: none.
     *
     * Returns: …/cplanets/server.cfg or "" on resolve failure.
     */
    String serverConfigPath() {
        String dir = configDir()
        if (dir.length < 1) {
            return("")
        }
        return(Sys.FileSystem().join(dir, "server.cfg"))
    }

    /*
     * Default human.cfg path under the XDG pack.
     *
     * Purpose: --config omit path for the GUI / human client.
     *
     * Parameters: none.
     *
     * Returns: …/cplanets/human.cfg or "" on resolve failure.
     */
    String humanConfigPath() {
        String dir = configDir()
        if (dir.length < 1) {
            return("")
        }
        return(Sys.FileSystem().join(dir, "human.cfg"))
    }

    /*
     * Default AI level config path (ai-<level>.cfg).
     *
     * Purpose: --config omit for cplanets-ai (soft) and spawn
     * template lookup beside the XDG pack.
     *
     * Parameters:
     *   level — difficulty token (soft/mid/hard/…); empty → soft.
     *
     * Returns: …/cplanets/ai-<level>.cfg or "" on resolve failure.
     */
    String aiLevelPath(String level) {
        String dir = configDir()
        if (dir.length < 1) {
            return("")
        }
        String token = level.trim()
        if (token.length < 1) {
            token = "soft"
        }
        return(Sys.FileSystem().join(
            dir, format("ai-{}.cfg", token)))
    }

    /*
     * Create missing default configs under the XDG directory.
     *
     * Purpose: first-run bootstrap so operators can start without
     * --config. Writes server.cfg (with three ai-client lines),
     * human.cfg, and ai-{soft,mid,hard}.cfg. Human/AI files are
     * never overwritten. An incomplete *generated* server.cfg
     * (XDG header present, CPL-116 sentinels missing) is rewritten
     * with the full key set (CPL-117 auto-heal).
     *
     * Parameters: none.
     *
     * Returns: true when the directory and all required files
     * exist afterward; false on mkdir/write failure (lastError).
     */
    bool ensureDefaults() {
        lastError = ""
        String dir = configDir()
        if (dir.length < 1) {
            return(false)
        }
        if (not ensureDir(dir)) {
            return(false)
        }
        if (not ensureServerConfig(
            Sys.FileSystem().join(dir, "server.cfg"))) {
            return(false)
        }
        if (not writeIfMissing(
            Sys.FileSystem().join(dir, "human.cfg"),
            defaultHumanText())) {
            return(false)
        }
        if (not writeIfMissing(
            Sys.FileSystem().join(dir, "ai-soft.cfg"),
            defaultAiLevelText("soft"))) {
            return(false)
        }
        if (not writeIfMissing(
            Sys.FileSystem().join(dir, "ai-mid.cfg"),
            defaultAiLevelText("mid"))) {
            return(false)
        }
        if (not writeIfMissing(
            Sys.FileSystem().join(dir, "ai-hard.cfg"),
            defaultAiLevelText("hard"))) {
            return(false)
        }
        return(true)
    }

    /*
     * Recursively create a directory path.
     *
     * Purpose: mkdir -p for ~/.config/cplanets when parents are
     * missing. FileSystem.mkdir is not recursive.
     *
     * Parameters:
     *   path — directory to ensure.
     *
     * Returns: true when path is a directory afterward.
     */
    bool ensureDir(String path) {
        Sys.FileSystem fs = Sys.FileSystem()
        if (fs.isDir(path)) {
            return(true)
        }
        if (fs.exists(path)) {
            lastError = format("not a directory: {}", path)
            return(false)
        }
        String parent = fs.dirname(path)
        if (parent.length > 0
            and not parent.equals(path)
            and not fs.isDir(parent)) {
            if (not ensureDir(parent)) {
                return(false)
            }
        }
        if (not fs.mkdir(path)) {
            lastError = format("cannot mkdir: {}", path)
            return(false)
        }
        return(true)
    }

    /*
     * Write text only when the path does not already exist.
     *
     * Purpose: first-run create without clobbering operator edits.
     *
     * Parameters:
     *   path — destination file.
     *   body — full file contents.
     *
     * Returns: true when the file exists afterward (created or
     * already present); false on write failure.
     */
    bool writeIfMissing(String path, String body) {
        Sys.FileSystem fs = Sys.FileSystem()
        if (fs.isFile(path)) {
            return(true)
        }
        if (fs.exists(path)) {
            lastError = format("path exists but is not a file: {}", path)
            return(false)
        }
        return(writeText(path, body))
    }

    /*
     * Ensure server.cfg exists with the full default key set.
     *
     * Purpose: create on first run; rewrite a stale CPL-115-era
     * generated stub that still carries the XDG header but lacks
     * CPL-116 sentinels (seat_hard_cap, etc.). Hand-edited files
     * without the XDG header are left alone even if sparse.
     *
     * Parameters:
     *   path — …/cplanets/server.cfg.
     *
     * Returns: true when the file exists afterward with either a
     * full generated body or an untouched operator file.
     */
    bool ensureServerConfig(String path) {
        Sys.FileSystem fs = Sys.FileSystem()
        if (not fs.isFile(path)) {
            if (fs.exists(path)) {
                lastError = format(
                    "path exists but is not a file: {}", path)
                return(false)
            }
            return(writeText(path, defaultServerText()))
        }
        String existing = ""
        try {
            Sys.File input = Sys.File(path, "r")
            existing = input.readAll()
            input.close()
        } except() as error {
            lastError = format(
                "cannot read '{}': {}", path, error)
            return(false)
        }
        if (not isGeneratedServerStub(existing)) {
            return(true)
        }
        if (hasFullServerKeySet(existing)) {
            return(true)
        }
        return(writeText(path, defaultServerText()))
    }

    /*
     * True when text looks like an auto-generated XDG server.cfg.
     *
     * Purpose: gate auto-heal so hand-edited configs are never
     * rewritten. Matches the CPL-115/116 header line.
     *
     * Parameters:
     *   text — current file body.
     *
     * Returns: true when the XDG creation marker is present.
     */
    bool isGeneratedServerStub(String text) {
        if (text.contains("Created under ~/.config/cplanets/")) {
            return(true)
        }
        return(false)
    }

    /*
     * True when text already lists the CPL-116 full key set.
     *
     * Purpose: skip rewrite when the generated file is complete.
     * Sentinels span process, clock, economy, and display sections.
     *
     * Parameters:
     *   text — current file body.
     *
     * Returns: true when every sentinel key appears.
     */
    bool hasFullServerKeySet(String text) {
        if (not text.contains("seat_hard_cap =")) {
            return(false)
        }
        if (not text.contains("recv_buffer_bytes =")) {
            return(false)
        }
        if (not text.contains("verbose_capture_lines =")) {
            return(false)
        }
        if (not text.contains("tick_auto_config_from_ai_lag =")) {
            return(false)
        }
        if (not text.contains("yard_build_extra_hull_time_frac =")) {
            return(false)
        }
        if (not text.contains("productive_rate =")) {
            return(false)
        }
        if (not text.contains("wealth_upkeep_tick_rate =")) {
            return(false)
        }
        if (not text.contains("design_scout_speed =")) {
            return(false)
        }
        if (not text.contains("livability_display_max =")) {
            return(false)
        }
        return(true)
    }

    /*
     * Write full text to path (create or truncate).
     *
     * Purpose: shared create/rewrite helper for ensureDefaults.
     *
     * Parameters:
     *   path — destination file.
     *   body — full file contents.
     *
     * Returns: true on success; false on write failure (lastError).
     */
    bool writeText(String path, String body) {
        try {
            Sys.File out = Sys.File(path, "w")
            out.write(body)
            out.close()
        } except() as error {
            lastError = format(
                "cannot write '{}': {}", path, error)
            return(false)
        }
        return(true)
    }

    /*
     * Builtin default server.cfg body.
     *
     * Purpose: seed a playable loopback serve with three named
     * AI clients (Alex/soft, Bethany/mid, Cameron/hard). Emits
     * every process/network and §14 key the server understands
     * (same magnitudes as config/server-default.cfg) so operators
     * see the full knob set without relying on silent ctor fills
     * (CPL-116).
     *
     * Parameters: none.
     *
     * Returns: config file text.
     */
    String defaultServerText() {
        String text = ""
        text.append("# CPlanets XDG default server config\n")
        text.append("# Created under ~/.config/cplanets/ (CPL-115/116).\n")
        text.append("# Edit freely. Incomplete generated stubs are\n")
        text.append("# rewritten on the next omit-config start; remove\n")
        text.append("# the XDG header line to keep a hand-edited file.\n")
        text.append("# Lists every server key with closed defaults.\n")
        text.append("# See doc/SERVER-CONFIG.md.\n\n")
        text.append("# --- listen bind ---\n")
        text.append("host = 127.0.0.1\n")
        text.append("port = 7700\n\n")
        text.append("# --- start galaxy process knobs ---\n")
        text.append("players = 0\n")
        text.append("seed = 7\n")
        text.append("seat_hard_cap = 256\n\n")
        text.append("# --- serve loop ---\n")
        text.append("serve = true\n")
        text.append("cycles = 0\n")
        text.append("injectable = false\n")
        text.append("verbosity = 10\n")
        text.append("verbose_capture_lines = 64\n\n")
        text.append("# --- presence / accept poll / recv ---\n")
        text.append("handshake_miss_ms = 5000\n")
        text.append("accept_poll_ms = 50\n")
        text.append("recv_buffer_bytes = 65536\n\n")
        text.append("# Explicit AI clients (friendly name = display_name).\n")
        text.append("# Level selects ai-<level>.cfg beside this file.\n")
        text.append("ai-client = \"Alex\", soft\n")
        text.append("ai-client = \"Bethany\", mid\n")
        text.append("ai-client = \"Cameron\", hard\n")
        text.append("spawn_ai_dir =\n")
        text.append("spawn_ai_bin =\n\n")
        text.append("# === §14 scenario / galaxy knobs ===\n")
        text.append("# --- clock ---\n")
        text.append("scenario_mode = closed\n")
        text.append("tick_period_seconds = 5\n")
        text.append("tick_auto_config_from_ai_lag = true\n")
        text.append("ai_reaction_lag_ticks = 1\n")
        text.append("ai_reaction_lag_seconds = 5.0\n")
        text.append("afk_timeout_seconds = 120.0\n")
        text.append("afk_shrink_factor = 1.0\n\n")
        text.append("# --- galaxy ---\n")
        text.append("world_count = 24\n")
        text.append("useful_mix = 0.35\n")
        text.append("scout_range = 3.0\n")
        text.append("galaxy_radius = 20.0\n\n")
        text.append("# --- identify ---\n")
        text.append("identify_attacker_base = 0.35\n")
        text.append("identify_attacker_per_attr = 0.05\n")
        text.append("identify_defender_base = 0.20\n")
        text.append("identify_defender_per_attr = 0.04\n\n")
        text.append("# --- travel / combat / tech ---\n")
        text.append("tech_range_base = 3.0\n")
        text.append("tech_range_per_tech = 0.5\n")
        text.append("tech_teleport_threshold = 10.0\n")
        text.append("tech_teleport_enabled = true\n")
        text.append("attack_bump = 1.0\n")
        text.append("pirate_attrition = 0.30\n")
        text.append("pirate_leftover = 0.05\n")
        text.append("pirate_idle_ticks = 10\n")
        text.append("battle_strength_duration_coeff = 1.0\n")
        text.append("battle_short_circuit_gap = 3.0\n")
        text.append("productive_inherent_defense = 1.0\n")
        text.append("stranded_ticks_n = 5\n")
        text.append("voyage_cost = 0.0\n\n")
        text.append("# --- economy / design / dispatch ---\n")
        text.append("design_develop_ticks = 5\n")
        text.append("yard_build_ticks = 3\n")
        text.append("yard_build_extra_hull_time_frac = 0.10\n")
        text.append("design_speed_cost_coeff = 1.0\n")
        text.append("design_range_cost_coeff = 1.0\n")
        text.append("reclaim_percent = 0.50\n")
        text.append("capture_use_chance = 0.25\n")
        text.append("cover_factor = 1.0\n")
        text.append("trade_bump = 1.20\n")
        text.append("dispatch_weight_scout = 0.1\n")
        text.append("dispatch_weight_colony = 5.0\n")
        text.append("start_wealth = 1000.0\n")
        text.append("start_resources = 500.0\n")
        text.append("start_tech = 1.0\n")
        text.append("start_power = 1.0\n")
        text.append("start_experience = 0.0\n\n")
        text.append("# --- production / yard / design cost bases ---\n")
        text.append("production_tick_rate = 0.01\n")
        text.append("yard_build_cost_per_size = 10.0\n")
        text.append("design_develop_cost_per_size = 50.0\n")
        text.append("colony_hop_fraction = 0.5\n\n")
        text.append("# --- galaxy spawn fractions / fallbacks ---\n")
        text.append("home_spawn_min_radius_fraction = 0.25\n")
        text.append("home_spawn_max_radius_fraction = 0.95\n")
        text.append("home_spawn_min_radius_floor = 0.5\n")
        text.append("useful_livability_fraction = 0.6\n")
        text.append("poor_livability_fraction = 0.2\n")
        text.append("poor_resources_fraction = 0.5\n")
        text.append("home_fallback_livability = 50.0\n")
        text.append("home_fallback_resources = 50.0\n")
        text.append("contact_reach = 4.0\n\n")
        text.append("# --- planetary resources / accessibility ---\n")
        text.append("rare_mineral_weight = 2.0\n")
        text.append("access_min = 0.35\n")
        text.append("access_max = 1.0\n")
        text.append("access_floor = 0.20\n")
        text.append("habit_base_ticks = 1\n")
        text.append("habit_base_wealth_cost = 25.0\n")
        text.append("wealth_upkeep_tick_rate = 0.003\n")
        text.append("resources_upkeep_tick_rate = 0.003\n")
        text.append("productive_rate = 1.0\n\n")
        text.append("# --- default hull template magnitudes ---\n")
        text.append("design_scout_speed = 2.0\n")
        text.append("design_scout_size = 0.5\n")
        text.append("design_colony_speed = 1.0\n")
        text.append("design_colony_size = 5.0\n")
        text.append("design_colony_hold = 10.0\n")
        text.append("design_freighter_speed = 1.0\n")
        text.append("design_freighter_size = 2.0\n")
        text.append("design_freighter_hold = 10.0\n")
        text.append("design_escort_speed = 1.5\n")
        text.append("design_escort_size = 3.0\n")
        text.append("design_frigate_speed = 1.5\n")
        text.append("design_frigate_size = 2.0\n")
        text.append("design_destroyer_speed = 1.0\n")
        text.append("design_destroyer_size = 8.0\n\n")
        text.append("# --- display (livability 1–10 mapping) ---\n")
        text.append("livability_internal_min = 0.0\n")
        text.append("livability_internal_max = 100.0\n")
        text.append("livability_display_min = 1\n")
        text.append("livability_display_max = 10\n")
        return(text)
    }

    /*
     * Builtin default human.cfg body.
     *
     * Purpose: seed the GUI client dial + display_name. No server
     * config dialog yet — file only (CPL-115).
     *
     * Parameters: none.
     *
     * Returns: config file text.
     */
    String defaultHumanText() {
        String text = ""
        text.append("# CPlanets XDG default human / GUI client config\n")
        text.append("# Created under ~/.config/cplanets/ (CPL-115).\n")
        text.append("# Edit freely; re-runs never overwrite this file.\n")
        text.append("# See doc/HUMAN-CLIENT-CONFIG.md.\n\n")
        text.append("host = 127.0.0.1\n")
        text.append("port = 7700\n")
        text.append("display_name = Human\n")
        text.append("once = false\n")
        text.append("pull = false\n")
        text.append("gui = true\n")
        text.append("test = false\n")
        text.append("refresh_ms = 1000\n")
        return(text)
    }

    /*
     * Builtin default ai-<level>.cfg body.
     *
     * Purpose: seed soft/mid/hard difficulty axis packs used by
     * `ai-client = name, level` and stand-alone cplanets-ai.
     *
     * Parameters:
     *   level — soft, mid, or hard (other tokens get mid axes).
     *
     * Returns: config file text.
     */
    String defaultAiLevelText(String level) {
        String token = level.trim().toLower()
        fp64 aggression = 0.55f64
        fp64 stickiness = 0.70f64
        fp64 expansion = 0.50f64
        fp64 escort = 0.55f64
        fp64 appetite = 0.40f64
        fp64 tech = 0.45f64
        int64 lagTicks = 1
        fp64 lagSeconds = 5.0f64
        fp64 surprise = 0.05f64
        if (token.equals("soft")) {
            aggression = 0.25f64
            stickiness = 0.80f64
            expansion = 0.35f64
            escort = 0.40f64
            appetite = 0.55f64
            tech = 0.40f64
            lagTicks = 2
            lagSeconds = 8.0f64
            surprise = 0.02f64
        } else (token.equals("hard")) {
            aggression = 0.85f64
            stickiness = 0.55f64
            expansion = 0.80f64
            escort = 0.70f64
            appetite = 0.25f64
            tech = 0.55f64
            lagTicks = 1
            lagSeconds = 3.0f64
            surprise = 0.10f64
        }
        String text = ""
        text.append(format(
            "# CPlanets XDG default AI level ({})\n", token))
        text.append("# Created under ~/.config/cplanets/ (CPL-115).\n")
        text.append("# See doc/AI-CLIENT-CONFIG.md.\n\n")
        text.append(format("aggression = {}\n", aggression))
        text.append(format("role_stickiness = {}\n", stickiness))
        text.append(format("expansion = {}\n", expansion))
        text.append(format("escort = {}\n", escort))
        text.append(format(
            "agreement_appetite = {}\n", appetite))
        text.append(format("tech_vs_hulls = {}\n", tech))
        text.append(format(
            "reaction_lag_ticks = {}\n", lagTicks))
        text.append(format(
            "reaction_lag_seconds = {}\n", lagSeconds))
        text.append(format("surprise_rate = {}\n", surprise))
        text.append("seed = 42\n")
        text.append("host = 127.0.0.1\n")
        text.append("port = 7700\n")
        text.append("cycles = 0\n")
        text.append("once = false\n")
        text.append("serve_loop = true\n")
        text.append("verbosity = 10\n")
        text.append("loop_period_ms = 100\n")
        return(text)
    }
}
