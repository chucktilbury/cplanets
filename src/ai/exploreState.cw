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
 *   2026-11-08  Track suspended (PUT /suspended) for menu hold.
 *   2026-11-08  Elimination / game-end stop helpers for serve-loop.
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
    bool suspended
    int64 cyclesDone
    int64 lastCycleIndex
    String lastCycleAction
    String lastError
    int64 lastPullTick
    # True after any snapshot showed at least one owned planet.
    # Used so pre-home zero ownership does not look like elimination.
    bool everOwnedPlanet

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
        suspended = false
        cyclesDone = 0
        lastCycleIndex = -1
        lastCycleAction = ""
        lastError = ""
        lastPullTick = -1
        everOwnedPlanet = false
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
     * Record intentional suspended / AFK flag outcome.
     *
     * Purpose: menu-open hold so handshake_miss does not drop the
     * seat; explore summary shows whether the flag is live.
     *
     * Parameters:
     *   want — requested suspended state.
     *   ok — true when PUT /suspended got a non-empty response.
     *
     * Returns: nothing.
     */
    void noteSuspended(bool want, bool ok) {
        if (ok) {
            suspended = want
            if (lastError.equals("suspended_failed")) {
                lastError = ""
            }
        } else {
            lastError = "suspended_failed"
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
        if (decoded.ownedPlanetCount() > 0) {
            everOwnedPlanet = true
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
     * True when the published game has ended.
     *
     * Purpose: serve-loop stop when closed eliminate-all (or
     * humans-quit) sets State.ended on the wire.
     *
     * Parameters: none.
     *
     * Returns: true when a snapshot reports ended.
     */
    bool gameEnded() {
        if (not hasSnapshot) {
            return(false)
        }
        return(snapshot.ended)
    }

    /*
     * True when this seat lost all planets after having owned some.
     *
     * Purpose: serve-loop stop for mid-game elimination before the
     * whole match ends (multi-seat closed games). Pre-home zero
     * ownership does not count (everOwnedPlanet stays false until
     * handshake grants a yard).
     *
     * Parameters: none.
     *
     * Returns: true when ever owned and current owned count is 0.
     */
    bool seatEliminated() {
        if (not hasSnapshot) {
            return(false)
        }
        if (not everOwnedPlanet) {
            return(false)
        }
        return(snapshot.ownedPlanetCount() < 1)
    }

    /*
     * Short token for why the continuous serve-loop should stop.
     *
     * Purpose: banner line after runLoop exits on end conditions.
     * Finite --cycles N paths do not use this (they print ok).
     *
     * Parameters: none.
     *
     * Returns: "eliminated", "game_ended", or empty when still live.
     */
    String serveStopReason() {
        if (seatEliminated()) {
            return("eliminated")
        }
        if (gameEnded()) {
            return("game_ended")
        }
        return("")
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
