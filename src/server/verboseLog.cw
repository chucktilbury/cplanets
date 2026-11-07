/*
 * src/server/verboseLog.cw — headless server verbosity logger.
 *
 * Levels (operators): 0 quiet (default), 1 player settings /
 * policy PUT detail, 2+ combat / battle events with fleet
 * strength. Emits to stdout; also keeps a short in-memory line
 * list for unit asserts. Not a GUI.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerVerboseLog (settings + combat).
 */

include "../lib/engagement.cw"
include "../lib/event.cw"
include "../lib/wireBytes.cw"

/*
 * ServerVerboseLog formats operator-facing stdout lines.
 *
 * level is copied from Scenario.verbosity (CLI may overlay).
 * lines stores recent emits for tests without scraping pipes.
 */
class ServerVerboseLog {
    int64 level
    list lines
    int64 maxLines
    bool echo

    /*
     * Construct a quiet logger with an empty capture buffer.
     *
     * Purpose: GameDriver can own one instance and setLevel after
     * setup / CLI resolve. echo defaults true (stdout); unit
     * programs may clear it and assert the capture list only.
     *
     * Parameters: none.
     *
     * Returns: ServerVerboseLog at level 0.
     */
    ServerVerboseLog() {
        level = 0
        lines = []
        maxLines = 64
        echo = true
    }

    /*
     * Set the active verbosity level.
     *
     * Purpose: apply setup key and optional CLI --verbosity.
     * Negative values clamp to 0.
     *
     * Parameters:
     *   value — 0 quiet, 1 settings, 2+ combat detail.
     *
     * Returns: nothing.
     */
    void setLevel(int64 value) {
        if (value < 0) {
            value = 0
        }
        level = value
    }

    /*
     * True when policy / settings PUTs should be logged.
     *
     * Purpose: gate putPolicy logging without scattering level
     * compares at call sites.
     *
     * Parameters: none.
     *
     * Returns: true when level >= 1.
     */
    bool settingsEnabled() {
        return(level >= 1)
    }

    /*
     * True when combat / battle tick detail should be logged.
     *
     * Purpose: gate fireOne combat logging.
     *
     * Parameters: none.
     *
     * Returns: true when level >= 2.
     */
    bool combatEnabled() {
        return(level >= 2)
    }

    /*
     * Emit one line to stdout and the capture list.
     *
     * Purpose: single sink so tests and operators see the same
     * text. Caps capture length to avoid unbounded growth.
     *
     * Parameters:
     *   line — full line including trailing newline when desired.
     *
     * Returns: nothing.
     */
    void emit(String line) {
        if (echo) {
            print(line)
        }
        if (lines.length >= maxLines) {
            lines = []
        }
        lines.append(line)
    }

    /*
     * Map a v1 policy role code to a short name.
     *
     * Purpose: readable settings logs without importing client /
     * AI policyShape modules into the server tree.
     *
     * Parameters:
     *   code — wire role u8.
     *
     * Returns: role name string.
     */
    String roleName(int64 code) {
        if (code == 1) {
            return("conqueror")
        }
        if (code == 2) {
            return("pirate")
        }
        if (code == 3) {
            return("trader")
        }
        if (code == 4) {
            return("hermit")
        }
        return("neutral")
    }

    /*
     * Log a player settings / policy PUT at level >= 1.
     *
     * Purpose: operators see who changed standing policy and the
     * decoded v1 fields when the blob matches the shared layout.
     * Opaque / short blobs still log seat + byte length.
     *
     * Parameters:
     *   playerId — seat that wrote the policy.
     *   blob — opaque PUT /policy body.
     *
     * Returns: nothing.
     */
    void logPolicyPut(int64 playerId, buffer blob) {
        if (not settingsEnabled()) {
            return()
        }
        if (blob.length >= 8) {
            WireBytes r = WireBytes()
            r.setRead(blob)
            int64 ver = r.readU8()
            int64 role = r.readU8()
            int64 exp = r.readU8()
            int64 esc = r.readU8()
            int64 agree = r.readU8()
            int64 tech = r.readU8()
            if (r.ok() and ver == 1) {
                emit(format(
                    "verbosity: settings player={} role={} expansion={} escort={} agreement={} tech={} bytes={}\n",
                    playerId,
                    roleName(role),
                    exp,
                    esc,
                    agree,
                    tech,
                    blob.length))
                return()
            }
        }
        emit(format(
            "verbosity: settings player={} bytes={}\n",
            playerId,
            blob.length))
    }

    /*
     * True when a tick event kind is combat / battle related.
     *
     * Purpose: avoid dumping every depart/arrive at combat level.
     *
     * Parameters:
     *   kind — TickEvent.kind.
     *
     * Returns: true for combat_*, ambush_*, defend, pirate_war.
     */
    bool isCombatKind(String kind) {
        if (kind.startsWith("combat_")) {
            return(true)
        }
        if (kind.startsWith("ambush")) {
            return(true)
        }
        if (kind.equals("defend")) {
            return(true)
        }
        if (kind.equals("pirate_war")) {
            return(true)
        }
        return(false)
    }

    /*
     * Convert comparative strength to milli-units for logs.
     *
     * Purpose: print strength without relying on fp format; same
     * milli scale publish uses for wealth. Does not invent balance.
     *
     * Parameters:
     *   strength — comparative strength already in the sim.
     *
     * Returns: floor(strength * 1000) as int64.
     */
    int64 strengthMilli(fp64 strength) {
        return(int64(strength * 1000.0))
    }

    /*
     * Log combat tick events and open engagement strengths.
     *
     * Purpose: level >= 2 detail for battles — event kinds plus
     * attacker/defender strength left on still-open fights. Quiet
     * when no combat-shaped events and no open engagements.
     *
     * Parameters:
     *   tick — State.tickCount after the fire.
     *   events — TickEvent list from the just-run tick.
     *   engagements — State engagement list (may include closed).
     *
     * Returns: nothing.
     */
    void logCombatTick(int64 tick, list events, list engagements) {
        if (not combatEnabled()) {
            return()
        }
        int64 index = 0
        while (index < events.length) {
            TickEvent ev = events[index]
            if (isCombatKind(ev.kind)) {
                emit(format(
                    "verbosity: combat tick={} kind={} fleet={} planet={} player={} value={}\n",
                    tick,
                    ev.kind,
                    ev.fleetId,
                    ev.planetId,
                    ev.playerId,
                    ev.value))
            }
            index = index + 1
        }
        index = 0
        while (index < engagements.length) {
            Engagement fight = engagements[index]
            if (fight.open) {
                emit(format(
                    "verbosity: combat tick={} engagement={} planet={} atk_milli={} def_milli={} ticks_open={}\n",
                    tick,
                    fight.id,
                    fight.planetId,
                    strengthMilli(fight.attackerStrengthLeft),
                    strengthMilli(fight.defenderStrengthLeft),
                    fight.ticksOpen))
            }
            index = index + 1
        }
    }

    /*
     * Clear the captured line list (tests).
     *
     * Purpose: isolate asserts between putPolicy / tick steps.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void clearLines() {
        lines = []
    }

    /*
     * True when any captured line contains the needle.
     *
     * Purpose: unit/fn asserts without regex.
     *
     * Parameters:
     *   needle — substring to find.
     *
     * Returns: true when found in any captured line.
     */
    bool linesContain(String needle) {
        int64 index = 0
        while (index < lines.length) {
            String line = lines[index]
            if (line.find(needle) >= 0) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }
}
