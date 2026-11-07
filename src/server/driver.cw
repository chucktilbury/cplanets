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
 *   2026-11-05  Phase H: apply AI-lag tick auto-config at start.
 *   2026-11-06  TUNING B: owned fleet issueOrder / recallFleet
 *               + pause flag in publish.
 *   2026-11-07  Server verbosity: policy PUT + combat tick logs.
 *   2026-11-07  Verbosity overlay clamps via ServerVerboseLog 0–10.
 *   2026-11-07  Ship create: owned design develop + yard build.
 */

include "clock.cw"
include "../lib/state.cw"
include "policyTable.cw"
include "presence.cw"
include "publish.cw"
include "snapshotStore.cw"
include "verboseLog.cw"

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
    ServerVerboseLog verbose

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
        # Tick period may auto-config from AI lag (RULES §2); still
        # setup-tunable when tickAutoConfigFromAiLag is false.
        game.scenario.applyAiLagAutoConfig()
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
        verbose = ServerVerboseLog()
        verbose.setLevel(game.scenario.verbosity)
        publishedState = publisher.encodeState(
            game, policies, paused)
        publishedDigest = publisher.encodeDigest(
            game.tickCount, lastEvents)
    }

    /*
     * Overlay the active verbosity level (CLI / tests).
     *
     * Purpose: --verbosity after setup load, or unit programs that
     * enable logging without rewriting Scenario text.
     *
     * Parameters:
     *   value — 0–10 on the provisional ladder (clamped).
     *
     * Returns: nothing.
     */
    void setVerbosity(int64 value) {
        verbose.setLevel(value)
        game.scenario.verbosity = verbose.level
    }

    /*
     * Accept a policy PUT for a seat.
     *
     * Purpose: anytime write; applies on next tick snapshot. Does
     * not advance the clock or tick. At verbosity >= settingsAt
     * (provisional 3), logs the settings change to stdout.
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
        bool ok = policies.put(playerId, blob)
        if (ok) {
            verbose.logPolicyPut(playerId, blob)
        }
        return(ok)
    }

    /*
     * Issue a travel / trade order for a seat-owned fleet.
     *
     * Purpose: wire PUT /order for list-client dispatch chrome
     * (TUNING-PLAYABLE B). Ownership-checked; mid-dispatch lock
     * still enforced inside State helpers (RULES §5).
     *
     * Parameters:
     *   playerId — requesting seat (must own the fleet).
     *   fleetId — sitting fleet to order.
     *   order — explore / take / trade / move / ambush.
     *   destPlanetId — destination rock.
     *
     * Returns: true when the order was queued.
     */
    bool issueOwnedOrder(
        int64 playerId,
        int64 fleetId,
        String order,
        int64 destPlanetId) {
        if (game.ended) {
            return(false)
        }
        Fleet fleet = game.findFleet(fleetId)
        if (fleet.id < 0 or fleet.ownerId != playerId) {
            return(false)
        }
        bool ok = false
        if (order.equals("trade")) {
            # Self-trade stand-in (agreementId -1) for balance loops;
            # multi-partner pact chrome stays Phase E / later B5.
            ok = game.issueTrade(fleetId, destPlanetId, -1, -1, 0)
        } else {
            ok = game.issueOrder(fleetId, order, destPlanetId)
        }
        if (ok) {
            republishWithoutTick()
        }
        return(ok)
    }

    /*
     * Request recall for a seat-owned fleet.
     *
     * Purpose: wire PUT /recall for list-client chrome (RULES §5.2).
     *
     * Parameters:
     *   playerId — requesting seat (must own the fleet).
     *   fleetId — fleet to recall / cancel.
     *
     * Returns: true when a recall request was recorded.
     */
    bool recallOwnedFleet(int64 playerId, int64 fleetId) {
        if (game.ended) {
            return(false)
        }
        Fleet fleet = game.findFleet(fleetId)
        if (fleet.id < 0 or fleet.ownerId != playerId) {
            return(false)
        }
        bool ok = game.recallFleet(fleetId)
        if (ok) {
            republishWithoutTick()
        }
        return(ok)
    }

    /*
     * Queue non-instant design development for a seat.
     *
     * Purpose: wire PUT /design for list-client ship create chrome
     * (RULES §5.3 / DIALOGS §6). Spends wealth; develops over
     * designDevelopTicks.
     *
     * Parameters:
     *   playerId — empire paying development wealth.
     *   draft — design template (id rewritten by State).
     *
     * Returns: new design id, or −1 on failure.
     */
    int64 queueOwnedDesign(int64 playerId, Design draft) {
        if (game.ended) {
            return(-1)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            return(-1)
        }
        int64 id = game.queueDesignDevelop(playerId, draft)
        if (id >= 0) {
            republishWithoutTick()
        }
        return(id)
    }

    /*
     * Queue a yard hull build on a seat-owned productive shipyard.
     *
     * Purpose: wire PUT /build for list-client yard chrome
     * (RULES §5.3). Spends resources; completes after
     * yardBuildTicks into a sit fleet.
     *
     * Parameters:
     *   playerId — empire paying resources (must own the yard).
     *   planetId — productive shipyard planet.
     *   designId — ready design to produce.
     *
     * Returns: true when the BuildJob was queued.
     */
    bool queueOwnedBuild(
        int64 playerId, int64 planetId, int64 designId) {
        if (game.ended) {
            return(false)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            return(false)
        }
        bool ok = game.queueYardBuild(playerId, planetId, designId)
        if (ok) {
            republishWithoutTick()
        }
        return(ok)
    }

    /*
     * Queue reclaim of sitting hulls at a seat-owned shipyard.
     *
     * Purpose: wire PUT /reclaim-hulls for yard reclaim path
     * (RULES §5.2 — reclaim only at a yard).
     *
     * Parameters:
     *   playerId — requesting seat (must own the fleet).
     *   fleetId — sitting fleet at a yard.
     *   hulls — how many hulls to reclaim.
     *
     * Returns: true when a ReclaimJob was queued.
     */
    bool queueOwnedReclaim(
        int64 playerId, int64 fleetId, int64 hulls) {
        if (game.ended) {
            return(false)
        }
        Fleet fleet = game.findFleet(fleetId)
        if (fleet.id < 0 or fleet.ownerId != playerId) {
            return(false)
        }
        bool ok = game.queueReclaim(fleetId, hulls)
        if (ok) {
            republishWithoutTick()
        }
        return(ok)
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
        republishWithoutTick()
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
        verbose.logCombatTick(
            game.tickCount, lastEvents, game.engagements)
        publishedState = publisher.encodeState(
            game, policies, paused)
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
        publishedState = publisher.encodeState(
            game, policies, paused)
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
