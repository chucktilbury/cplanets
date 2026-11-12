/*
 * src/server/aiClientEntry.cw — one explicit AI seat from server cfg.
 *
 * Replaces numeric spawn_ai_count: each `ai-client = "name", level`
 * line becomes one AiClientEntry. The friendly name is the in-game
 * display_name; level selects `ai-<level>.cfg` (default soft).
 *
 * Created: 2026-11-11
 * Author: Auto
 *
 * Changelog:
 *   2026-11-11  CPL-115: explicit named AI clients with level.
 */

/*
 * AiClientEntry holds one server-spawned AI identity.
 *
 * Parsed from repeated `ai-client` keys. name is required;
 * level defaults to "soft" when the config omits it.
 */
class AiClientEntry {
    String name
    String level

    /*
     * Construct an empty AI client entry.
     *
     * Purpose: give parsers a blank slot before overlay.
     *
     * Parameters: none.
     *
     * Returns: AiClientEntry with empty name and soft level.
     */
    AiClientEntry() {
        name = ""
        level = "soft"
    }

    /*
     * Construct a named entry with an explicit level.
     *
     * Purpose: build entries from parse or defaults without a
     * separate setter pass.
     *
     * Parameters:
     *   displayName — in-game friendly name (display_name).
     *   difficulty — level token (soft/mid/hard/…); empty → soft.
     *
     * Returns: AiClientEntry with name/level filled.
     */
    AiClientEntry(String displayName, String difficulty) {
        name = displayName
        level = difficulty
        if (level.trim().length < 1) {
            level = "soft"
        }
    }
}
