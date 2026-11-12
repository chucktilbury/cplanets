/*
 * tests/unit/unit_lobbyHumanPause.cw — Pause uncheck leaves lobby.
 *
 * CPL-118: lobby publishes paused; clearing pause via setPaused(false)
 * must call go() so ticks / play verbs unlock. Console go remains a
 * separate path; this unit covers the human Pause start control.
 *
 * Created: 2026-11-12
 * Author: Auto
 *
 * Changelog:
 *   2026-11-12  Initial Pause-uncheck → go regression (CPL-118).
 */

include "lib/state.cw"
include "server/driver.cw"

start {
    bool ok = true

    # Miss window above one tick period so injectable advance after
    # Pause-start does not handshake_miss-drop the sole human.
    State game = State()
    game.startClosed(118u, 0)
    GameDriver driver = GameDriver(game, true, "", false, 60000u)
    driver.softMaxPlayers = 0

    if (not driver.inLobby()) {
        ok = false
    }
    if (ok and driver.handshakeAllocate() != 0) {
        ok = false
    }
    if (ok and not driver.publishPausedFlag()) {
        ok = false
    }
    if (ok and not driver.pauseOffered()) {
        ok = false
    }
    # Play verbs still blocked before start.
    if (ok and driver.issueOwnedOrder(0, 1, "explore", 1, 0)) {
        ok = false
    }

    # Human Pause uncheck → leave lobby (shared go path).
    if (ok and not driver.setPaused(false)) {
        ok = false
    }
    if (ok and driver.inLobby()) {
        ok = false
    }
    if (ok and driver.publishPausedFlag()) {
        ok = false
    }
    if (ok and not driver.running) {
        ok = false
    }

    # Refresh presence so the injectable advance does not age-drop.
    if (ok and driver.handshakeKeepAlive(0) != 0) {
        ok = false
    }

    # Injectable ticks may advance after Pause start.
    if (ok and driver.advanceTicks(1) != 1) {
        ok = false
    }
    if (ok and driver.game.tickCount != 1) {
        ok = false
    }

    # Re-pause still works with one human after running.
    if (ok and not driver.setPaused(true)) {
        ok = false
    }
    if (ok and not driver.paused) {
        ok = false
    }
    if (ok and driver.advanceTicks(1) != 0) {
        ok = false
    }
    if (ok and not driver.setPaused(false)) {
        ok = false
    }
    if (ok and driver.paused) {
        ok = false
    }

    driver.close()

    # setPaused(false) with no seat still leaves lobby (console-like).
    State empty = State()
    empty.startClosed(119u, 0)
    GameDriver emptyDrv = GameDriver(empty, true, "", false, 500u)
    if (ok and not emptyDrv.setPaused(false)) {
        ok = false
    }
    if (ok and emptyDrv.inLobby()) {
        ok = false
    }
    emptyDrv.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
