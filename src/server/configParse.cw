/*
 * src/server/configParse.cw — load unified server config text.
 *
 * Same key = value application text as AI/human configs. One key
 * set: process/network plus former §14 scenario magnitudes.
 * Unknown keys fail loud (ok=false + lastError). The legacy
 * `setup = PATH` key is rejected with a migration hint.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerConfigParse.
 *   2026-11-07  handshake_miss_ms + accept_poll_ms keys.
 *   2026-11-08  menu key for operator status console.
 *   2026-11-08  Drop menu key (status via stdin m while serving).
 *   2026-11-09  Accept §14 scenario keys; reject setup= path.
 *   2026-11-09  recv_buffer_bytes, seat_hard_cap, verbose_capture_lines.
 *   2026-11-10  spawn_ai_count / template / dir / bin (CPL-106).
 */

include "../lib/setupParse.cw"
include "config.cw"

/*
 * ServerConfigParse turns application text into a ServerConfig.
 *
 * Starts from ServerConfig() defaults (including Scenario()),
 * overlays recognized process and §14 keys, then clampAll().
 * File I/O stays with the caller. Check ok after parseText;
 * lastError names the first unknown key, malformed line, or
 * rejected legacy setup path. Accepts both `host` and `address`
 * for the bind string.
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
     * Purpose: load process/network and §14 knobs without a stdlib
     * format. Blank lines and # comments are skipped. Resets
     * ok/lastError for this parse. On unknown key or malformed
     * line, ok becomes false and lastError is set; overlay still
     * continues.
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
     * Purpose: name every process/network knob and every former
     * scenario §14 key so one operator file drives serve start.
     * `host` and `address` both set the bind string. Legacy
     * `setup` fails loud with a migration message. Unknown keys
     * fail loud (first error wins).
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
            if (ok) {
                ok = false
                lastError = "setup path removed; fold §14 keys into this server config (see doc/SERVER-CONFIG.md)"
            }
            return()
        }
        if (key.equals("host") or key.equals("address")) {
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
        } else (key.equals("handshake_miss_ms")) {
            cfg.handshakeMissMs = val.toInt64()
        } else (key.equals("accept_poll_ms")) {
            cfg.acceptPollMs = val.toInt64()
        } else (key.equals("recv_buffer_bytes")) {
            cfg.recvBufferBytes = val.toInt64()
        } else (key.equals("seat_hard_cap")) {
            cfg.seatHardCap = val.toInt64()
        } else (key.equals("verbose_capture_lines")) {
            cfg.verboseCaptureLines = val.toInt64()
        } else (key.equals("spawn_ai_count")) {
            cfg.spawnAiCount = val.toInt64()
        } else (key.equals("spawn_ai_template")) {
            cfg.spawnAiTemplate = val
        } else (key.equals("spawn_ai_dir")) {
            cfg.spawnAiDir = val
        } else (key.equals("spawn_ai_bin")) {
            cfg.spawnAiBin = val
        } else {
            applyScenarioKey(cfg, key, val)
        }
    }

    /*
     * Overlay one §14 scenario key onto cfg.scenario.
     *
     * Purpose: reuse SetupParse key names so closed-default
     * fragments stay valid when pasted into a server config.
     * Rewrite "unknown setup key" to "unknown server config key".
     *
     * Parameters:
     *   cfg — mutable ServerConfig (scenario nested).
     *   key — §14 field name.
     *   val — trimmed value text.
     *
     * Returns: nothing.
     */
    void applyScenarioKey(ServerConfig cfg, String key, String val) {
        SetupParse setup = SetupParse()
        setup.applyPair(cfg.scenario, key, val)
        if (not setup.ok) {
            if (ok) {
                ok = false
                if (setup.lastError.startsWith("unknown setup key:")) {
                    lastError = format(
                        "unknown server config key: {}", key)
                } else {
                    lastError = setup.lastError
                }
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
