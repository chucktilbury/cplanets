/*
 * src/client/configParse.cw — load human client settings (G).
 *
 * Separate file from AI config (RULES §2). Application key =
 * value text; unknown keys ignored.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial HumanConfigParse.
 *   2026-11-07  CLI mirror mode flags: once, pull, gui, test.
 *   2026-11-09  refresh_ms GUI state/digest poll period.
 */

include "config.cw"

/*
 * HumanConfigParse turns settings text into a HumanConfig.
 */
class HumanConfigParse {
    /*
     * Construct a stateless parser helper.
     *
     * Purpose: match AiConfigParse / SetupParse layout.
     *
     * Parameters: none.
     *
     * Returns: HumanConfigParse instance.
     */
    HumanConfigParse() {
    }

    /*
     * Parse a full human settings document.
     *
     * Purpose: load dial knobs without a stdlib format. Blank
     * lines and # comments are skipped.
     *
     * Parameters:
     *   text — entire settings body.
     *
     * Returns: HumanConfig with overlays applied and clamped.
     */
    HumanConfig parseText(String text) {
        HumanConfig cfg = HumanConfig()
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
     *
     * Parameters:
     *   cfg — mutable HumanConfig.
     *   line — trimmed non-comment line.
     *
     * Returns: nothing.
     */
    void applyLine(HumanConfig cfg, String line) {
        list parts = line.split("=")
        if (parts.length < 2) {
            return()
        }
        String key = parts[0]
        String val = parts[1]
        key = key.trim()
        val = val.trim()
        if (key.equals("player_id")) {
            cfg.playerId = val.toInt64()
        } else (key.equals("host")) {
            cfg.host = val
        } else (key.equals("port")) {
            cfg.port = val.toInt64()
        } else (key.equals("once")) {
            cfg.once = parseBool(val)
        } else (key.equals("pull")) {
            cfg.pull = parseBool(val)
        } else (key.equals("gui")) {
            cfg.gui = parseBool(val)
        } else (key.equals("test")) {
            cfg.test = parseBool(val)
        } else (key.equals("refresh_ms")) {
            cfg.refreshMs = val.toInt64()
        }
    }

    /*
     * Parse a bool from human settings text.
     *
     * Purpose: accept true/false/1/0 for mode flags without a
     * stdlib bool parser (matches SetupParse / AiConfigParse).
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
