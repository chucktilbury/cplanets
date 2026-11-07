/*
 * src/server/configParse.cw — load server runtime config text.
 *
 * Same key = value application text as AI/human configs and
 * scenario setup, but a separate key set: network + process only.
 * Galaxy §14 knobs stay in scenario files (RULES §14). Unknown
 * keys fail loud (ok=false + lastError).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerConfigParse.
 */

include "config.cw"

/*
 * ServerConfigParse turns application text into a ServerConfig.
 *
 * Starts from ServerConfig() defaults, overlays recognized keys,
 * then clampAll(). File I/O stays with the caller. Check ok after
 * parseText; lastError names the first unknown key or malformed
 * line. Accepts both `host` and `address` for the bind string.
 */
class ServerConfigParse {
    bool ok
    String lastError

    /*
     * Construct a stateless parser helper.
     *
     * Purpose: match AiConfigParse / SetupParse layout.
     *
     * Parameters: none.
     *
     * Returns: an empty ServerConfigParse instance with ok=true.
     */
    ServerConfigParse() {
        ok = true
        lastError = ""
    }

    /*
     * Parse a full server config document.
     *
     * Purpose: load process/network knobs without a stdlib format.
     * Blank lines and # comments are skipped. Resets ok/lastError
     * for this parse. On unknown key or malformed line, ok becomes
     * false and lastError is set; overlay still continues.
     *
     * Parameters:
     *   text — entire config body (newline-separated key = value).
     *
     * Returns: ServerConfig with overlays applied and bands clamped.
     * Check ok / lastError before trusting the result.
     */
    ServerConfig parseText(String text) {
        ok = true
        lastError = ""
        ServerConfig cfg = ServerConfig()
        list lines = text.split("\n")
        int64 index = 0
        while (index < lines.length) {
            String line = lines[index]
            line = line.trim()
            if (line.length > 0 and not line.startsWith("#")) {
                applyLine(cfg, line)
            }
            index = index + 1
        }
        cfg.clampAll()
        return(cfg)
    }

    /*
     * Apply one physical line to a config.
     *
     * Purpose: split on the first '=' and dispatch key/value.
     * Lines without '=' are a loud failure (not silent skips).
     *
     * Parameters:
     *   cfg — mutable ServerConfig.
     *   line — trimmed non-comment line.
     *
     * Returns: nothing.
     */
    void applyLine(ServerConfig cfg, String line) {
        list parts = line.split("=")
        if (parts.length < 2) {
            if (ok) {
                ok = false
                lastError = format(
                    "malformed server config line (need key = value): {}",
                    line)
            }
            return()
        }
        String key = parts[0]
        String val = parts[1]
        key = key.trim()
        val = val.trim()
        applyPair(cfg, key, val)
    }

    /*
     * Overlay one recognized server config key.
     *
     * Purpose: name every process/network knob so text and CLI stay
     * aligned. `host` and `address` both set the bind string.
     * Unknown keys fail loud (first error wins).
     *
     * Parameters:
     *   cfg — mutable ServerConfig.
     *   key — config field name.
     *   val — trimmed value text.
     *
     * Returns: nothing.
     */
    void applyPair(ServerConfig cfg, String key, String val) {
        if (key.equals("setup")) {
            cfg.setup = val
        } else (key.equals("host") or key.equals("address")) {
            cfg.host = val
        } else (key.equals("port")) {
            cfg.port = val.toInt64()
        } else (key.equals("players")) {
            cfg.players = val.toInt64()
        } else (key.equals("seed")) {
            cfg.seed = val.toInt64()
        } else (key.equals("cycles")) {
            cfg.cycles = val.toInt64()
        } else (key.equals("serve")) {
            cfg.serve = parseBool(val)
        } else (key.equals("injectable")) {
            cfg.injectable = parseBool(val)
        } else (key.equals("verbosity")) {
            cfg.verbosity = val.toInt64()
        } else {
            if (ok) {
                ok = false
                lastError = format(
                    "unknown server config key: {}", key)
            }
        }
    }

    /*
     * Parse a bool from server config text.
     *
     * Purpose: accept true/false/1/0 without a stdlib bool parser
     * (matches SetupParse / AiConfigParse).
     *
     * Parameters:
     *   val — trimmed token.
     *
     * Returns: true for "true"/"1"; otherwise false.
     */
    bool parseBool(String val) {
        if (val.equals("true") or val.equals("1")) {
            return(true)
        }
        return(false)
    }
}
