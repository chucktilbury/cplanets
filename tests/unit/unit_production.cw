/*
 * tests/unit/unit_production.cw — productive home credits empire pools.
 *
 * Fixed seed; production tick raises wealth/resources scaled by
 * Planet.allocationPct (PUT /budget). Zero allocation spends nothing;
 * full allocation spends more than a mid-band throttle (PLAN §4.C /
 * RULES §7.1 / DIALOGS §4.2).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial production unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 *   2026-11-07  Prove allocationPct scales empire-pool credit.
 */

include "lib/state.cw"

start {
    bool ok = true

    # --- allocationPct 0: no empire-pool credit ---
    State idle = State()
    idle.startClosed(13u, 1)
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

    # --- mid-band (50): positive gain ---
    State mid = State()
    mid.startClosed(13u, 1)
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

    # --- default / 100: roughly 2x mid-band gain ---
    State full = State()
    full.startClosed(13u, 1)
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

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
