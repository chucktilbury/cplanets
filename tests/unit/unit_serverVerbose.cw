/*
 * tests/unit/unit_serverVerbose.cw — verbosity logger + driver hooks.
 *
 * Checks setup verbosity parse, 0–10 clamp, quiet default, settings
 * PUT emit at provisional settingsAt (3), and combat path emit at
 * combatAt (6). Capture list is asserted; stdout also prints.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial server verbosity unit program.
 *   2026-11-07  Remap asserts to 0–10 provisional thresholds + clamp.
 */

include "lib/setupParse.cw"
include "lib/wireBytes.cw"
include "server/driver.cw"
include "server/verboseLog.cw"

start {
    bool ok = true

    # --- setup key ---
    SetupParse parser = SetupParse()
    Scenario loaded = parser.parseText("verbosity = 3\n")
    if (not parser.ok or loaded.verbosity != 3) {
        ok = false
    }

    # --- clamp out of range (setup) ---
    Scenario high = parser.parseText("verbosity = 99\n")
    if (not parser.ok or high.verbosity != 10) {
        ok = false
    }
    Scenario low = parser.parseText("verbosity = -4\n")
    if (not parser.ok or low.verbosity != 0) {
        ok = false
    }

    # --- quiet: no settings line ---
    ServerVerboseLog quiet = ServerVerboseLog()
    quiet.echo = false
    quiet.setLevel(0)
    buffer tiny = buffer[]
    tiny.append(1)
    quiet.logPolicyPut(0, tiny)
    quiet.logCombatTick(1, [], [])
    if (quiet.lines.length != 0) {
        ok = false
    }

    # --- below settingsAt: still quiet for settings ---
    ServerVerboseLog midLow = ServerVerboseLog()
    midLow.echo = false
    midLow.setLevel(2)
    midLow.logPolicyPut(0, tiny)
    if (midLow.lines.length != 0) {
        ok = false
    }

    # --- level settingsAt (3): opaque settings ---
    ServerVerboseLog settings = ServerVerboseLog()
    settings.echo = false
    settings.setLevel(3)
    settings.logPolicyPut(3, tiny)
    if (not settings.linesContain("verbosity: settings player=3")) {
        ok = false
    }
    if (not settings.linesContain("bytes=1")) {
        ok = false
    }

    # --- level settingsAt: decoded v1 policy shape ---
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

    # --- below combatAt: settings ok, no combat ---
    settings.clearLines()
    settings.setLevel(5)
    list earlyEvents = []
    earlyEvents.append(TickEvent("combat_open", 2, 5, 0, 1))
    settings.logCombatTick(7, earlyEvents, [])
    if (settings.lines.length != 0) {
        ok = false
    }

    # --- level combatAt (6): combat event + engagement strength ---
    ServerVerboseLog combatLog = ServerVerboseLog()
    combatLog.echo = false
    combatLog.setLevel(6)
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

    # --- setLevel clamps ---
    combatLog.setLevel(42)
    if (combatLog.level != 10 or not combatLog.fullEnabled()) {
        ok = false
    }
    combatLog.setLevel(-1)
    if (combatLog.level != 0) {
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
    driver.setVerbosity(3)
    driver.verbose.echo = false
    driver.verbose.clearLines()
    if (not driver.putPolicy(0, shaped)) {
        ok = false
    }
    if (not driver.verbose.linesContain(
        "verbosity: settings player=0")) {
        ok = false
    }
    driver.setVerbosity(99)
    if (driver.verbose.level != 10 or game.scenario.verbosity != 10) {
        ok = false
    }
    driver.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
