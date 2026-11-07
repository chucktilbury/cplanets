/*
 * tests/unit/unit_serverVerbose.cw — verbosity logger + driver hooks.
 *
 * Checks setup verbosity parse, quiet default, settings PUT emit
 * at level 1, and combat path emit at level 2 (synthetic events /
 * open engagement). Capture list is asserted; stdout also prints.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial server verbosity unit program.
 */

include "lib/setupParse.cw"
include "lib/wireBytes.cw"
include "server/driver.cw"
include "server/verboseLog.cw"

start {
    bool ok = true

    # --- setup key ---
    SetupParse parser = SetupParse()
    Scenario loaded = parser.parseText("verbosity = 1\n")
    if (not parser.ok or loaded.verbosity != 1) {
        ok = false
    }

    # --- quiet: no settings line ---
    ServerVerboseLog quiet = ServerVerboseLog()
    quiet.echo = false
    quiet.setLevel(0)
    buffer tiny = buffer[]
    tiny.append(1)
    quiet.logPolicyPut(0, tiny)
    if (quiet.lines.length != 0) {
        ok = false
    }

    # --- level 1: opaque settings ---
    ServerVerboseLog settings = ServerVerboseLog()
    settings.echo = false
    settings.setLevel(1)
    settings.logPolicyPut(3, tiny)
    if (not settings.linesContain("verbosity: settings player=3")) {
        ok = false
    }
    if (not settings.linesContain("bytes=1")) {
        ok = false
    }

    # --- level 1: decoded v1 policy shape ---
    WireBytes w = WireBytes()
    w.writeU8(1)
    w.writeU8(3)
    w.writeU8(40)
    w.writeU8(50)
    w.writeU8(10)
    w.writeU8(60)
    w.writeU8(0)
    w.writeU8(0)
    buffer shaped = w.bytes
    settings.clearLines()
    settings.logPolicyPut(0, shaped)
    if (not settings.linesContain("role=trader")) {
        ok = false
    }
    if (not settings.linesContain("expansion=40")) {
        ok = false
    }

    # --- level 2: combat event + engagement strength ---
    ServerVerboseLog combatLog = ServerVerboseLog()
    combatLog.echo = false
    combatLog.setLevel(2)
    list events = []
    events.append(TickEvent("combat_open", 2, 5, 0, 1))
    events.append(TickEvent("depart", 2, 5, 0, 0))
    list fights = []
    Engagement fight = Engagement(1)
    fight.openPlanet(5, 2, 0, 1, 12.5, 8.0)
    fights.append(fight)
    combatLog.logCombatTick(7, events, fights)
    if (not combatLog.linesContain("kind=combat_open")) {
        ok = false
    }
    if (combatLog.linesContain("kind=depart")) {
        ok = false
    }
    if (not combatLog.linesContain("atk_milli=12500")) {
        ok = false
    }
    if (not combatLog.linesContain("def_milli=8000")) {
        ok = false
    }

    # --- GameDriver putPolicy hooks verbosity ---
    State game = State()
    game.startClosed(19u, 2)
    GameDriver driver = GameDriver(
        game, true, "", false, 10000u)
    if (driver.verbose.level != 0) {
        ok = false
    }
    driver.setVerbosity(1)
    driver.verbose.echo = false
    driver.verbose.clearLines()
    if (not driver.putPolicy(0, shaped)) {
        ok = false
    }
    if (not driver.verbose.linesContain(
        "verbosity: settings player=0")) {
        ok = false
    }
    driver.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
