/*
 * tests/unit/unit_aiExploreStop.cw — AI serve-loop stop reasons.
 *
 * Pins elimination / game-ended helpers on AiExploreState so
 * continuous --serve-loop (cycles 0) exits for the right cause
 * without treating pre-home zero ownership as elimination.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial explore stop-reason unit program.
 */

include "ai/config.cw"
include "ai/exploreState.cw"
include "ai/reaction.cw"
include "ai/verboseLog.cw"
include "client/planetRow.cw"
include "client/stateView.cw"

start {
    bool ok = true

    AiConfig cfg = AiConfig()
    cfg.playerId = 1
    cfg.clampAll()
    ReactionLag lag = ReactionLag()
    AiVerboseLog verbose = AiVerboseLog()
    verbose.echo = false
    AiExploreState state = AiExploreState(cfg, lag, verbose)

    # No snapshot yet → still live.
    if (state.serveStopReason().length != 0) {
        ok = false
    }
    if (state.seatEliminated() or state.gameEnded()) {
        ok = false
    }

    # Empty snapshot (pre-home): zero owned planets, not eliminated.
    ClientStateView empty = ClientStateView(1)
    empty.tick = 0
    empty.ended = false
    state.noteSnapshot(empty, 0)
    if (state.everOwnedPlanet) {
        ok = false
    }
    if (state.seatEliminated()) {
        ok = false
    }
    if (state.serveStopReason().length != 0) {
        ok = false
    }

    # Grant a home yard → everOwnedPlanet latches.
    ClientStateView home = ClientStateView(1)
    home.tick = 1
    home.ended = false
    PlanetRow yard = PlanetRow()
    yard.id = 3
    yard.visible = true
    yard.shipyard = true
    yard.ownerId = 1
    home.planets.append(yard)
    state.noteSnapshot(home, 1)
    if (not state.everOwnedPlanet) {
        ok = false
    }
    if (home.ownedPlanetCount() != 1) {
        ok = false
    }
    if (state.serveStopReason().length != 0) {
        ok = false
    }

    # Lose all planets → eliminated.
    ClientStateView gone = ClientStateView(1)
    gone.tick = 2
    gone.ended = false
    state.noteSnapshot(gone, 2)
    if (not state.seatEliminated()) {
        ok = false
    }
    if (not state.serveStopReason().equals("eliminated")) {
        ok = false
    }

    # Fresh explore: game ended without local elimination flag.
    AiExploreState endedState = AiExploreState(cfg, lag, verbose)
    ClientStateView over = ClientStateView(1)
    over.tick = 9
    over.ended = true
    over.winnerId = 0
    endedState.noteSnapshot(over, 9)
    if (not endedState.gameEnded()) {
        ok = false
    }
    if (not endedState.serveStopReason().equals("game_ended")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
