/*
 * src/ai/verboseLog.cw — headless AI client verbosity logger.
 *
 * Scale is 0–10 (clamped). Out-of-range values clamp, they are not
 * rejected. Provisional category thresholds (may firm up later):
 *   0     errors only (optional lines silent)
 *   1–2   reserved
 *   3+    useful AI decisions (seat / handshake, policy shape,
 *         cycle put|skip|fail)
 *   4–9   reserved (finer decision detail)
 *   10    full decision dumps / statistics (gate only; no spam yet)
 * Emits to stdout; also keeps a short in-memory line list for
 * unit asserts. Mirrors ServerVerboseLog shape without combat.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial AiVerboseLog (seat / policy / cycle).
 *   2026-11-07  Remap to 0–10 scale; clamp; provisional thresholds.
 *   2026-11-09  logOrder / logBuild for explore and yard verbs.
 *   2026-11-10  logFleet / logAssign for CPL-101 create+assign.
 */

include "policyShape.cw"

/*
 * AiVerboseLog formats operator-facing stdout lines for the AI.
 *
 * level is copied from AiConfig.verbosity (CLI may overlay).
 * lines stores recent emits for tests without scraping pipes.
 * Threshold fields document the provisional ladder for growth.
 */
class AiVerboseLog {
    int64 level
    list lines
    int64 maxLines
    bool echo
    # Provisional thresholds on the 0–10 scale (not permanent law).
    int64 levelMin
    int64 levelMax
    int64 decisionsAt
    int64 fullAt

    /*
     * Construct a quiet logger with an empty capture buffer.
     *
     * Purpose: AiClient / AiMain can own one instance and setLevel
     * after config / CLI resolve. echo defaults true (stdout);
     * unit programs may clear it and assert the capture list only.
     *
     * Parameters: none.
     *
     * Returns: AiVerboseLog at level 0.
     */
    AiVerboseLog() {
        level = 0
        lines = []
        maxLines = 64
        echo = true
        levelMin = 0
        levelMax = 10
        decisionsAt = 3
        fullAt = 10
    }

    /*
     * Clamp a raw verbosity into the legal 0–10 band.
     *
     * Purpose: shared guard for setLevel, AiConfig, and CLI. Out
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
     * Purpose: apply AI config key and optional CLI --verbosity.
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
     * True when useful AI decisions should be logged.
     *
     * Purpose: gate seat / policy / cycle emits without scattering
     * level compares at call sites. Provisional: decisionsAt (3).
     *
     * Parameters: none.
     *
     * Returns: true when level >= decisionsAt.
     */
    bool decisionsEnabled() {
        return(level >= decisionsAt)
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
     * Clear the capture list (tests).
     *
     * Purpose: reset between asserts without changing level/echo.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void clearLines() {
        lines = []
    }

    /*
     * True when the capture list contains a substring.
     *
     * Purpose: unit asserts without exact full-line equality.
     *
     * Parameters:
     *   needle — substring to search for in any captured line.
     *
     * Returns: true when any line contains needle.
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

    /*
     * Log seat / handshake outcome.
     *
     * Purpose: decisionsAt+ visibility into which playerId dialed
     * and whether presence keep-alive succeeded.
     *
     * Parameters:
     *   playerId — AI seat id.
     *   ok — true when handshake got a non-empty response.
     *
     * Returns: nothing.
     */
    void logSeat(int64 playerId, bool ok) {
        if (not decisionsEnabled()) {
            return()
        }
        String status = "ok"
        if (not ok) {
            status = "fail"
        }
        emit(format(
            "verbosity: seat player={} handshake={}\n",
            playerId,
            status))
    }

    /*
     * Log a generated policy about to be PUT (or printed locally).
     *
     * Purpose: decisionsAt+ decision trail — role and axis percents
     * plus whether surprise fired. Matches the useful fields from
     * server settings lines without duplicating combat detail.
     *
     * Parameters:
     *   playerId — AI seat id.
     *   shape — policy just produced by AiBrain.
     *   via — short channel tag ("put" / "once" / "local").
     *
     * Returns: nothing.
     */
    void logPolicy(int64 playerId, AiPolicyShape shape, String via) {
        if (not decisionsEnabled()) {
            return()
        }
        int64 surprise = 0
        if (shape.surpriseApplied) {
            surprise = 1
        }
        emit(format(
            "verbosity: policy player={} via={} role={} expansion={} escort={} agreement={} tech={} surprise={}\n",
            playerId,
            via,
            shape.roleName,
            shape.expansionPct,
            shape.escortPct,
            shape.agreementS,
            shape.techBiasPct,
            surprise))
    }

    /*
     * Log one serve-loop cycle action.
     *
     * Purpose: decisionsAt+ trail of put / skip / fail per attempt
     * without dumping full state. action is a short token.
     *
     * Parameters:
     *   cycle — zero-based attempt index.
     *   tick — published tick used for lag gating.
     *   playerId — AI seat id.
     *   action — "put", "skip", or "fail".
     *
     * Returns: nothing.
     */
    void logCycle(
        int64 cycleIndex,
        int64 tick,
        int64 playerId,
        String action) {
        if (not decisionsEnabled()) {
            return()
        }
        emit(format(
            "verbosity: cycle index={} tick={} player={} action={}\n",
            cycleIndex,
            tick,
            playerId,
            action))
    }

    /*
     * Log a PUT /order explore / take attempt.
     *
     * Purpose: decisionsAt+ trail when the AI dispatches a fleet
     * (Section C — policy blobs alone never move ships).
     *
     * Parameters:
     *   playerId — AI seat id.
     *   fleetId — sitting fleet ordered.
     *   order — order string (explore / take / …).
     *   destPlanetId — destination rock.
     *   hulls — peel count (0 = whole stack).
     *   ok — true when the server accepted the order.
     *
     * Returns: nothing.
     */
    void logOrder(
        int64 playerId,
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls,
        bool ok) {
        if (not decisionsEnabled()) {
            return()
        }
        String status = "ok"
        if (not ok) {
            status = "fail"
        }
        emit(format(
            "verbosity: order player={} fleet={} order={} dest={} hulls={} status={}\n",
            playerId,
            fleetId,
            order,
            destPlanetId,
            hulls,
            status))
    }

    /*
     * Log a PUT /build yard attempt.
     *
     * Purpose: decisionsAt+ trail when the AI queues a hull to
     * recreate fleets after the starter stack is locked in flight.
     *
     * Parameters:
     *   playerId — AI seat id.
     *   planetId — yard planet.
     *   designId — ready design id.
     *   ok — true when the server queued the build.
     *
     * Returns: nothing.
     */
    void logBuild(
        int64 playerId,
        int64 planetId,
        int64 designId,
        bool ok) {
        if (not decisionsEnabled()) {
            return()
        }
        String status = "ok"
        if (not ok) {
            status = "fail"
        }
        emit(format(
            "verbosity: build player={} planet={} design={} status={}\n",
            playerId,
            planetId,
            designId,
            status))
    }

    /*
     * Log a PUT /fleet create attempt.
     *
     * Purpose: decisionsAt+ trail when the AI creates a named empty
     * fleet to receive unassigned stock (CPL-101).
     *
     * Parameters:
     *   playerId — AI seat id.
     *   planetId — park planet.
     *   fleetName — unique per-seat label.
     *   ok — true when the server created the fleet.
     *
     * Returns: nothing.
     */
    void logFleet(
        int64 playerId,
        int64 planetId,
        String fleetName,
        bool ok) {
        if (not decisionsEnabled()) {
            return()
        }
        String status = "ok"
        if (not ok) {
            status = "fail"
        }
        emit(format(
            "verbosity: fleet player={} planet={} name={} status={}\n",
            playerId,
            planetId,
            fleetName,
            status))
    }

    /*
     * Log a PUT /assign attempt.
     *
     * Purpose: decisionsAt+ trail when the AI moves stock into a
     * named fleet before dispatch (CPL-101).
     *
     * Parameters:
     *   playerId — AI seat id.
     *   fleetId — sitting fleet filled.
     *   typeName — design name assigned.
     *   qty — hulls moved.
     *   ok — true when the server accepted assign.
     *
     * Returns: nothing.
     */
    void logAssign(
        int64 playerId,
        int64 fleetId,
        String typeName,
        int64 qty,
        bool ok) {
        if (not decisionsEnabled()) {
            return()
        }
        String status = "ok"
        if (not ok) {
            status = "fail"
        }
        emit(format(
            "verbosity: assign player={} fleet={} type={} qty={} status={}\n",
            playerId,
            fleetId,
            typeName,
            qty,
            status))
    }
}
