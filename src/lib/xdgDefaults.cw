/*
 * src/lib/xdgDefaults.cw — ~/.config/cplanets default file pack.
 *
 * When --config is omitted (or the XDG pack is incomplete), create
 * server.cfg, human.cfg, and ai-{soft,mid,hard}.cfg under the
 * XDG config home. Existing files are never overwritten. Used by
 * cplanets-server, cplanets, and cplanets-ai (CPL-115).
 *
 * Created: 2026-11-11
 * Author: Auto
 *
 * Changelog:
 *   2026-11-11  CPL-115: XDG default config creation.
 */

# Callers must `import system as Sys` (server / human / AI mains do).

/*
 * XdgDefaults resolves and seeds the operator config directory.
 *
 * Prefers $XDG_CONFIG_HOME/cplanets, else $HOME/.config/cplanets.
 * ensureDefaults creates missing files only; lastError explains
 * mkdir / HOME failures.
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
     * human.cfg, and ai-{soft,mid,hard}.cfg. Never overwrites.
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
        if (not writeIfMissing(
            Sys.FileSystem().join(dir, "server.cfg"),
            defaultServerText())) {
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
     * AI clients (Alex/soft, Bethany/mid, Cameron/hard). Omitted
     * §14 keys keep Scenario() closed defaults.
     *
     * Parameters: none.
     *
     * Returns: config file text.
     */
    String defaultServerText() {
        String text = ""
        text.append("# CPlanets XDG default server config\n")
        text.append("# Created under ~/.config/cplanets/ (CPL-115).\n")
        text.append("# Edit freely; re-runs never overwrite this file.\n")
        text.append("# See doc/SERVER-CONFIG.md.\n\n")
        text.append("host = 127.0.0.1\n")
        text.append("port = 7700\n")
        text.append("players = 0\n")
        text.append("seed = 7\n")
        text.append("serve = true\n")
        text.append("cycles = 0\n")
        text.append("injectable = false\n")
        text.append("verbosity = 10\n")
        text.append("handshake_miss_ms = 5000\n")
        text.append("accept_poll_ms = 50\n\n")
        text.append("# Explicit AI clients (friendly name = display_name).\n")
        text.append("# Level selects ai-<level>.cfg beside this file.\n")
        text.append("ai-client = \"Alex\", soft\n")
        text.append("ai-client = \"Bethany\", mid\n")
        text.append("ai-client = \"Cameron\", hard\n\n")
        text.append("spawn_ai_dir =\n")
        text.append("spawn_ai_bin =\n\n")
        text.append("scenario_mode = closed\n")
        text.append("tick_period_seconds = 5\n")
        text.append("world_count = 24\n")
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
