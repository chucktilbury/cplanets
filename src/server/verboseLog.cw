/*
 * src/server/verboseLog.cw — headless server verbosity logger.
 *
 * Scale is 0–10 (clamped). Out-of-range values clamp, they are not
 * rejected. Provisional category thresholds (may firm up later):
 *   0     errors only (optional lines silent)
 *   1–2   reserved
 *   3+    settings / policy PUT detail; ship-create verbs
 *   6+    combat / battle events + engagement strengths
 *   10    full dumps / statistics (gate only; no spam yet)
 * Emits to stdout; also keeps a short in-memory line list for
 * unit asserts. Not a GUI.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerVerboseLog (settings + combat).
 *   2026-11-07  Remap to 0–10 scale; clamp; provisional thresholds.
 *   2026-11-07  Ship-create PUT /design /build /reclaim-hulls lines.
 *   2026-11-07  PUT /order accept/reject reason lines.
 */

include "../lib/engagement.cw"
include "../lib/event.cw"
include "../lib/wireBytes.cw"

/*
 * ServerVerboseLog formats operator-facing stdout lines.
 *
 * level is copied from Scenario.verbosity (CLI may overlay).
 * lines stores recent emits for tests without scraping pipes.
 * Threshold fields document the provisional ladder for growth.
 */
class ServerVerboseLog {
    int64 level
    list lines
    int64 maxLines
    bool echo
    # Provisional thresholds on the 0–10 scale (not permanent law).
    int64 levelMin
    int64 levelMax
    int64 settingsAt
    int64 combatAt
    int64 fullAt

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
        levelMin = 0
        levelMax = 10
        settingsAt = 3
        combatAt = 6
        fullAt = 10
    }

    /*
     * Clamp a raw verbosity into the legal 0–10 band.
     *
     * Purpose: shared guard for setLevel, Scenario, and CLI. Out
     * of range values clamp (not reject) so operators and configs
     * stay usable while the ladder is provisional.
     *
     * Parameters:
     *   value — raw requested level.
     *
     * Returns: value forced into [levelMin, levelMax].
     */
    int64 clampLevel(int64 value) {
        if (value < levelMin) {
            return(levelMin)
        }
        if (value > levelMax) {
            return(levelMax)
        }
        return(value)
    }

    /*
     * Set the active verbosity level.
     *
     * Purpose: apply setup key and optional CLI --verbosity.
     * Values outside 0–10 clamp into range.
     *
     * Parameters:
     *   value — 0–10 on the provisional ladder.
     *
     * Returns: nothing.
     */
    void setLevel(int64 value) {
        level = clampLevel(value)
    }

    /*
     * True when policy / settings PUTs should be logged.
     *
     * Purpose: gate putPolicy logging without scattering level
     * compares at call sites. Provisional: settingsAt (3).
     *
     * Parameters: none.
     *
     * Returns: true when level >= settingsAt.
     */
    bool settingsEnabled() {
        return(level >= settingsAt)
    }

    /*
     * True when combat / battle tick detail should be logged.
     *
     * Purpose: gate fireOne combat logging. Provisional: combatAt
     * (6).
     *
     * Parameters: none.
     *
     * Returns: true when level >= combatAt.
     */
    bool combatEnabled() {
        return(level >= combatAt)
    }

    /*
     * True when full dumps / statistics should be logged.
     *
     * Purpose: reserve the top of the ladder for future decision
     * dumps and statistics without inventing spam yet. No call
     * sites emit under this gate today.
     *
     * Parameters: none.
     *
     * Returns: true when level >= fullAt (10).
     */
    bool fullEnabled() {
        return(level >= fullAt)
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
     * Log a player settings / policy PUT at settingsAt+.
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
     * Log a PUT /design develop result.
     *
     * Purpose: visible server ack for Ships Start develop (settings
     * band, same as policy PUTs).
     *
     * Parameters:
     *   playerId — seat that paid wealth.
     *   designId — new design id, or −1 when rejected.
     *   name — draft name from the wire.
     *
     * Returns: nothing.
     */
    void logDesignDevelop(
        int64 playerId, int64 designId, String name) {
        if (not settingsEnabled()) {
            return()
        }
        if (designId < 0) {
            emit(format(
                "verbosity: design player={} rejected name={}\n",
                playerId, name))
            return()
        }
        emit(format(
            "verbosity: design player={} id={} name={} queued\n",
            playerId, designId, name))
    }

    /*
     * Log a PUT /order dispatch result.
     *
     * Purpose: operator-visible accept/reject with the same reason
     * string the client surfaces (missing fleet, lock, peel, …).
     *
     * Parameters:
     *   playerId — requesting seat.
     *   fleetId — fleet Entry id.
     *   order — order string.
     *   destPlanetId — destination rock.
     *   hulls — peel count (0 = whole stack).
     *   accepted — true when the order was queued.
     *   reason — reject detail when accepted is false.
     *
     * Returns: nothing.
     */
    void logOrder(
        int64 playerId,
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls,
        bool accepted,
        String reason) {
        if (not settingsEnabled()) {
            return()
        }
        if (accepted) {
            emit(format(
                "verbosity: order player={} fleet={} {} dest={} hulls={} queued\n",
                playerId, fleetId, order, destPlanetId, hulls))
            return()
        }
        emit(format(
            "verbosity: order player={} fleet={} {} dest={} hulls={} rejected ({})\n",
            playerId, fleetId, order, destPlanetId, hulls, reason))
    }

    /*
     * Log a PUT /build yard result.
     *
     * Purpose: visible server ack for Ships Queue build.
     *
     * Parameters:
     *   playerId — seat paying resources.
     *   planetId — yard planet.
     *   designId — ready design.
     *   accepted — true when a BuildJob was queued.
     *
     * Returns: nothing.
     */
    void logYardBuild(
        int64 playerId,
        int64 planetId,
        int64 designId,
        bool accepted) {
        if (not settingsEnabled()) {
            return()
        }
        String bit = "rejected"
        if (accepted) {
            bit = "queued"
        }
        emit(format(
            "verbosity: build player={} planet={} design={} {}\n",
            playerId, planetId, designId, bit))
    }

    /*
     * Log a PUT /reclaim-hulls result.
     *
     * Purpose: visible server ack for Ships Reclaim hulls.
     *
     * Parameters:
     *   playerId — seat reclaiming.
     *   fleetId — sitting fleet at a yard.
     *   hulls — requested hull count.
     *   accepted — true when a ReclaimJob was queued.
     *
     * Returns: nothing.
     */
    void logReclaimHulls(
        int64 playerId,
        int64 fleetId,
        int64 hulls,
        bool accepted) {
        if (not settingsEnabled()) {
            return()
        }
        String bit = "rejected"
        if (accepted) {
            bit = "queued"
        }
        emit(format(
            "verbosity: reclaim player={} fleet={} hulls={} {}\n",
            playerId, fleetId, hulls, bit))
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
     * Purpose: combatAt+ detail for battles — event kinds plus
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
