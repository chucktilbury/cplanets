/*
 * tests/unit/unit_statusMenu.cw — read-only status view walk.
 *
 * Starts a closed galaxy, formats summary / player / planet / fleet /
 * design / config text, and checks key tokens without stdin.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial status menu unit program.
 *   2026-11-08  Drop menu= config dump token.
 *   2026-11-08  Summary uses seated= / softMax= tokens.
 *   2026-11-09  Lobby summary shows paused=true (clock hold).
 */

include "server/config.cw"
include "server/statusViews.cw"

start {
    bool ok = true

    State game = State()
    game.startClosed(7u, 2)
    game.ensureAllSeatHomes()
    GameDriver driver = GameDriver(
        game, true, "", false, 5000u)
    ServerConfig cfg = ServerConfig()
    cfg.players = 2
    cfg.seed = 7
    driver.softMaxPlayers = 2
    StatusViews views = StatusViews(driver, cfg)

    String summary = views.summaryLine()
    if (not summary.startsWith("phase=lobby")) {
        ok = false
    }
    if (not summary.contains("tick=0")) {
        ok = false
    }
    if (not summary.contains("paused=true")) {
        ok = false
    }
    if (not summary.contains("seated=2")) {
        ok = false
    }
    if (not summary.contains("softMax=2")) {
        ok = false
    }
    if (not summary.contains("planets=")) {
        ok = false
    }
    if (not summary.contains("fleets=")) {
        ok = false
    }

    String players = views.playerList()
    if (not players.contains("[1] id=0")) {
        ok = false
    }
    if (not players.contains("[2] id=1")) {
        ok = false
    }

    String seat = views.playerDetail(0)
    if (not seat.contains("Player id=0")) {
        ok = false
    }
    if (not seat.contains("owned planets=")) {
        ok = false
    }

    if (views.countOwnedPlanets(0) < 1) {
        ok = false
    }
    if (views.countOwnedFleets(0) < 1) {
        ok = false
    }
    if (views.countOwnedHulls(0) < 1) {
        ok = false
    }

    String planets = views.planetList(-1)
    if (not planets.contains("Planets:")) {
        ok = false
    }
    int64 homeId = views.planetIdAt(-1, 1)
    if (homeId < 0) {
        ok = false
    } else {
        String rock = views.planetDetail(homeId)
        if (not rock.contains("Planet id=")) {
            ok = false
        }
        if (not rock.contains("Sitting fleets:")) {
            ok = false
        }
    }

    String owned = views.planetList(0)
    if (not owned.contains("Planets owned by 0:")) {
        ok = false
    }

    String fleets = views.fleetList(-1)
    if (not fleets.contains("Fleets:")) {
        ok = false
    }
    int64 fleetId = views.fleetIdAt(-1, 1)
    if (fleetId < 0) {
        ok = false
    } else {
        String detail = views.fleetDetail(fleetId)
        if (not detail.contains("Fleet id=")) {
            ok = false
        }
        if (not detail.contains("design=")) {
            ok = false
        }
    }

    String designs = views.designList()
    if (not designs.contains("Designs:")) {
        ok = false
    }
    if (not designs.contains("scout")) {
        ok = false
    }

    String jobs = views.jobsList()
    if (not jobs.contains("Build jobs:")) {
        ok = false
    }

    String serverDump = views.serverConfigDump()
    if (not serverDump.contains("Server config (read-only):")) {
        ok = false
    }
    if (not serverDump.contains("serve=")) {
        ok = false
    }
    String scenarioDump = views.scenarioConfigDump()
    if (not scenarioDump.contains("Scenario setup")) {
        ok = false
    }
    if (not scenarioDump.contains("mode=")) {
        ok = false
    }

    driver.close()
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
