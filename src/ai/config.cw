/*
 * src/ai/config.cw — AI client difficulty axes (Phase H).
 *
 * Own config surface, not the human settings file (RULES §2 /
 * PLAN §4.H). Axes are continuous soft→hard knobs; reaction lag
 * exposes both tick and wall shapes until RULES locks one.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AiConfig axes + clamp helpers.
 *   2026-11-07  verbosity (0 quiet / 1+ seat, policy, cycle).
 *   2026-11-07  Verbosity 0–10 scale; clamp in clampAll.
 *   2026-11-07  CLI mirror keys: cycles, once, serve_loop.
 *   2026-11-08  cycles 0 = serve until eliminated/ended/stop.
 */

/*
 * AiConfig holds one stand-alone AI client's knobs.
 *
 * Axes are fp64 in [0.0, 1.0] unless noted. seed pins surprise
 * and role rolls for reproducible fn tests.
 */
class AiConfig {
    fp64 aggression
    fp64 roleStickiness
    fp64 expansion
    fp64 escort
    fp64 agreementAppetite
    fp64 techVsHulls
    int64 reactionLagTicks
    fp64 reactionLagSeconds
    fp64 surpriseRate
    uint64 seed
    int64 playerId
    String host
    int64 port
    # Stdout decision log level. Scale 0–10 (clamped). CLI
    # --verbosity may overlay after load. Provisional: 0 errors
    # only; 3+ seat / policy / cycle; 10 full dumps (AiVerboseLog).
    int64 verbosity
    # CLI mirror defaults (silent argv override after load).
    # cycles: 0 = run until eliminated / game ended / process stop;
    # N > 0 caps serve-loop attempts (smoke / harness).
    int64 cycles
    bool once
    bool serveLoop

    /*
     * Construct mid-band defaults for a seat.
     *
     * Purpose: give loaders and tests a known soft-mid baseline
     * before overlays. Surprise stays rare by default.
     *
     * Parameters: none.
     *
     * Returns: AiConfig with mid axes, lag 1 tick / 2.0s, seed 1.
     */
    AiConfig() {
        aggression = 0.5
        roleStickiness = 0.7
        expansion = 0.5
        escort = 0.5
        agreementAppetite = 0.4
        techVsHulls = 0.5
        reactionLagTicks = 1
        reactionLagSeconds = 2.0
        surpriseRate = 0.05
        seed = 1u
        playerId = 0
        host = "127.0.0.1"
        port = 0
        verbosity = 0
        cycles = 0
        once = false
        serveLoop = false
    }

    /*
     * Clamp every axis into its legal band.
     *
     * Purpose: harden after text load so brain math never sees
     * out-of-range surprise or negative lag.
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void clampAll() {
        aggression = clamp01(aggression)
        roleStickiness = clamp01(roleStickiness)
        expansion = clamp01(expansion)
        escort = clamp01(escort)
        agreementAppetite = clamp01(agreementAppetite)
        techVsHulls = clamp01(techVsHulls)
        surpriseRate = clamp01(surpriseRate)
        if (reactionLagTicks < 1) {
            reactionLagTicks = 1
        }
        if (reactionLagSeconds < 0.0) {
            reactionLagSeconds = 0.0
        }
        if (seed == 0u) {
            seed = 1u
        }
        if (playerId < 0) {
            playerId = 0
        }
        if (port < 0) {
            port = 0
        }
        if (verbosity < 0) {
            verbosity = 0
        } else (verbosity > 10) {
            verbosity = 10
        }
        # 0 = unlimited serve-loop (until eliminated / ended / stop).
        if (cycles < 0) {
            cycles = 0
        }
    }

    /*
     * Clamp a float into [0.0, 1.0].
     *
     * Purpose: shared axis guard for clampAll and parsers.
     *
     * Parameters:
     *   value — raw fp64.
     *
     * Returns: value forced into [0.0, 1.0].
     */
    fp64 clamp01(fp64 value) {
        if (value < 0.0) {
            return(0.0)
        }
        if (value > 1.0) {
            return(1.0)
        }
        return(value)
    }
}
