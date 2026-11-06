/*
 * src/client/appCore.cw — headless human client coordinator (G).
 *
 * Refresh / apply without GTK so unit/fn and --pull work without
 * a display. GUI wraps this core (PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AppCore.
 *   2026-11-06  TUNING B: pause / order / recall remote helpers.
 */

include "config.cw"
include "policyShape.cw"
include "publishDecode.cw"
include "session.cw"
include "stateView.cw"
include "../server/policyTable.cw"
include "../server/publish.cw"
include "../lib/state.cw"

/*
 * AppCore owns the working ClientStateView and policy editor.
 *
 * fillFromGame builds a seat view in-process (tests). pullFrom
 * uses TCP. Never ticks; never opens the universe DB.
 */
class AppCore {
    HumanConfig config
    ClientStateView view
    HumanPolicyShape draft
    PublishDecode decoder

    /*
     * Construct a core around a config.
     *
     * Purpose: shared state for headless and GTK paths.
     *
     * Parameters:
     *   cfg — clamped human config.
     *
     * Returns: AppCore with empty view and default draft.
     */
    AppCore(HumanConfig cfg) {
        config = cfg
        view = ClientStateView(cfg.playerId)
        draft = HumanPolicyShape()
        decoder = PublishDecode()
    }

    /*
     * Fill the view from an in-process State (no TCP).
     *
     * Purpose: unit/fn tests without a listen socket. Uses the
     * same PublishCodec the server uses so decode matches wire.
     *
     * Parameters:
     *   game — current State.
     *   policies — last-policy table (may be empty).
     *
     * Returns: true when encode/decode produced a view.
     */
    bool fillFromGame(State game, PolicyTable policies) {
        PublishCodec codec = PublishCodec()
        buffer blob = codec.encodeStateView(
            game, policies, config.playerId, false)
        if (blob.length < 1) {
            return(false)
        }
        view = decoder.decodeState(blob, config.playerId)
        view.tick = game.tickCount
        draft = view.policy
        buffer digest = codec.encodeDigest(
            game.tickCount, [])
        decoder.decodeDigest(digest, view)
        return(true)
    }

    /*
     * Dial, handshake, GET state + digest over TCP.
     *
     * Purpose: --pull and GUI refresh.
     *
     * Parameters: none (uses config).
     *
     * Returns: true when state pull succeeded.
     */
    bool pullRemote() {
        HumanSession session = HumanSession(config)
        if (not session.dial()) {
            return(false)
        }
        session.handshake()
        ClientStateView next = session.pullState()
        session.pullDigest(next)
        session.close()
        view = next
        draft = view.policy
        return(true)
    }

    /*
     * PUT the draft policy over TCP.
     *
     * Purpose: policy editor Apply — no dumb-order warnings.
     *
     * Parameters: none (uses draft + config).
     *
     * Returns: true when accepted.
     */
    bool applyDraftRemote() {
        HumanSession session = HumanSession(config)
        if (not session.dial()) {
            return(false)
        }
        session.handshake()
        bool ok = session.putPolicy(draft)
        session.close()
        return(ok)
    }

    /*
     * PUT pause over TCP when port is set.
     *
     * Purpose: GuiMain Pause CheckButton.
     *
     * Parameters:
     *   wantPaused — desired pause flag.
     *
     * Returns: true when accepted.
     */
    bool putPauseRemote(bool wantPaused) {
        HumanSession session = HumanSession(config)
        if (not session.dial()) {
            return(false)
        }
        session.handshake()
        bool ok = session.putPause(wantPaused)
        session.close()
        return(ok)
    }

    /*
     * PUT a fleet order over TCP.
     *
     * Purpose: Fleets tab Dispatch button.
     *
     * Parameters:
     *   fleetId — owned fleet.
     *   order — explore / take / trade / move / ambush.
     *   destPlanetId — destination.
     *
     * Returns: true when queued.
     */
    bool putOrderRemote(
        int64 fleetId, String order, int64 destPlanetId) {
        HumanSession session = HumanSession(config)
        if (not session.dial()) {
            return(false)
        }
        session.handshake()
        bool ok = session.putOrder(fleetId, order, destPlanetId)
        session.close()
        return(ok)
    }

    /*
     * PUT recall over TCP.
     *
     * Purpose: Fleets tab Recall button.
     *
     * Parameters:
     *   fleetId — owned fleet.
     *
     * Returns: true when recorded.
     */
    bool putRecallRemote(int64 fleetId) {
        HumanSession session = HumanSession(config)
        if (not session.dial()) {
            return(false)
        }
        session.handshake()
        bool ok = session.putRecall(fleetId)
        session.close()
        return(ok)
    }

    /*
     * Print a headless summary of the current view.
     *
     * Purpose: --once / --pull text output without GTK.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSummary() {
        print("cplanets\n")
        print(format("tick={}\n", view.tick))
        print(format(
            "planets_visible={}\n", view.visiblePlanetCount()))
        print(format(
            "fleets_visible={}\n", view.visibleFleetCount()))
        int64 index = 0
        while (index < view.planets.length) {
            PlanetRow row = view.planets[index]
            if (row.visible) {
                print(row.listLabel())
                print("\n")
            }
            index = index + 1
        }
        index = 0
        while (index < view.fleets.length) {
            FleetRow row = view.fleets[index]
            if (row.visible) {
                print(row.listLabel())
                print("\n")
            }
            index = index + 1
        }
        print("digest:\n")
        print(view.digestText())
        print(format(
            "policy role={} expansion={}\n",
            draft.roleName, draft.expansionPct))
    }
}
