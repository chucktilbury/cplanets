/*
 * src/ai/verboseLog.cw — headless AI client verbosity logger.
 *
 * Levels (operators): 0 quiet (default), 1+ useful AI decisions
 * (seat / handshake, policy PUT shape, cycle put|skip|fail).
 * Emits to stdout; also keeps a short in-memory line list for
 * unit asserts. Mirrors ServerVerboseLog shape without combat.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial AiVerboseLog (seat / policy / cycle).
 */

include "policyShape.cw"

/*
 * AiVerboseLog formats operator-facing stdout lines for the AI.
 *
 * level is copied from AiConfig.verbosity (CLI may overlay).
 * lines stores recent emits for tests without scraping pipes.
 */
class AiVerboseLog {
    int64 level
    list lines
    int64 maxLines
    bool echo

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
    }

    /*
     * Set the active verbosity level.
     *
     * Purpose: apply AI config key and optional CLI --verbosity.
     * Negative values clamp to 0.
     *
     * Parameters:
     *   value — 0 quiet, 1+ seat / policy / cycle decisions.
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
     * True when useful AI decisions should be logged.
     *
     * Purpose: gate seat / policy / cycle emits without scattering
     * level compares at call sites.
     *
     * Parameters: none.
     *
     * Returns: true when level >= 1.
     */
    bool decisionsEnabled() {
        return(level >= 1)
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
     * Purpose: level >= 1 visibility into which playerId dialed and
     * whether presence keep-alive succeeded.
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
     * Purpose: level >= 1 decision trail — role and axis percents
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
     * Purpose: level >= 1 trail of put / skip / fail per attempt
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
}
