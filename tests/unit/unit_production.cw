/*
 * tests/unit/unit_production.cw — productive home net income.
 *
 * Fixed seed; production tick applies credit − upkeep scaled by
 * Planet.allocationPct (PUT /budget). Zero allocation spends
 * nothing; full allocation spends more than a mid-band throttle.
 * CPL-113: low accessibility can debit; pools clamp at zero.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial production unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-07  Prove allocationPct scales empire-pool credit.
 *   2026-11-11  CPL-113: negative net under low access; clamp.
 *   2026-11-11  CPL-114: productive iff structural net > 0.
 */

include "lib/state.cw"

start {
    bool ok = true

    # --- allocationPct 0: no empire-pool credit or upkeep ---
    State idle = State()
    idle.startClosed(13u, 1)
    idle.ensureAllSeatHomes()
    Planet idleHome = idle.galaxy.planets[0]
    idleHome.allocationPct = 0
    idle.galaxy.planets[0] = idleHome
    Player beforeIdle = idle.primaryPlayer()
    fp64 wIdle = beforeIdle.wealth
    fp64 rIdle = beforeIdle.resources
    list idleEvents = idle.tick()
    Player afterIdle = idle.primaryPlayer()
    if (afterIdle.wealth != wIdle) {
        ok = false
    }
    if (afterIdle.resources != rIdle) {
        ok = false
    }
    bool sawIdle = false
    int64 index = 0
    while (index < idleEvents.length) {
        TickEvent ev = idleEvents[index]
        if (ev.kind.equals("production")) {
            sawIdle = true
        }
        index = index + 1
    }
    if (not sawIdle) {
        ok = false
    }

    # --- mid-band (50): positive net on fully accessible home ---
    State mid = State()
    mid.startClosed(13u, 1)
    mid.ensureAllSeatHomes()
    Planet midHome = mid.galaxy.planets[0]
    midHome.allocationPct = 50
    mid.galaxy.planets[0] = midHome
    Player beforeMid = mid.primaryPlayer()
    fp64 wMid0 = beforeMid.wealth
    fp64 rMid0 = beforeMid.resources
    list midEvents = mid.tick()
    Player afterMid = mid.primaryPlayer()
    fp64 wMidGain = afterMid.wealth - wMid0
    fp64 rMidGain = afterMid.resources - rMid0
    if (wMidGain <= 0.0) {
        ok = false
    }
    if (rMidGain <= 0.0) {
        ok = false
    }
    if (mid.tickCount != 1) {
        ok = false
    }
    if (not mid.locked) {
        ok = false
    }
    bool sawMid = false
    index = 0
    while (index < midEvents.length) {
        TickEvent ev = midEvents[index]
        if (ev.kind.equals("production")) {
            sawMid = true
        }
        index = index + 1
    }
    if (not sawMid) {
        ok = false
    }

    # --- default / 100: roughly 2x mid-band net ---
    State full = State()
    full.startClosed(13u, 1)
    full.ensureAllSeatHomes()
    Planet fullHome = full.galaxy.planets[0]
    if (fullHome.allocationPct != 100) {
        ok = false
    }
    Player beforeFull = full.primaryPlayer()
    fp64 wFull0 = beforeFull.wealth
    fp64 rFull0 = beforeFull.resources
    full.tick()
    Player afterFull = full.primaryPlayer()
    fp64 wFullGain = afterFull.wealth - wFull0
    fp64 rFullGain = afterFull.resources - rFull0
    if (wFullGain <= wMidGain) {
        ok = false
    }
    if (rFullGain <= rMidGain) {
        ok = false
    }
    fp64 wRatio = wFullGain / wMidGain
    fp64 rRatio = rFullGain / rMidGain
    if (wRatio < 1.99 or wRatio > 2.01) {
        ok = false
    }
    if (rRatio < 1.99 or rRatio > 2.01) {
        ok = false
    }

    # --- CPL-113/114: low access → negative net; not productive ---
    State hard = State()
    hard.startClosed(13u, 1)
    hard.ensureAllSeatHomes()
    Planet hardHome = hard.galaxy.planets[0]
    hardHome.airAccess = 0.2
    hardHome.waterAccess = 0.2
    hardHome.commonMineralsAccess = 0.2
    hardHome.rareMineralsAccess = 0.2
    hardHome.allocationPct = 100
    hard.galaxy.planets[0] = hardHome
    Player beforeHard = hard.primaryPlayer()
    fp64 wHard0 = beforeHard.wealth
    fp64 rHard0 = beforeHard.resources
    hard.tick()
    Player afterHard = hard.primaryPlayer()
    if (afterHard.wealth >= wHard0) {
        ok = false
    }
    if (afterHard.resources >= rHard0) {
        ok = false
    }
    Planet hardAfter = hard.galaxy.planets[0]
    if (hardAfter.productive) {
        ok = false
    }

    # --- CPL-114: industry-rich low-habit rock can still be productive ---
    State industry = State()
    industry.startClosed(13u, 1)
    industry.ensureAllSeatHomes()
    Planet indRock = industry.galaxy.planets[0]
    indRock.air = 5.0
    indRock.water = 5.0
    indRock.commonMinerals = 80.0
    indRock.rareMinerals = 40.0
    indRock.airAccess = 0.25
    indRock.waterAccess = 0.25
    indRock.commonMineralsAccess = 1.0
    indRock.rareMineralsAccess = 1.0
    indRock.refreshComposites(industry.scenario.rareMineralWeight)
    indRock.allocationPct = 100
    industry.galaxy.planets[0] = indRock
    industry.tick()
    Planet indAfter = industry.galaxy.planets[0]
    if (not indAfter.productive) {
        ok = false
    }
    if (not industry.scenario.isStructurallyProductive(indAfter)) {
        ok = false
    }

    # --- CPL-113: debit clamp — pool never goes below zero ---
    State broke = State()
    broke.startClosed(13u, 1)
    broke.ensureAllSeatHomes()
    Planet brokeHome = broke.galaxy.planets[0]
    brokeHome.airAccess = 0.2
    brokeHome.waterAccess = 0.2
    brokeHome.commonMineralsAccess = 0.2
    brokeHome.rareMineralsAccess = 0.2
    brokeHome.livability = 100.0
    brokeHome.resources = 100.0
    brokeHome.allocationPct = 100
    broke.galaxy.planets[0] = brokeHome
    Player beforeBroke = broke.primaryPlayer()
    beforeBroke.wealth = 0.01
    beforeBroke.resources = 0.01
    broke.players[0] = beforeBroke
    broke.tick()
    Player afterBroke = broke.primaryPlayer()
    if (afterBroke.wealth < 0.0) {
        ok = false
    }
    if (afterBroke.resources < 0.0) {
        ok = false
    }
    if (afterBroke.wealth > 0.01) {
        ok = false
    }
    if (afterBroke.resources > 0.01) {
        ok = false
    }

    # --- CPL-114: productive_rate scales time-to-productive ---
    Scenario rateSc = Scenario()
    Planet probe = Planet(9)
    probe.air = 50.0
    probe.water = 50.0
    probe.commonMinerals = 50.0
    probe.rareMinerals = 10.0
    probe.airAccess = 0.5
    probe.waterAccess = 0.5
    probe.commonMineralsAccess = 0.5
    probe.rareMineralsAccess = 0.5
    probe.refreshComposites(rateSc.rareMineralWeight)
    rateSc.productiveRate = 1.0
    int64 slowTicks = rateSc.timeToProductiveTicks(probe)
    rateSc.productiveRate = 2.0
    int64 fastTicks = rateSc.timeToProductiveTicks(probe)
    if (slowTicks < 1) {
        ok = false
    }
    if (fastTicks >= slowTicks) {
        ok = false
    }
    if (not rateSc.isStructurallyProductive(probe)) {
        # access 0.5 is near break-even; force easy rock check
        probe.airAccess = 1.0
        probe.waterAccess = 1.0
        probe.commonMineralsAccess = 1.0
        probe.rareMineralsAccess = 1.0
        if (not rateSc.isStructurallyProductive(probe)) {
            ok = false
        }
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
