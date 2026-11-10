/*
 * src/server/aiSpawn.cw — spawn N AI clients via process (CPL-106).
 *
 * After the server listens, optionally launch stand-alone
 * cplanets-ai children. Each child gets its own config file
 * (copied from spawn_ai_template) with a unique display_name
 * and dial host/port matching the live listen bind.
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial AsyncProcess AI spawn helper.
 */

import process as P

include "../lib/playerNames.cw"
include "../lib/rng.cw"
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
     * Spawn cfg.spawnAiCount AI clients when count > 0.
     *
     * Purpose: operator convenience so one server config can
     * bring up a lobby with AI seats already dialing. Each child
     * receives `--config` pointing at a generated file under
     * spawn_ai_dir (or a temp dir). Requires spawn_ai_template.
     *
     * Parameters:
     *   cfg — loaded ServerConfig (spawn_* keys + host).
     *   listenPort — actual bound TCP port (may differ from
     *                cfg.port when ephemeral).
     *   seed — PRNG seed for name picks (usually cfg.seed).
     *
     * Returns: true when count is 0 or all children started;
     * false on missing template/bin or launch failure (lastError
     * set). Partial launches still keep started children.
     */
    bool spawnAll(ServerConfig cfg, int64 listenPort, int64 seed) {
        lastError = ""
        if (cfg.spawnAiCount < 1) {
            return(true)
        }
        if (cfg.spawnAiTemplate.trim().length < 1) {
            lastError = "spawn_ai_count > 0 requires spawn_ai_template"
            return(false)
        }
        Sys.FileSystem fs = Sys.FileSystem()
        if (not fs.isFile(cfg.spawnAiTemplate)) {
            lastError = format(
                "spawn_ai_template not found: {}",
                cfg.spawnAiTemplate)
            return(false)
        }
        String templateText = ""
        Sys.File input = Sys.File(cfg.spawnAiTemplate, "r")
        templateText = input.readAll()
        input.close()

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

        SeededRng rng = SeededRng(uint64(seed))
        if (seed < 1) {
            rng = SeededRng(1u)
        }
        PlayerNames pool = PlayerNames()
        String dialHost = cfg.host
        if (dialHost.equals("0.0.0.0") or dialHost.length < 1) {
            dialHost = "127.0.0.1"
        }

        int64 index = 0
        while (index < cfg.spawnAiCount) {
            String name = pool.pickUnused(rng, names)
            names.append(name)
            String path = fs.join(
                outDir, format("ai-spawn-{}.cfg", index))
            String body = buildChildConfig(
                templateText, name, dialHost, listenPort,
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
                    name, child.error())
                child.close()
                return(false)
            }
            children.append(child)
            print(format(
                "SPAWN_AI={} config={} name={}\n",
                index, path, name))
            index = index + 1
        }
        print(format("SPAWN_AI_COUNT={}\n", children.length))
        Sys.StandardIO().flush()
        return(true)
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
     * Purpose: start from the template text and append overlays
     * for display_name, host, port, and seed so the last key
     * wins for parsers that re-apply later lines (AI parse keeps
     * last write per key as sequential overlay — actually
     * AiConfigParse overwrites on each apply, so trailing
     * overlays win).
     *
     * Parameters:
     *   templateText — full template file body.
     *   name — unique display_name.
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
        body.append("# --- server spawn overlays (CPL-106) ---\n")
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
