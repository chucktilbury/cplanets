/*
 * src/ai/exploreState.cw — what this AI client knows (menu source).
 *
 * Live read-only bag for the on-demand status console. Scoped to
 * client knowledge: dial/config, last decoded GET snapshot (same
 * visibility as a human client), last policy decision, lag, and
 * recent verbosity/errors. Never invents server-only authority.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI explore state for status menu.
 */

include "../client/stateView.cw"
include "config.cw"
include "policyShape.cw"
include "reaction.cw"
include "verboseLog.cw"
include "view.cw"

/*
 * AiExploreState holds the AI's last known client-side facts.
 *
 * AiClient updates this on dial / handshake / GET / PUT. The
 * status menu and formatters read it without mutating game state.
 */
class AiExploreState {
    AiConfig config
    AiView view
    ClientStateView snapshot
    bool hasSnapshot
    AiPolicyShape lastPolicy
    bool hasPolicy
    String lastPolicyVia
    ReactionLag lag
    AiVerboseLog verbose
    bool dialOk
    bool handshakeOk
    bool connectedHint
    bool decisionPaused
    int64 cyclesDone
    int64 lastCycleIndex
    String lastCycleAction
    String lastError
    int64 lastPullTick

    /*
     * Construct an empty explore bag around config + logger/lag.
     *
     * Purpose: AiClient owns one instance for the menu gate.
     *
     * Parameters:
     *   cfg — clamped AI config (dial / seat / axes).
     *   liveLag — ReactionLag shared with the decision loop.
     *   liveVerbose — AiVerboseLog for recent decision lines.
     *
     * Returns: AiExploreState with empty snapshot and no errors.
     */
    AiExploreState(
        AiConfig cfg,
        ReactionLag liveLag,
        AiVerboseLog liveVerbose) {
        config = cfg
        view = AiView(cfg.playerId)
        snapshot = ClientStateView(cfg.playerId)
        hasSnapshot = false
        lastPolicy = AiPolicyShape()
        hasPolicy = false
        lastPolicyVia = ""
        lag = liveLag
        verbose = liveVerbose
        dialOk = false
        handshakeOk = false
        connectedHint = false
        decisionPaused = false
        cyclesDone = 0
        lastCycleIndex = -1
        lastCycleAction = ""
        lastError = ""
        lastPullTick = -1
    }

    /*
     * Record dial outcome.
     *
     * Purpose: connection section of the status menu.
     *
     * Parameters:
     *   ok — true when TCP connect succeeded.
     *
     * Returns: nothing.
     */
    void noteDial(bool ok) {
        dialOk = ok
        connectedHint = ok
        if (not ok) {
            lastError = "dial_failed"
        }
    }

    /*
     * Record handshake outcome.
     *
     * Purpose: seat presence line for the menu.
     *
     * Parameters:
     *   ok — true when handshake got a non-empty response.
     *
     * Returns: nothing.
     */
    void noteHandshake(bool ok) {
        handshakeOk = ok
        if (not ok) {
            lastError = "handshake_failed"
        }
    }

    /*
     * Store a decoded GET /state snapshot and mirror AiView.
     *
     * Purpose: planets/fleets/designs explore uses the same
     * visibility flags a human client would see.
     *
     * Parameters:
     *   decoded — ClientStateView from PublishDecode.
     *   pullTick — response tick (may match decoded.tick).
     *
     * Returns: nothing.
     */
    void noteSnapshot(ClientStateView decoded, int64 pullTick) {
        snapshot = decoded
        hasSnapshot = true
        lastPullTick = pullTick
        view.playerId = config.playerId
        view.publishedTick = pullTick
        if (pullTick < 0) {
            view.publishedTick = decoded.tick
        }
        view.wealth = fp64(decoded.wealthMilli) / 1000.0
        view.resources = fp64(decoded.resourcesMilli) / 1000.0
        view.knownCompetitorCount = decoded.knownCompetitors.length
        if (decoded.policy.roleName.length > 0) {
            view.currentRole = decoded.policy.roleName
        }
        if (pullTick < 0) {
            lastError = "pull_state_failed"
        } else {
            if (lastError.equals("pull_state_failed")) {
                lastError = ""
            }
        }
    }

    /*
     * Record a generated / PUT policy shape.
     *
     * Purpose: decisions browse without scraping stdout.
     *
     * Parameters:
     *   shape — last brain output.
     *   via — channel tag ("put" / "once" / "local" / "skip").
     *
     * Returns: nothing.
     */
    void notePolicy(AiPolicyShape shape, String via) {
        lastPolicy = shape
        hasPolicy = true
        lastPolicyVia = via
    }

    /*
     * Record one serve-loop cycle outcome.
     *
     * Purpose: cycle trail for the decisions menu section.
     *
     * Parameters:
     *   cycleIndex — zero-based attempt index.
     *   action — "put", "skip", or "fail".
     *
     * Returns: nothing.
     */
    void noteCycle(int64 cycleIndex, String action) {
        lastCycleIndex = cycleIndex
        lastCycleAction = action
        cyclesDone = cycleIndex + 1
        if (action.equals("fail")) {
            lastError = format("cycle_{}_fail", cycleIndex)
        }
    }

    /*
     * Record a free-form last error token.
     *
     * Purpose: transport / reject failures surface in the menu.
     *
     * Parameters:
     *   text — short error token (may be empty to clear).
     *
     * Returns: nothing.
     */
    void noteError(String text) {
        lastError = text
    }
}
