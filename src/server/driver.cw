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
 *   2026-11-07  Planet budget + private/broadcast compose inbox.
 *   2026-11-07  Wire afk_timeout_seconds / afk_shrink_factor.
 *   2026-11-07  Budget allocationPct applied in production tick.
 *   2026-11-07  Verbosity lines for design / build / reclaim.
 *   2026-11-07  issueOwnedOrder accepts optional hull peel count.
 *   2026-11-07  lastOrderError + pre-peel validation for clear
 *               PUT /order reject reasons (fleet missing / locked).
 *   2026-11-08  Handshake grants seat home yard + starter fleet.
 *   2026-11-08  PUT /suspended intentional AFK skips handshake_miss.
 *   2026-11-08  Server allocates free seats on handshake; clients
 *               do not claim playerId. Keep-alive only when connected.
 *   2026-11-08  Lobby until operator go; reconnect tokens on allocate;
 *               reclaim by token; ticks blocked in lobby (incl. admin).
 *   2026-11-08  Grow seats on allocate; softMaxPlayers optional cap
 *               (0 = unlimited within practical bounds).
 *   2026-11-08  Lobby suppresses end-status (all-humans-quit /
 *               eliminate-all); AI allocate marks human=false.
 *   2026-11-09  Lobby miss-drop clears reconnect tokens so
 *               abandoned seats are free (no ghost clients);
 *               after go, drop still keeps tokens for reclaim.
 *               Handshake / seat connect never leave lobby.
 *   2026-11-09  Lobby also rejects play verbs (order/build/
 *               design/recall/reclaim/budget) and publishes the
 *               held clock as paused so AI/human clients do not
 *               treat connect as serve-start before operator go.
 */

include "clock.cw"
include "../lib/playerMessage.cw"
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
    list inbox
    bool paused
    bool running
    bool storeEnabled
    int64 fireCount
    ServerVerboseLog verbose
    String lastOrderError
    # Optional soft maximum of allocated seats (config players).
    # 0 = unlimited within State.seatHardCap (server config).
    int64 softMaxPlayers

    /*
     * Construct a driver around a started State.
     *
     * Purpose: wire clock, empty policies/presence, and optional
     * SQLite store for one stand-alone live game. Starts in
     * **lobby** (running=false): TCP accept, seating, and status
     * work, but wall / injectable ticks do not fire until go().
     * softMaxPlayers defaults to 0 (unlimited); the serve path
     * sets it from ServerConfig.players after construct.
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
     * Returns: GameDriver in lobby, ready for handshake / go /
     * putPolicy / advanceTicks (after go).
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
        inbox = []
        paused = false
        running = false
        fireCount = 0
        lastOrderError = ""
        softMaxPlayers = 0
        verbose = ServerVerboseLog()
        verbose.setLevel(game.scenario.verbosity)
        publishedState = publisher.encodeState(
            game, policies, publishPausedFlag())
        publishedDigest = publisher.encodeDigest(
            game.tickCount, lastEvents)
    }

    /*
     * True while the session is still in lobby (pre-go).
     *
     * Purpose: status banner, menu Go affordance, and tick gates.
     *
     * Parameters: none.
     *
     * Returns: true when running is false.
     */
    bool inLobby() {
        return(not running)
    }

    /*
     * True when the game clock must not advance for clients.
     *
     * Purpose: lobby holds wall/injectable cadence until operator
     * go, and the one-human pause flag also holds it. Publish and
     * status chrome use this so a connected client sees the
     * session as held (paused) rather than a live running clock
     * at tick 0. Play verbs also consult running via requireGo.
     *
     * Parameters: none.
     *
     * Returns: true when paused or still in lobby.
     */
    bool clockHeld() {
        return(paused or not running)
    }

    /*
     * Paused flag written into published state / digest chrome.
     *
     * Purpose: GET /state consumers (human GUI, AI) must see the
     * lobby hold. Raw `paused` alone is false in lobby, which made
     * connect look like an unpaused live game even while ticks
     * were gated — AI then queued explore/build before go.
     *
     * Parameters: none.
     *
     * Returns: clockHeld() (lobby or explicit pause).
     */
    bool publishPausedFlag() {
        return(clockHeld())
    }

    /*
     * Reject play mutations while still in lobby.
     *
     * Purpose: seating/handshake/policy may run before go, but
     * orders, yard builds, design develop, recall, reclaim, and
     * budget changes are gameplay and must wait for operator go.
     * Sets lastOrderError when refusing so PUT /order acks carry
     * a clear reason.
     *
     * Parameters: none.
     *
     * Returns: true when running (caller may proceed); false when
     * still in lobby (caller must abort the verb).
     */
    bool requireGo() {
        if (running) {
            return(true)
        }
        lastOrderError = "still in lobby (operator go required)"
        return(false)
    }

    /*
     * Leave lobby and allow wall / injectable ticks.
     *
     * Purpose: operator console `g` / status-menu Go / harness
     * PUT /admin/go. Idempotent. Does not itself fire a tick.
     * Starts with **whatever seats are already allocated** — does
     * not wait for softMaxPlayers / expected seat count. Later
     * “all humans ready” can call this same path
     * (tryAutoGoAllHumansReady is the stub hook).
     *
     * Parameters: none.
     *
     * Returns: true when this call transitioned lobby→running;
     * false when already running or the game has ended.
     */
    bool go() {
        if (game.ended) {
            return(false)
        }
        if (running) {
            return(false)
        }
        running = true
        republishWithoutTick()
        return(true)
    }

    /*
     * Count seats that have been allocated (in the players list).
     *
     * Purpose: status banner seated vs soft max. Every handshake
     * allocate appends or reuses a slot in game.players — that
     * length is the seated/allocated count.
     *
     * Parameters: none.
     *
     * Returns: game.players.length.
     */
    int64 seatedCount() {
        return(game.players.length)
    }

    /*
     * True when softMaxPlayers allows growing one more seat.
     *
     * Purpose: handshake allocate checks before State.appendSeat.
     * softMaxPlayers 0 means unlimited (practical bound lives in
     * appendSeat). softMaxPlayers N rejects when seatedCount >= N.
     *
     * Parameters: none.
     *
     * Returns: true when a new seat may be appended.
     */
    bool canGrowSeat() {
        if (softMaxPlayers > 0
            and game.players.length >= softMaxPlayers) {
            return(false)
        }
        return(true)
    }

    /*
     * Stub: auto-go when every human seat is ready (v1 unused).
     *
     * Purpose: keep a single go() path for a future “all humans
     * agree” UI. v1 never marks ready and always returns false.
     *
     * Parameters: none.
     *
     * Returns: false (operator go only in v1).
     */
    bool tryAutoGoAllHumansReady() {
        # v1: no per-seat ready flags / UI yet.
        return(false)
    }

    /*
     * Set per-owned-planet allocation % (budget chrome).
     *
     * Purpose: PUT /budget for Planets-tab Scale (DIALOGS §4.2).
     * Production tick multiplies empire-pool credit from this
     * rock by allocationPct/100; no yard logistics tax.
     *
     * Parameters:
     *   playerId — owner seat (must own the rock).
     *   planetId — owned planet id.
     *   allocationPct — 0..100 production spend fraction.
     *
     * Returns: true when stored and republished.
     */
    bool setOwnedBudget(
        int64 playerId, int64 planetId, int64 allocationPct) {
        if (game.ended) {
            return(false)
        }
        if (not requireGo()) {
            return(false)
        }
        if (planetId < 0
            or planetId >= game.galaxy.planets.length) {
            return(false)
        }
        Planet rock = game.galaxy.planets[planetId]
        if (rock.ownerId != playerId) {
            return(false)
        }
        int64 pct = allocationPct
        if (pct < 0) {
            pct = 0
        }
        if (pct > 100) {
            pct = 100
        }
        rock.allocationPct = pct
        game.galaxy.planets[planetId] = rock
        republishWithoutTick()
        return(true)
    }

    /*
     * Post a private or broadcast message from a seat.
     *
     * Purpose: PUT /message compose-to-pick (RULES §13). Private
     * requires a known competitor; broadcast goes to all known.
     *
     * Parameters:
     *   playerId — sending seat.
     *   toPlayerId — private recipient (ignored when broadcast).
     *   text — message body (must be non-empty).
     *   broadcast — true for send-to-all-known.
     *
     * Returns: true when queued in the inbox.
     */
    bool postOwnedMessage(
        int64 playerId,
        int64 toPlayerId,
        String text,
        bool broadcast) {
        if (game.ended) {
            return(false)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            return(false)
        }
        if (text.length < 1) {
            return(false)
        }
        Player seat = game.players[playerId]
        if (broadcast) {
            PlayerMessage note = PlayerMessage(
                playerId, -1, text, true)
            inbox.append(note)
            return(true)
        }
        if (not seat.knowsCompetitor(toPlayerId)) {
            return(false)
        }
        PlayerMessage priv = PlayerMessage(
            playerId, toPlayerId, text, false)
        inbox.append(priv)
        return(true)
    }

    /*
     * Build a seat-scoped digest blob (tick + visible messages).
     *
     * Purpose: GET /digest audience filter — private lines must
     * not leak to other seats (playerId on GetDigestRequest).
     *
     * Parameters:
     *   playerId — requesting seat.
     *
     * Returns: opaque digest bytes (tick events + visible inbox).
     */
    buffer digestForSeat(int64 playerId) {
        list events = []
        int64 index = 0
        while (index < lastEvents.length) {
            events.append(lastEvents[index])
            index = index + 1
        }
        index = 0
        while (index < inbox.length) {
            PlayerMessage note = inbox[index]
            list knownOfSender = []
            if (note.fromId >= 0
                and note.fromId < game.players.length) {
                Player sender = game.players[note.fromId]
                knownOfSender = sender.knownCompetitors
            }
            if (note.visibleTo(playerId, knownOfSender)) {
                String kind = "private"
                int64 toVal = note.toId
                if (note.broadcast) {
                    kind = "broadcast"
                    toVal = 0
                }
                TickEvent ev = TickEvent(
                    kind, -1, -1, note.fromId, toVal)
                ev.text = note.text
                events.append(ev)
            }
            index = index + 1
        }
        return(publisher.encodeDigest(game.tickCount, events))
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
     * still enforced inside State helpers (RULES §5). Optional
     * hulls peels a subset from a multi-hull sitting stack so the
     * remainder can go to other destinations. Validates sitting /
     * dest / hulls before peel so a failed order never orphans a
     * peeled stack. Sets lastOrderError on reject for the ack wire.
     *
     * Parameters:
     *   playerId — requesting seat (must own the fleet).
     *   fleetId — sitting fleet to order (or peel-from).
     *   order — explore / take / trade / move / ambush.
     *   destPlanetId — destination rock.
     *   hulls — subset size; 0 means the whole stack.
     *
     * Returns: true when the order was queued.
     */
    bool issueOwnedOrder(
        int64 playerId,
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls) {
        lastOrderError = ""
        if (game.ended) {
            lastOrderError = "game ended"
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (not requireGo()) {
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        Fleet fleet = game.findFleet(fleetId)
        if (fleet.id < 0) {
            lastOrderError = format(
                "fleet {} does not exist", fleetId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (fleet.ownerId != playerId) {
            lastOrderError = format(
                "fleet {} not owned by player {}", fleetId, playerId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (not fleet.sitting
            or fleet.pendingDeparture
            or fleet.departed
            or fleet.stranded
            or fleet.engagementId >= 0) {
            lastOrderError = format(
                "fleet {} not sitting (locked or in flight)", fleetId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (fleet.hullCount < 1) {
            lastOrderError = format(
                "fleet {} has no hulls", fleetId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (hulls > fleet.hullCount) {
            lastOrderError = format(
                "hulls {} > fleet {} stack {}",
                hulls, fleetId, fleet.hullCount)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        if (destPlanetId < 0
            or destPlanetId >= game.galaxy.planets.length) {
            lastOrderError = format(
                "dest planet {} invalid", destPlanetId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        int64 orderId = game.peelSittingHulls(fleetId, hulls)
        if (orderId < 0) {
            lastOrderError = format(
                "fleet {} peel refused", fleetId)
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, false,
                lastOrderError)
            return(false)
        }
        bool ok = false
        if (order.equals("trade")) {
            # Self-trade stand-in (agreementId -1) for balance loops;
            # multi-partner pact chrome stays Phase E / later B5.
            ok = game.issueTrade(orderId, destPlanetId, -1, -1, 0)
        } else {
            ok = game.issueOrder(orderId, order, destPlanetId)
        }
        if (ok) {
            republishWithoutTick()
            verbose.logOrder(
                playerId, fleetId, order, destPlanetId, hulls, true, "")
            return(true)
        }
        lastOrderError = format(
            "fleet {} order '{}' refused", orderId, order)
        verbose.logOrder(
            playerId, fleetId, order, destPlanetId, hulls, false,
            lastOrderError)
        return(false)
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
        if (not requireGo()) {
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
            verbose.logDesignDevelop(playerId, -1, draft.name)
            return(-1)
        }
        if (not requireGo()) {
            verbose.logDesignDevelop(playerId, -1, draft.name)
            return(-1)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            verbose.logDesignDevelop(playerId, -1, draft.name)
            return(-1)
        }
        int64 id = game.queueDesignDevelop(playerId, draft)
        verbose.logDesignDevelop(playerId, id, draft.name)
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
            verbose.logYardBuild(
                playerId, planetId, designId, false)
            return(false)
        }
        if (not requireGo()) {
            verbose.logYardBuild(
                playerId, planetId, designId, false)
            return(false)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            verbose.logYardBuild(
                playerId, planetId, designId, false)
            return(false)
        }
        bool ok = game.queueYardBuild(playerId, planetId, designId)
        verbose.logYardBuild(playerId, planetId, designId, ok)
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
            verbose.logReclaimHulls(
                playerId, fleetId, hulls, false)
            return(false)
        }
        if (not requireGo()) {
            verbose.logReclaimHulls(
                playerId, fleetId, hulls, false)
            return(false)
        }
        Fleet fleet = game.findFleet(fleetId)
        if (fleet.id < 0 or fleet.ownerId != playerId) {
            verbose.logReclaimHulls(
                playerId, fleetId, hulls, false)
            return(false)
        }
        bool ok = game.queueReclaim(fleetId, hulls)
        verbose.logReclaimHulls(playerId, fleetId, hulls, ok)
        if (ok) {
            republishWithoutTick()
        }
        return(ok)
    }

    /*
     * Pick the first free seat for a new empty-body connect.
     *
     * Purpose: server-side seating — clients cannot know a free
     * seat without being told (RULES §2). Walks allocated seats
     * and returns the first that is not connected, not quit, and
     * has **no** outstanding reconnect token. Token-held dropped
     * seats are reclaimable only with the token (cannot steal).
     * Quit seats stay closed for the live game. When none are
     * free, callers may growSeat() under softMaxPlayers.
     *
     * Parameters: none.
     *
     * Returns: seat id, or -1 when the game ended or every
     * allocated seat is taken / token-held / quit.
     */
    int64 findFreeSeat() {
        if (game.ended) {
            return(-1)
        }
        presence.ensureSeats(game.players.length)
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            if (not seat.quit
                and not presence.isConnected(index)
                and not presence.hasReconnectToken(index)) {
                return(index)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Append a new empire seat under the soft-max ceiling.
     *
     * Purpose: handshake allocate grows seats on demand so a third
     * client is not aborted when softMaxPlayers is 0 / unset
     * (RULES §2). Grows presence and policy tables to match.
     *
     * Parameters: none.
     *
     * Returns: new seat id, or -1 when soft max / practical bound
     * blocks growth or the game has ended.
     */
    int64 growSeat() {
        if (game.ended) {
            return(-1)
        }
        if (not canGrowSeat()) {
            return(-1)
        }
        int64 playerId = game.appendSeat()
        if (playerId < 0) {
            return(-1)
        }
        policies.ensureSeats(game.players.length)
        presence.ensureSeats(game.players.length)
        return(playerId)
    }

    /*
     * Seat a player id: presence + home grant.
     *
     * Purpose: shared path for allocate and keep-alive. Clears
     * drop flags when a free dropped seat is taken again. First
     * successful seat also creates that seat's home planet and
     * starter fleet (RULES §3). Later keep-alives leave the home
     * in place. Drop and quit do not destroy an already-granted
     * home.
     *
     * Parameters:
     *   playerId — empire id already chosen by allocate/keep-alive.
     *
     * Returns: true when presence was recorded and the seat home
     * is granted (or was already granted).
     */
    bool seatConnected(int64 playerId) {
        if (game.ended) {
            return(false)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            return(false)
        }
        Player seat = game.players[playerId]
        if (seat.quit) {
            return(false)
        }
        if (seat.dropped) {
            seat.markReseated()
            game.players[playerId] = seat
        }
        if (not presence.handshake(playerId, clock.now())) {
            return(false)
        }
        if (not game.ensureHomeForSeat(playerId)) {
            return(false)
        }
        republishWithoutTick()
        return(true)
    }

    /*
     * Allocate a human seat (reuse free or grow), mint token, connect.
     *
     * Purpose: PUT /handshake with an empty body (new human
     * connect). Same growth / token rules as handshakeAllocateAs
     * with asAi=false. Seat stays human=true (default).
     *
     * Parameters: none.
     *
     * Returns: assigned seat id, or -1 when soft max is full /
     * growth failed / connect failed.
     */
    int64 handshakeAllocate() {
        return(handshakeAllocateAs(false))
    }

    /*
     * Allocate a seat as human or AI, mint token, connect.
     *
     * Purpose: PUT /handshake empty (human) or 1-byte kind=1 (AI).
     * Prefers a free never-tokened seat among those already
     * allocated; otherwise grows a new seat when softMaxPlayers
     * allows (0 = unlimited). AI seats get markAi() so
     * all-humans-quit ignores them (RULES §2 / §15) — a lone AI
     * in lobby must not end the server on handshake_miss drop.
     * Never steals a token-held dropped seat.
     *
     * Parameters:
     *   asAi — true to mark the seat non-human after connect.
     *
     * Returns: assigned seat id, or -1 when soft max is full /
     * growth failed / connect failed.
     */
    int64 handshakeAllocateAs(bool asAi) {
        int64 playerId = findFreeSeat()
        if (playerId < 0) {
            playerId = growSeat()
        }
        if (playerId < 0) {
            return(-1)
        }
        buffer token = presence.mintToken()
        if (not presence.setReconnectToken(playerId, token)) {
            return(-1)
        }
        if (not seatConnected(playerId)) {
            presence.clearReconnectToken(playerId)
            return(-1)
        }
        if (asAi) {
            game.markPlayerAi(playerId)
            republishWithoutTick()
        }
        return(playerId)
    }

    /*
     * Refresh presence for a seat that is already connected.
     *
     * Purpose: PUT /handshake keep-alive after the client was
     * told its playerId. Body is exactly playerId u32. Does not
     * reclaim a dropped seat (no token → cannot steal); callers
     * must send the opaque token for reclaim.
     *
     * Parameters:
     *   playerId — previously assigned empire id.
     *
     * Returns: playerId when keep-alive succeeded, else -1.
     */
    int64 handshakeKeepAlive(int64 playerId) {
        if (game.ended) {
            return(-1)
        }
        if (playerId < 0 or playerId >= game.players.length) {
            return(-1)
        }
        if (not presence.isConnected(playerId)) {
            return(-1)
        }
        if (not seatConnected(playerId)) {
            return(-1)
        }
        return(playerId)
    }

    /*
     * Reclaim (or keep-alive) a seat by opaque reconnect token.
     *
     * Purpose: PUT /handshake body of TOKEN_BYTES. Restores the
     * same seat after drop; while still connected, refreshes
     * presence. Tokens remain valid until quit or game end
     * (lobby and running). Unknown / wrong-length tokens fail.
     *
     * Parameters:
     *   token — opaque PresenceBook.TOKEN_BYTES from allocate ack.
     *
     * Returns: seat id on success, or -1 on failure.
     */
    int64 handshakeReclaim(buffer token) {
        if (game.ended) {
            return(-1)
        }
        int64 playerId = presence.findSeatByToken(token)
        if (playerId < 0) {
            return(-1)
        }
        Player seat = game.players[playerId]
        if (seat.quit) {
            return(-1)
        }
        if (not seatConnected(playerId)) {
            return(-1)
        }
        return(playerId)
    }

    /*
     * Record a presence handshake for a known seat id.
     *
     * Purpose: in-process unit / fn tests that already chose a
     * seat. Live TCP clients must use handshakeAllocate /
     * handshakeKeepAlive instead of claiming ids.
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when the seat was connected and home granted.
     */
    bool handshake(int64 playerId) {
        return(seatConnected(playerId))
    }

    /*
     * Mark a seat intentionally suspended (AFK) or clear it.
     *
     * Purpose: client menu-open / human AFK flag. While suspended,
     * handshake_miss does not drop the seat; last policy and AFK
     * production shrink still apply (RULES §2 Presence). First
     * successful suspend also grants the seat home like handshake.
     *
     * Parameters:
     *   playerId — empire id.
     *   wantSuspended — true to hold past handshake_miss.
     *
     * Returns: true when presence was updated and the seat home
     * is granted (or was already granted).
     */
    bool setSuspended(int64 playerId, bool wantSuspended) {
        if (game.ended) {
            return(false)
        }
        if (not presence.setSuspended(
            playerId, wantSuspended, clock.now())) {
            return(false)
        }
        if (not game.ensureHomeForSeat(playerId)) {
            return(false)
        }
        republishWithoutTick()
        return(true)
    }

    /*
     * Mark a voluntary quit and maybe refresh end status.
     *
     * Purpose: all-humans-quit ends the **running** game
     * (RULES §2). Lobby suppresses end-status so a quit while
     * seating does not tear down the server before operator go.
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
        presence.clearReconnectToken(playerId)
        refreshEndStatusIfRunning()
        republishWithoutTick()
        return(true)
    }

    /*
     * Apply a drop (lost contact) to a seat.
     *
     * Purpose: handshake miss / TCP close. Last policy continues
     * for the live remainder. While **running**, the reconnect
     * token stays so the same client can reclaim (RULES §2).
     * While still in **lobby**, the token is cleared so the seat
     * is free for a new empty/kind allocate — abandoned lobby
     * seats must not linger as ghost clients when an AI/human
     * process restarts without the in-memory token. Lobby also
     * suppresses end-status so a miss-drop cannot end the server
     * before go.
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
        releaseLobbySeatToken(playerId)
        refreshEndStatusIfRunning()
        republishWithoutTick()
        return(true)
    }

    /*
     * Clear a seat's reconnect token while still in lobby.
     *
     * Purpose: lobby seating is provisional until operator go.
     * A miss-dropped / explicit-drop seat that keeps its token
     * cannot be taken by empty allocate, so a restarted AI or
     * human (process-local token lost) grows a new seat and leaves
     * a ghost. Clearing the token in lobby makes findFreeSeat
     * reuse the slot. After go(), tokens stay on drop for reclaim.
     *
     * Parameters:
     *   playerId — empire id just marked dropped.
     *
     * Returns: nothing.
     */
    void releaseLobbySeatToken(int64 playerId) {
        if (running) {
            return()
        }
        presence.clearReconnectToken(playerId)
    }

    /*
     * Re-run end-game checks only after operator go.
     *
     * Purpose: lobby accepts seats and ages presence, but must
     * never crown eliminate-all or trip all-humans-quit before
     * the session is running. Shared by quit / drop / miss scan.
     *
     * Parameters: none.
     *
     * Returns: nothing; may set game.ended when running.
     */
    void refreshEndStatusIfRunning() {
        if (not running) {
            return()
        }
        game.refreshEndStatus()
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
     * Fire one cadence step if due and not lobby/paused/ended.
     *
     * Purpose: snapshot → tick → persist → publish (PLAN §4.F).
     * Lobby blocks wall **and** injectable cadence until operator
     * / admin go() — presence may still age, but end-status and
     * fireOne stay gated on running.
     *
     * Parameters: none.
     *
     * Returns: true when a tick actually fired.
     */
    bool maybeTick() {
        if (game.ended) {
            return(false)
        }
        # Presence still ages in lobby; cadence fire and end-status
        # wait on go (scanPresenceDrops → refreshEndStatusIfRunning).
        scanPresenceDrops()
        if (game.ended or clockHeld()) {
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
     * Lobby also blocks injectable advance until go() — harness
     * must PUT /admin/go (or call go()) first.
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
        if (not running) {
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
            if (clockHeld()) {
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
     * Purpose: presence maintenance between ticks (and in lobby
     * between accepts). End-status runs only while running so a
     * lobby miss-drop cannot all-humans-quit the server. Lobby
     * also clears reconnect tokens on miss so abandoned seats
     * are free for the next allocate (no ghost clients).
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
            releaseLobbySeatToken(id)
            index = index + 1
        }
        if (droppedIds.length > 0) {
            refreshEndStatusIfRunning()
            if (not running) {
                republishWithoutTick()
            }
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
        applyAfkProductionScales()
        lastEvents = game.tick()
        verbose.logCombatTick(
            game.tickCount, lastEvents, game.engagements)
        publishedState = publisher.encodeState(
            game, policies, publishPausedFlag())
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
     * Apply AFK production shrink for idle connected seats.
     *
     * Purpose: RULES §2 — after afk_timeout_seconds without a
     * policy PUT while still present (handshake alive), scale
     * productive gains by afk_shrink_factor (default 1.0 = no-op
     * placeholder). Dropped seats are not AFK; they keep 1.0.
     *
     * Parameters: none (mutates game.players afkProductionScale).
     *
     * Returns: nothing.
     */
    void applyAfkProductionScales() {
        fp64 period = fp64(game.scenario.tickPeriodSeconds)
        if (period < 1.0) {
            period = 1.0
        }
        fp64 timeout = game.scenario.afkTimeoutSeconds
        fp64 shrink = game.scenario.afkShrinkFactor
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            fp64 scale = 1.0
            if (presence.isConnected(index)
                and not seat.quit
                and not seat.dropped
                and index < policies.slots.length) {
                PolicySlot slot = policies.slots[index]
                fp64 idleSec = fp64(slot.tickUses) * period
                if (timeout >= 0.0 and idleSec >= timeout) {
                    scale = shrink
                }
            }
            seat.afkProductionScale = scale
            game.players[index] = seat
            index = index + 1
        }
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
            game, policies, publishPausedFlag())
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
