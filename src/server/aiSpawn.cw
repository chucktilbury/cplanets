/*
 * src/server/aiSpawn.cw — spawn explicit AI clients via process.
 *
 * After the server listens, optionally launch stand-alone
 * cplanets-ai children listed by `ai-client = "name", level` in
 * the server config. Each child gets its own config file copied
 * from `ai-<level>.cfg` with display_name set to the friendly
 * name and dial host/port matching the live listen bind (CPL-115).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial AsyncProcess AI spawn helper (CPL-106).
 *   2026-11-11  CPL-115: spawn from aiClients + ai-<level>.cfg.
 */

import process as P

include "../lib/xdgDefaults.cw"
include "aiClientEntry.cw"
include "config.cw"

# Callers must `import system as Sys` (cplanets-server does).

/*
 * AiSpawnBook tracks server-launched AI child processes.
 *
 * Writes per-child configs, starts AsyncProcess handles, and
 * cancels them on close. Does not tick or seat — children dial
 * TCP like any external AI client.
 */
class AiSpawnBook {
    list children
    list configPaths
    list names
    String lastError

    /*
     * Construct an empty spawn book.
     *
     * Purpose: hold child handles for the serve lifetime.
     *
     * Parameters: none.
     *
     * Returns: AiSpawnBook with empty lists.
     */
    AiSpawnBook() {
        children = []
        configPaths = []
        names = []
        lastError = ""
    }

    /*
     * Spawn every cfg.aiClients entry when the list is non-empty.
     *
     * Purpose: operator convenience so one server config can
     * bring up a lobby with named AI seats already dialing. Each
     * child receives `--config` pointing at a generated file under
     * spawn_ai_dir (or a temp dir). Level files are ai-<level>.cfg
     * resolved beside the server config, then XDG, then cwd.
     *
     * Parameters:
     *   cfg — loaded ServerConfig (aiClients + host + spawn_*).
     *   listenPort — actual bound TCP port (may differ from
     *                cfg.port when ephemeral).
     *   seed — PRNG seed for per-child seed overlays.
     *
     * Returns: true when the list is empty or all children started;
     * false on missing level/bin or launch failure (lastError
     * set). Partial launches still keep started children.
     */
    bool spawnAll(ServerConfig cfg, int64 listenPort, int64 seed) {
        lastError = ""
        if (cfg.aiClients.length < 1) {
            return(true)
        }
        Sys.FileSystem fs = Sys.FileSystem()
        String outDir = cfg.spawnAiDir.trim()
        if (outDir.length < 1) {
            outDir = fs.join(fs.tempDir(), "cplanets-ai-spawn")
        }
        if (not fs.exists(outDir)) {
            if (not fs.mkdir(outDir)) {
                lastError = format(
                    "cannot create spawn_ai_dir: {}", outDir)
                return(false)
            }
        }

        String bin = resolveAiBin(cfg.spawnAiBin)
        if (bin.length < 1 or not fs.isFile(bin)) {
            lastError = format(
                "cplanets-ai binary not found (spawn_ai_bin='{}')",
                cfg.spawnAiBin)
            return(false)
        }

        String dialHost = cfg.host
        if (dialHost.equals("0.0.0.0") or dialHost.length < 1) {
            dialHost = "127.0.0.1"
        }

        int64 index = 0
        while (index < cfg.aiClients.length) {
            AiClientEntry entry = cfg.aiClients[index]
            String level = entry.level.trim()
            if (level.length < 1) {
                level = "soft"
            }
            String templatePath = resolveLevelTemplate(
                cfg.configPath, level)
            if (templatePath.length < 1
                or not fs.isFile(templatePath)) {
                lastError = format(
                    "ai-client '{}': level file not found (ai-{}.cfg)",
                    entry.name, level)
                return(false)
            }
            String templateText = ""
            Sys.File input = Sys.File(templatePath, "r")
            templateText = input.readAll()
            input.close()

            names.append(entry.name)
            String path = fs.join(
                outDir, format("ai-spawn-{}.cfg", index))
            String body = buildChildConfig(
                templateText, entry.name, dialHost, listenPort,
                seed + index + 1)
            Sys.File out = Sys.File(path, "w")
            out.write(body)
            out.close()
            configPaths.append(path)

            list args = []
            args.append("--config")
            args.append(path)
            P.AsyncProcess child = P.AsyncProcess(bin, args)
            if (not child.started()) {
                lastError = format(
                    "failed to spawn AI '{}': {}",
                    entry.name, child.error())
                child.close()
                return(false)
            }
            children.append(child)
            print(format(
                "SPAWN_AI={} config={} name={} level={}\n",
                index, path, entry.name, level))
            index = index + 1
        }
        print(format("SPAWN_AI_COUNT={}\n", children.length))
        Sys.StandardIO().flush()
        return(true)
    }

    /*
     * Resolve ai-<level>.cfg for one AI client.
     *
     * Purpose: prefer the directory of the loaded server config,
     * then the XDG cplanets pack, then cwd / config/ checkout
     * layout so repo samples and first-run defaults both work.
     *
     * Parameters:
     *   serverConfigPath — cfg.configPath (may be empty).
     *   level — difficulty token (soft/mid/hard/…).
     *
     * Returns: path to an existing file, or the beside-server
     * candidate (for error text) when nothing is found.
     */
    String resolveLevelTemplate(
        String serverConfigPath,
        String level) {
        Sys.FileSystem fs = Sys.FileSystem()
        String fileName = format("ai-{}.cfg", level)
        if (serverConfigPath.trim().length > 0) {
            String dir = fs.dirname(serverConfigPath)
            if (dir.length > 0) {
                String beside = fs.join(dir, fileName)
                if (fs.isFile(beside)) {
                    return(beside)
                }
            }
        }
        XdgDefaults xdg = XdgDefaults()
        String xdgPath = xdg.aiLevelPath(level)
        if (xdgPath.length > 0 and fs.isFile(xdgPath)) {
            return(xdgPath)
        }
        if (fs.isFile(fileName)) {
            return(fileName)
        }
        String repo = fs.join("config", fileName)
        if (fs.isFile(repo)) {
            return(repo)
        }
        if (serverConfigPath.trim().length > 0) {
            String dir = fs.dirname(serverConfigPath)
            if (dir.length > 0) {
                return(fs.join(dir, fileName))
            }
        }
        return(fileName)
    }

    /*
     * Resolve the cplanets-ai executable path.
     *
     * Purpose: honor spawn_ai_bin when set; otherwise use a
     * sibling of argv[0] named cplanets-ai.
     *
     * Parameters:
     *   configured — spawn_ai_bin value (may be empty).
     *
     * Returns: absolute or relative path string (may not exist).
     */
    String resolveAiBin(String configured) {
        String trimmed = configured.trim()
        if (trimmed.length > 0) {
            return(trimmed)
        }
        Sys.FileSystem fs = Sys.FileSystem()
        String self = Sys.Process().arg(0)
        if (self.length < 1) {
            return("cplanets-ai")
        }
        String dir = fs.dirname(self)
        if (dir.length < 1) {
            return("cplanets-ai")
        }
        return(fs.join(dir, "cplanets-ai"))
    }

    /*
     * Build one per-child AI config document.
     *
     * Purpose: start from the level template text and append
     * overlays for display_name, host, port, and seed so trailing
     * keys win in AiConfigParse.
     *
     * Parameters:
     *   templateText — full level file body.
     *   name — friendly display_name from ai-client.
     *   host — dial host.
     *   port — dial port.
     *   childSeed — per-child seed.
     *
     * Returns: config file text.
     */
    String buildChildConfig(
        String templateText,
        String name,
        String host,
        int64 port,
        int64 childSeed) {
        # Copy first — String append mutates; do not grow templateText.
        String body = format("{}\n", templateText)
        body.append("# --- server spawn overlays (CPL-115) ---\n")
        body.append(format("display_name = {}\n", name))
        body.append(format("host = {}\n", host))
        body.append(format("port = {}\n", port))
        body.append(format("seed = {}\n", childSeed))
        body.append("serve_loop = true\n")
        body.append("once = false\n")
        return(body)
    }

    /*
     * Cancel and close every spawned AI child.
     *
     * Purpose: tear down AsyncProcess handles when the server
     * listen loop ends so children do not outlive the parent.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void closeAll() {
        int64 index = 0
        while (index < children.length) {
            P.AsyncProcess child = children[index]
            if (child != null) {
                if (not child.finished()) {
                    child.cancel(500)
                }
                child.close()
            }
            index = index + 1
        }
        children = []
    }
}
