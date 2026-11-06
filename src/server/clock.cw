/*
 * src/server/clock.cw — injectable / wall tick clock (Phase F).
 *
 * Owns when the server may fire a cadence tick. Injectable mode
 * advances only under test / admin control (no wall sleep in CI).
 * Wall mode reads Time.Clock monotonic milliseconds (RULES §2 /
 * PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial injectable and wall cadence clock.
 */

import time as Time

/*
 * ServerClock decides when the next real-time tick is due.
 *
 * Period is clamped to the provisional 1–30 second band at
 * construction. Injectable clocks ignore wall time until
 * advanceMs / setNowMs are called.
 */
class ServerClock {
    bool injectable
    int64 periodMs
    uint64 nowMs
    uint64 lastFireMs
    bool everFired
    Time.Clock wall

    /*
     * Construct a cadence clock.
     *
     * Purpose: pin the tick period and choose injectable vs wall
     * time so tests never sleep (PLAN §4.F item 5).
     *
     * Parameters:
     *   periodSeconds — desired tick period; clamped to 1–30.
     *   useInjectable — true for tests / admin advance; false for
     *                   live wall-clock cadence.
     *
     * Returns: ServerClock with now/last at 0 and everFired false.
     */
    ServerClock(int64 periodSeconds, bool useInjectable) {
        injectable = useInjectable
        int64 seconds = periodSeconds
        if (seconds < 1) {
            seconds = 1
        } else (seconds > 30) {
            seconds = 30
        }
        periodMs = seconds * 1000
        nowMs = 0u
        lastFireMs = 0u
        everFired = false
        wall = Time.Clock()
        if (not injectable) {
            nowMs = wall.monotonicMilliseconds()
            lastFireMs = nowMs
        }
    }

    /*
     * Read the current clock milliseconds.
     *
     * Purpose: presence handshake and due checks share one time
     * base. Wall mode refreshes from the OS; injectable returns
     * the last set/advanced value.
     *
     * Parameters: none.
     *
     * Returns: monotonic-style milliseconds (injectable or wall).
     */
    uint64 now() {
        if (not injectable) {
            nowMs = wall.monotonicMilliseconds()
        }
        return(nowMs)
    }

    /*
     * Force the injectable clock to an absolute value.
     *
     * Purpose: unit tests place the clock at a known ms without
     * sleeping.
     *
     * Parameters:
     *   absoluteMs — new injectable now.
     *
     * Returns: true when injectable; false when wall (ignored).
     */
    bool setNowMs(uint64 absoluteMs) {
        if (not injectable) {
            return(false)
        }
        nowMs = absoluteMs
        return(true)
    }

    /*
     * Advance the injectable clock by a delta.
     *
     * Purpose: simulate elapsed real time between policy writes
     * without wall sleep.
     *
     * Parameters:
     *   deltaMs — milliseconds to add (0 is a no-op success).
     *
     * Returns: true when injectable; false when wall (ignored).
     */
    bool advanceMs(uint64 deltaMs) {
        if (not injectable) {
            return(false)
        }
        nowMs = nowMs + deltaMs
        return(true)
    }

    /*
     * True when a cadence fire is due.
     *
     * Purpose: the server loop and maybeTick consult this before
     * snapshot → tick → publish. First fire is due immediately
     * when everFired is false (bootstrap).
     *
     * Parameters: none.
     *
     * Returns: true when now - lastFire >= period, or never fired.
     */
    bool due() {
        uint64 stamp = now()
        if (not everFired) {
            return(true)
        }
        if (stamp < lastFireMs) {
            return(true)
        }
        uint64 elapsed = stamp - lastFireMs
        return(elapsed >= uint64(periodMs))
    }

    /*
     * Record that a tick just fired at now().
     *
     * Purpose: reset the cadence window after snapshot/tick/
     * publish so the next due waits a full period.
     *
     * Parameters: none.
     *
     * Returns: nothing; sets lastFireMs and everFired.
     */
    void markFired() {
        lastFireMs = now()
        everFired = true
    }
}
