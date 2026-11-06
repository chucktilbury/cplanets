/*
 * src/ai/reaction.cw — AI reaction lag gate (Phase H).
 *
 * Exposes both tick-count and wall-time lag until RULES locks a
 * binding shape (PLAN §4.H / §9). Update when either gate is
 * ready so both knobs stay meaningful.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial ReactionLag either-gate.
 */

include "config.cw"

/*
 * ReactionLag decides when the AI may PUT a new policy.
 *
 * Tracks the last update tick and wall ms. Near-every-tick play
 * uses lagTicks=1 and a small lagSeconds; slower bots raise both.
 */
class ReactionLag {
    int64 lastUpdateTick
    uint64 lastUpdateMs
    bool everUpdated

    /*
     * Construct a lag tracker that has never updated.
     *
     * Purpose: first shouldUpdate returns true so the AI emits an
     * initial policy after connect / start.
     *
     * Parameters: none.
     *
     * Returns: ReactionLag with everUpdated false.
     */
    ReactionLag() {
        lastUpdateTick = 0
        lastUpdateMs = 0u
        everUpdated = false
    }

    /*
     * True when config lag allows a new policy update.
     *
     * Purpose: gate brain.generate against published tick and
     * wall/injectable now. OR of tick and wall readiness.
     *
     * Parameters:
     *   cfg — AI config with reactionLagTicks / Seconds.
     *   publishedTick — current published tick.
     *   nowMs — current wall or injectable milliseconds.
     *
     * Returns: true when never updated, or either lag gate ready.
     */
    bool shouldUpdate(
        AiConfig cfg,
        int64 publishedTick,
        uint64 nowMs) {
        if (not everUpdated) {
            return(true)
        }
        int64 tickDelta = publishedTick - lastUpdateTick
        if (tickDelta < 0) {
            tickDelta = 0
        }
        bool tickReady = tickDelta >= cfg.reactionLagTicks
        uint64 needMs = uint64(
            int64(cfg.reactionLagSeconds * 1000.0 + 0.5))
        bool wallReady = false
        if (nowMs >= lastUpdateMs) {
            wallReady = (nowMs - lastUpdateMs) >= needMs
        } else {
            wallReady = true
        }
        return(tickReady or wallReady)
    }

    /*
     * Record that a policy update just happened.
     *
     * Purpose: reset both lag windows after a PUT.
     *
     * Parameters:
     *   publishedTick — tick at update time.
     *   nowMs — clock at update time.
     *
     * Returns: nothing.
     */
    void markUpdated(int64 publishedTick, uint64 nowMs) {
        lastUpdateTick = publishedTick
        lastUpdateMs = nowMs
        everUpdated = true
    }
}
