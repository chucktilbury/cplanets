/*
 * src/ai/configParse.cw — load AI client config text (Phase H).
 *
 * Same key = value application text as scenario setup, but a
 * separate file and key set (RULES §2 — AI does not share the
 * human settings file). Unknown keys fail loud (ok=false +
 * lastError) so tuning typos cannot silently no-op.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AiConfigParse overlays.
 *   2026-11-06  Fail loud on unknown keys (TUNING A2).
 *   2026-11-07  verbosity key (AI stdout decision logging).
 */

include "config.cw"

/*
 * AiConfigParse turns application text into an AiConfig.
 *
 * Starts from AiConfig() defaults, overlays recognized keys, then
 * clampAll(). File I/O stays with the caller. Check ok after
 * parseText; lastError names the first unknown key or malformed
 * line.
 */
class AiConfigParse {
    bool ok
    String lastError

    /*
     * Construct a stateless parser helper.
     *
     * Purpose: match SetupParse layout; work lives in parseText.
     *
     * Parameters: none.
     *
     * Returns: an empty AiConfigParse instance with ok=true.
     */
    AiConfigParse() {
        ok = true
        lastError = ""
    }

    /*
     * Parse a full AI config document.
     *
     * Purpose: load stand-alone AI knobs without a stdlib format.
     * Blank lines and # comments are skipped. Resets ok/lastError
     * for this parse. On unknown key or malformed line, ok becomes
     * false and lastError is set; overlay still continues.
     *
     * Parameters:
     *   text — entire config body (newline-separated key = value).
     *
     * Returns: AiConfig with overlays applied and axes clamped.
     * Check ok / lastError before trusting the result.
     */
    AiConfig parseText(String text) {
        ok = true
        lastError = ""
        AiConfig cfg = AiConfig()
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
     *   cfg — mutable AiConfig.
     *   line — trimmed non-comment line.
     *
     * Returns: nothing.
     */
    void applyLine(AiConfig cfg, String line) {
        list parts = line.split("=")
        if (parts.length < 2) {
            if (ok) {
                ok = false
                lastError = format(
                    "malformed AI config line (need key = value): {}",
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
     * Overlay one recognized AI config key.
     *
     * Purpose: name every PLAN §4.H axis so text and code stay
     * aligned. Unknown keys fail loud (first error wins).
     *
     * Parameters:
     *   cfg — mutable AiConfig.
     *   key — config field name.
     *   val — trimmed value text.
     *
     * Returns: nothing.
     */
    void applyPair(AiConfig cfg, String key, String val) {
        if (key.equals("aggression")) {
            cfg.aggression = val.toFp64()
        } else (key.equals("role_stickiness")) {
            cfg.roleStickiness = val.toFp64()
        } else (key.equals("expansion")) {
            cfg.expansion = val.toFp64()
        } else (key.equals("escort")) {
            cfg.escort = val.toFp64()
        } else (key.equals("agreement_appetite")) {
            cfg.agreementAppetite = val.toFp64()
        } else (key.equals("tech_vs_hulls")) {
            cfg.techVsHulls = val.toFp64()
        } else (key.equals("reaction_lag_ticks")) {
            cfg.reactionLagTicks = val.toInt64()
        } else (key.equals("reaction_lag_seconds")) {
            cfg.reactionLagSeconds = val.toFp64()
        } else (key.equals("surprise_rate")) {
            cfg.surpriseRate = val.toFp64()
        } else (key.equals("seed")) {
            cfg.seed = uint64(val.toInt64())
        } else (key.equals("player_id")) {
            cfg.playerId = val.toInt64()
        } else (key.equals("host")) {
            cfg.host = val
        } else (key.equals("port")) {
            cfg.port = val.toInt64()
        } else (key.equals("verbosity")) {
            cfg.verbosity = val.toInt64()
        } else {
            if (ok) {
                ok = false
                lastError = format("unknown AI config key: {}", key)
            }
        }
    }
}
