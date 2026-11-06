/*
 * src/server/driver.cw — real-time tick driver (Phase F).
 *
 * Sole cadence owner: when due, snapshot policies → State.tick →
 * persist → publish state + digest. No all-ready barrier. AFK =
 * last policy. Injectable clock / advance N for tests. Pause only
 * with one human. Setup locks on first tick. All-humans-quit ends
 * the live game (RULES §2 / PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GameDriver cadence loop helpers.
 */

include "clock.cw"
include "../lib/state.cw"
include "policyTable.cw"
include "presence.cw"
include "publish.cw"
include "snapshotStore.cw"

/*
 * GameDriver is the server-side sole writer for one live game.
 *
 * Holds State, policies, presence, clock, and SQLite-shaped store.
 * TCP and verb framing stay in handler / listen; this class is the
 * injectable-clock core under test without sockets.
 */
class GameDriver {
    State game
    PolicyTable policies
    PresenceBook presence
    ServerClock clock
    SnapshotStore store
    PublishCodec publisher
    buffer publishedState
    buffer publishedDigest
    list lastEvents
    list lastSnapshot
    bool paused
    bool storeEnabled
    int64 fireCount

    /*
     * Construct a driver around a started State.
     *
     * Purpose: wire clock, empty policies/presence, and optional
     * SQLite store for one stand-alone live game.
     *
     * Parameters:
     *   started — State already startClosed / loaded.
     *   useInjectable — true for tests (no wall sleep).
     *   dbPath — SQLite path or "" for temp; unused when
     *            enableStore is false.
     *   enableStore — when false, skip SQLite (unit tests that
     *                 only need cadence + publish blobs).
     *   handshakeMissMs — presence drop window.
     *
     * Returns: GameDriver ready for putPolicy / advanceTicks.
     */
    GameDriver(
        State started,
        bool useInjectable,
        String dbPath,
        bool enableStore,
        uint64 handshakeMissMs) {
        game = started
        policies = PolicyTable()
        policies.ensureSeats(game.players.length)
        presence = PresenceBook(handshakeMissMs)
        presence.ensureSeats(game.players.length)
        clock = ServerClock(
            game.scenario.clampTickPeriod(),
            useInjectable)
        store = SnapshotStore(dbPath)
        storeEnabled = enableStore
        if (storeEnabled) {
            store.open()
        }
        publisher = PublishCodec()
        publishedState = buffer[]
        publishedDigest = buffer[]
        lastEvents = []
        lastSnapshot = []
        paused = false
        fireCount = 0
        publishedState = publisher.encodeState(game, policies)
        publishedDigest = publisher.encodeDigest(
            game.tickCount, lastEvents)
    }

    /*
     * Accept a policy PUT for a seat.
     *
     * Purpose: anytime write; applies on next tick snapshot. Does
     * not advance the clock or tick.
     *
     * Parameters:
     *   playerId — empire id.
     *   blob — opaque policy bytes.
     *
     * Returns: true when stored.
     */
    bool putPolicy(int64 playerId, buffer blob) {
        if (game.ended) {
            return(false)
        }
        return(policies.put(playerId, blob))
    }

    /*
     * Record a presence handshake for a seat.
     *
     * Purpose: AFK ≠ drop — live contact without a policy PUT.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when recorded.
     */
    bool handshake(int64 playerId) {
        if (game.ended) {
            return(false)
        }
        return(presence.handshake(playerId, clock.now()))
    }

    /*
     * Mark a voluntary quit and refresh end status.
     *
     * Purpose: all-humans-quit ends the live game (RULES §2).
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when the seat was updated.
     */
    bool quitPlayer(int64 playerId) {
        if (playerId < 0 or playerId >= game.players.length) {
            return(false)
        }
        Player seat = game.players[playerId]
        seat.markQuit()
        game.players[playerId] = seat
        presence.markDrop(playerId)
        game.refreshEndStatus()
        republishWithoutTick()
        return(true)
    }

    /*
     * Apply a drop (lost contact) to a seat.
     *
     * Purpose: handshake miss / TCP close. Last policy continues
     * for the live remainder; no rejoin (RULES §2).
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when marked.
     */
    bool dropPlayer(int64 playerId) {
        if (playerId < 0 or playerId >= game.players.length) {
            return(false)
        }
        if (not presence.markDrop(playerId)) {
            # still ensure State flags match
        }
        Player seat = game.players[playerId]
        seat.markDrop()
        game.players[playerId] = seat
        game.refreshEndStatus()
        republishWithoutTick()
        return(true)
    }

    /*
     * Request pause on or off.
     *
     * Purpose: pause only when exactly one live human remains.
     * With two or more humans, reject and keep the clock running.
     *
     * Parameters:
     *   wantPaused — desired pause flag.
     *
     * Returns: true when the pause state changed or already matched
     * and allowed; false when not offered.
     */
    bool setPaused(bool wantPaused) {
        if (wantPaused and not presence.pauseAllowed(game.players)) {
            return(false)
        }
        paused = wantPaused
        return(true)
    }

    /*
     * True when pause is currently offered.
     *
     * Purpose: admin / status responses.
     *
     * Parameters: none.
     *
     * Returns: presence.pauseAllowed over current seats.
     */
    bool pauseOffered() {
        return(presence.pauseAllowed(game.players))
    }

    /*
     * Fire one cadence step if due and not paused/ended.
     *
     * Purpose: snapshot → tick → persist → publish (PLAN §4.F).
     *
     * Parameters: none.
     *
     * Returns: true when a tick actually fired.
     */
    bool maybeTick() {
        if (game.ended or paused) {
            return(false)
        }
        scanPresenceDrops()
        if (game.ended) {
            return(false)
        }
        if (not clock.due()) {
            return(false)
        }
        return(fireOne())
    }

    /*
     * Advance N ticks via the injectable clock (admin / tests).
     *
     * Purpose: CI without wall sleep. Forces period elapsed N
     * times, firing each due tick. Wall clocks reject this.
     *
     * Parameters:
     *   count — number of ticks to fire (clamped >= 0).
     *
     * Returns: number of ticks actually fired.
     */
    int64 advanceTicks(int64 count) {
        if (not clock.injectable) {
            return(0)
        }
        if (count < 0) {
            count = 0
        }
        int64 fired = 0
        int64 step = 0
        while (step < count) {
            if (game.ended) {
                return(fired)
            }
            if (paused) {
                return(fired)
            }
            clock.advanceMs(uint64(clock.periodMs))
            if (maybeTick()) {
                fired = fired + 1
            }
            step = step + 1
        }
        return(fired)
    }

    /*
     * Scan handshake misses and apply drops.
     *
     * Purpose: presence maintenance between ticks.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void scanPresenceDrops() {
        list droppedIds = []
        presence.scanDrops(clock.now(), droppedIds)
        int64 index = 0
        while (index < droppedIds.length) {
            int64 id = droppedIds[index]
            Player seat = game.players[id]
            if (not seat.quit and not seat.dropped) {
                seat.markDrop()
                game.players[id] = seat
            }
            index = index + 1
        }
        if (droppedIds.length > 0) {
            game.refreshEndStatus()
        }
    }

    /*
     * Snapshot policies, tick, persist, publish.
     *
     * Purpose: one cadence fire body shared by maybeTick.
     *
     * Parameters: none.
     *
     * Returns: true after a successful fire.
     */
    bool fireOne() {
        # Opaque policy blobs are snapshotted for publish/persist.
        # Structured apply onto State lands with later client work;
        # tick() still advances fleets/orders already on State.
        lastSnapshot = policies.snapshot()
        lastEvents = game.tick()
        publishedState = publisher.encodeState(game, policies)
        publishedDigest = publisher.encodeDigest(
            game.tickCount, lastEvents)
        if (storeEnabled and store.openOk) {
            store.persist(
                game.tickCount,
                publishedState,
                publishedDigest,
                policies)
        }
        clock.markFired()
        fireCount = fireCount + 1
        return(true)
    }

    /*
     * Refresh published blobs without advancing tickCount.
     *
     * Purpose: quit/drop end status should be visible on GET
     * state before the next cadence fire.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void republishWithoutTick() {
        publishedState = publisher.encodeState(game, policies)
        publishedDigest = publisher.encodeDigest(
            game.tickCount, lastEvents)
        if (storeEnabled and store.openOk) {
            store.persist(
                game.tickCount,
                publishedState,
                publishedDigest,
                policies)
        }
    }

    /*
     * Close the snapshot store.
     *
     * Purpose: end of process; temp DB discarded (no save).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void close() {
        if (storeEnabled) {
            store.close()
        }
    }
}
