/*
 * src/lib/state.cw — game state bootstrap and pure tick entry.
 *
 * Assembles scenario, galaxy, empire pools, designs, fleets, and
 * seeded RNG. Phase C adds tick(); D1 adds engagements for take
 * combat; D2 adds player–player agreements and trade issue
 * helpers; D3 adds issueAmbush and pirate role stickiness —
 * still no TCP/SQLite/scheduler (PLAN §4.B–D / RULES §7).
 * D5 adds contact/end fields and sandbox homes. Homes are created
 * on seat connect (ensureHomeForSeat), not pre-seeded at start.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial closed-game start helpers.
 *   2026-11-05  Phase C: fleets, designs, builds, tick entry,
 *               order helpers (dispatch/recall/sit/move).
 *   2026-11-05  Phase D1: engagements list + take combat wiring.
 *   2026-11-05  Phase D2: agreements + issueTrade helpers.
 *   2026-11-05  Phase D3: issueAmbush + pirate role lock.
 *   2026-11-05  Phase D4: reclaim, design develop, confiscation.
 *   2026-11-05  Phase D5: contact/end + sandbox partition homes.
 *   2026-11-06  startFromScenario for path-loaded setup (TUNING A).
 *   2026-11-07  Build/design costs + default templates from Scenario.
 *   2026-11-07  peelSittingHulls + issueOrderHulls for split
 *               dispatch of a multi-hull sitting stack.
 *   2026-11-08  Defer home yards / starter fleets to seat connect.
 *   2026-11-08  finishStart allows 0 seats; appendSeat grows the
 *               empire list on handshake allocate (live serve).
 *   2026-11-09  Every seated empire gets a starter scout fleet
 *               (RULES §2), not only seat 0.
 *   2026-11-09  seatHardCap from server config (was literal 256).
 *   2026-11-10  CPL-101: unassigned HullStock; develop noop/unique
 *               names; named fleet create + assign; min-speed ETA.
 */



include "agreement.cw"
include "confiscate.cw"
include "design.cw"
include "event.cw"
include "fleet.cw"
include "galaxy.cw"
include "setupParse.cw"
include "shipInventory.cw"
include "tick.cw"
include "travel.cw"

/*
 * State is the published game snapshot.
 *
 * Phase B constructed the start layout. Phase C adds designs,
 * fleets, yard jobs, and a pure tick that mutates this snapshot
 * and returns events.
 */
class State {
    Scenario scenario
    Galaxy galaxy
    list players
    list designs
    list fleets
    list builds
    list reclaims
    # Unassigned hulls staged at a yard planet (CPL-101).
    list stocks
    ShipInventory inventory
    # Last develop/assign/create reject reason for driver acks.
    String lastInventoryError
    list engagements
    list agreements
    list confiscationArms
    SeededRng rng
    Travel travel
    TickDriver driver
    bool locked
    int64 tickCount
    int64 nextFleetId
    int64 nextDesignId
    int64 nextBuildId
    int64 nextReclaimId
    int64 nextEngagementId
    int64 nextAgreementId
    bool ended
    String endReason
    int64 winnerId
    # Absolute seat bound (server config seat_hard_cap). Soft max
    # on GameDriver still rejects earlier when players > 0.
    int64 seatHardCap

    /*
     * Construct an empty state shell.
     *
     * Purpose: allow field-by-field fill from startClosed /
     * startFromText without a partial constructor.
     *
     * Parameters: none.
     *
     * Returns: State with empty collections and unlocked setup.
     */
    State() {
        scenario = Scenario()
        galaxy = Galaxy()
        players = []
        designs = []
        fleets = []
        builds = []
        reclaims = []
        stocks = []
        inventory = ShipInventory()
        lastInventoryError = ""
        engagements = []
        agreements = []
        confiscationArms = []
        rng = SeededRng(1u)
        travel = Travel()
        driver = TickDriver()
        locked = false
        tickCount = 0
        nextFleetId = 1
        nextDesignId = 0
        nextBuildId = 1
        nextReclaimId = 1
        nextEngagementId = 1
        nextAgreementId = 1
        ended = false
        endReason = ""
        winnerId = -1
        seatHardCap = 256
    }

    /*
     * Start a closed-scenario game from the default fixture.
     *
     * Purpose: one-call bootstrap for unit tests and the tick CLI
     * host — galaxy rocks, empire seats/pools, seeded RNG, and
     * default designs. Player homes and starter fleets are not
     * created here; call ensureHomeForSeat (or ensureAllSeatHomes
     * in tests) after a client connects / is seated.
     *
     * Parameters:
     *   seed — PRNG seed (0 remapped inside SeededRng).
     *   playerCount — initial empire seats (>= 0). Live serve
     *     starts at 0 and grows via appendSeat on allocate; unit
     *     fixtures may pre-create N seats.
     *
     * Returns: nothing; fills this State in place.
     */
    void startClosed(uint64 seed, int64 playerCount) {
        scenario = Scenario()
        scenario.clampTickPeriod()
        finishStart(seed, playerCount)
    }

    /*
     * Start a game from application-text setup.
     *
     * Purpose: load named §14 knobs from text, then build galaxy
     * and pools the same way as startClosed.
     *
     * Parameters:
     *   text — setup document body.
     *   seed — PRNG seed.
     *   playerCount — initial empire seats (>= 0); see startClosed.
     *
     * Returns: nothing; fills this State in place.
     */
    void startFromText(
        String text,
        uint64 seed,
        int64 playerCount) {
        SetupParse parser = SetupParse()
        scenario = parser.parseText(text)
        finishStart(seed, playerCount)
    }

    /*
     * Start a game from an already-parsed Scenario snapshot.
     *
     * Purpose: let the server CLI load setup by path, fail loud on
     * unknown keys in the parser, then bootstrap the galaxy without
     * reparsing (TUNING-PLAYABLE workstream A).
     *
     * Parameters:
     *   loaded — Scenario with knobs already overlaid / clamped.
     *   seed — PRNG seed.
     *   playerCount — initial empire seats (>= 0); see startClosed.
     *
     * Returns: nothing; fills this State in place.
     */
    void startFromScenario(
        Scenario loaded,
        uint64 seed,
        int64 playerCount) {
        scenario = loaded
        scenario.clampTickPeriod()
        finishStart(seed, playerCount)
    }

    /*
     * Shared galaxy / pool / design wiring after scenario is set.
     *
     * Purpose: keep startClosed and startFromText aligned on player
     * seats, unowned start galaxy, default designs, and RNG.
     * Homes stay deferred until ensureHomeForSeat / handshake.
     * Live serve passes playerCount 0 and grows seats on allocate.
     *
     * Parameters:
     *   seed — PRNG seed.
     *   playerCount — initial empire seats; values < 0 become 0.
     *
     * Returns: nothing; mutates this State.
     */
    void finishStart(uint64 seed, int64 playerCount) {
        rng = SeededRng(seed)
        locked = false
        tickCount = 0
        players = []
        designs = []
        fleets = []
        builds = []
        reclaims = []
        stocks = []
        lastInventoryError = ""
        engagements = []
        agreements = []
        confiscationArms = []
        nextFleetId = 1
        nextDesignId = 0
        nextBuildId = 1
        nextReclaimId = 1
        nextEngagementId = 1
        nextAgreementId = 1
        ended = false
        endReason = ""
        winnerId = -1
        int64 seats = playerCount
        if (seats < 0) {
            seats = 0
        }
        int64 index = 0
        while (index < seats) {
            Player seat = Player(index)
            seat.applyStartingPools(scenario)
            seat.partitionId = index
            players.append(seat)
            index = index + 1
        }
        galaxy = Galaxy()
        # −1: reserved primary home slot stays unowned until seat 0
        # connects (RULES §2 / §3 connect-time home spawn).
        galaxy.buildFrom(scenario, rng, -1)
        seedDefaultDesigns()
    }

    /*
     * Append one new empire seat with starting pools.
     *
     * Purpose: handshake allocate grows the seat list when no free
     * reclaimable seat exists and soft max still allows growth
     * (RULES §2). Does not grant a home — caller runs
     * ensureHomeForSeat after presence is recorded.
     *
     * Parameters: none.
     *
     * Returns: new seat id (== prior players.length), or -1 when
     * the practical absolute seat bound is already reached.
     */
    int64 appendSeat() {
        if (players.length >= seatHardCap) {
            return(-1)
        }
        int64 id = players.length
        Player seat = Player(id)
        seat.applyStartingPools(scenario)
        seat.partitionId = id
        players.append(seat)
        return(id)
    }

    /*
     * Install default scout and colony designs for empire 0 tests.
     *
     * Purpose: Phase C needs hull templates without a design UI.
     * Scout hop reach follows scenario.scoutRange; colony is
     * shorter so stranded tests can miss a remote hop.
     *
     * Parameters: none.
     *
     * Returns: nothing; appends to designs.
     */
    void seedDefaultDesigns() {
        Design scout = Design(nextDesignId)
        nextDesignId = nextDesignId + 1
        scout.makeScout(
            scenario.scoutRange,
            scenario.designScoutSpeed,
            scenario.designScoutSize)
        designs.append(scout)
        Design colony = Design(nextDesignId)
        nextDesignId = nextDesignId + 1
        colony.makeColony(
            scenario.scoutRange * scenario.colonyHopFraction,
            scenario.designColonySpeed,
            scenario.designColonySize,
            scenario.designColonyHold)
        designs.append(colony)
    }

    /*
     * Create this seat's home yard and starter fleet once.
     *
     * Purpose: RULES lock — homes are not pre-seeded at scenario
     * start. The live server calls this from handshake when a
     * human or AI client connects and is seated. Idempotent: a
     * later handshake / reconnect path does not destroy or
     * duplicate an existing home.
     *
     * Parameters:
     *   playerId — empire seat to seat (>= 0).
     *
     * Returns: true when the seat already had a home or a new home
     * was claimed; false when the seat is invalid or no free rock
     * remains for a sandbox home.
     */
    bool ensureHomeForSeat(int64 playerId) {
        if (playerId < 0 or playerId >= players.length) {
            return(false)
        }
        Player seat = players[playerId]
        if (seat.homeGranted) {
            return(true)
        }
        int64 homeId = -1
        if (playerId == 0) {
            homeId = galaxy.claimPrimaryHome(scenario, 0)
        } else {
            homeId = galaxy.claimSandboxHome(
                scenario, playerId, playerId)
        }
        if (homeId < 0) {
            return(false)
        }
        seat.homeGranted = true
        players[playerId] = seat
        # RULES §2: every seated empire gets the productive yard
        # plus the minimal starter scout stack (not seat-0 only).
        seedStarterFleet(playerId, homeId)
        return(true)
    }

    /*
     * Seat every configured empire with a home (test helper).
     *
     * Purpose: in-process unit/fn programs that never open TCP still
     * need productive yards and starter fleets. Production servers
     * must not call this — they seat via handshake only.
     *
     * Parameters: none.
     *
     * Returns: true when every seat received a home.
     */
    bool ensureAllSeatHomes() {
        bool ok = true
        int64 index = 0
        while (index < players.length) {
            if (not ensureHomeForSeat(index)) {
                ok = false
            }
            index = index + 1
        }
        return(ok)
    }

    /*
     * Park a small scout fleet on a newly granted home yard.
     *
     * Purpose: give every seated empire a dispatch-ready scout
     * stack without waiting on yard production first (RULES §2
     * minimal starter fleet). Called once from ensureHomeForSeat
     * for primary and sandbox seats alike.
     *
     * Parameters:
     *   ownerId — empire that owns the fleet.
     *   homePlanetId — sitting location (the new home yard).
     *
     * Returns: nothing; appends to fleets when designs exist.
     */
    void seedStarterFleet(int64 ownerId, int64 homePlanetId) {
        if (designs.length < 1 or ownerId < 0) {
            return()
        }
        Fleet home = Fleet(
            nextFleetId, ownerId, homePlanetId, 0, 3)
        home.name = "starter"
        nextFleetId = nextFleetId + 1
        fleets.append(home)
    }

    /*
     * Mark setup locked once a game is in progress.
     *
     * Purpose: mirror RULES §14 lock without a server yet.
     *
     * Parameters: none.
     *
     * Returns: nothing; sets locked true.
     */
    void lockSetup() {
        locked = true
    }

    /*
     * Return the first player seat (empire 0).
     *
     * Purpose: unit tests read home-owner pools without indexing
     * through an any-typed list at every call site.
     *
     * Parameters: none.
     *
     * Returns: Player at players[0]; raises if no seats.
     */
    Player primaryPlayer() {
        Player seat = players[0]
        return(seat)
    }

    /*
     * Find a fleet by id.
     *
     * Purpose: order helpers and tests locate fleets without
     * scanning call sites.
     *
     * Parameters:
     *   fleetId — Fleet.id to find.
     *
     * Returns: matching Fleet, or a dummy Fleet(-1,…) if missing.
     */
    Fleet findFleet(int64 fleetId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.id == fleetId) {
                return(fleet)
            }
            index = index + 1
        }
        return(Fleet(-1, -1, -1, -1, 0))
    }

    /*
     * Replace a fleet in the list by id.
     *
     * Purpose: persist mutations from issue/recall helpers.
     *
     * Parameters:
     *   fleet — updated fleet with a matching id.
     *
     * Returns: true when a slot was overwritten.
     */
    bool storeFleet(Fleet fleet) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet cur = fleets[index]
            if (cur.id == fleet.id) {
                fleets[index] = fleet
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Peel hulls from a sitting stack into a new sitting fleet.
     *
     * Purpose: yard builds merge same-design hulls into one sit
     * fleet; dispatch subsets (e.g. 2 of 4 to planet 1) need a
     * peel before issueTravel so the remainder stays parked.
     * hulls <= 0 or hulls >= stack count leaves the original
     * fleet and returns its id (whole-stack dispatch).
     *
     * Parameters:
     *   fleetId — sitting unlocked fleet to peel from.
     *   hulls — hulls for the departing subset (0 = all).
     *
     * Returns: fleet id to order (new or original), or -1 when
     * the peel is refused (missing / locked / not sitting /
     * hulls out of range above the stack).
     */
    int64 peelSittingHulls(int64 fleetId, int64 hulls) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0) {
            return(-1)
        }
        if (not fleet.sitting
            or fleet.pendingDeparture
            or fleet.departed
            or fleet.stranded
            or fleet.engagementId >= 0) {
            return(-1)
        }
        if (fleet.hullCount < 1) {
            return(-1)
        }
        if (hulls <= 0 or hulls >= fleet.hullCount) {
            if (hulls > fleet.hullCount) {
                return(-1)
            }
            return(fleet.id)
        }
        Fleet born = Fleet(
            nextFleetId,
            fleet.ownerId,
            fleet.locationPlanetId,
            fleet.designId,
            hulls)
        nextFleetId = nextFleetId + 1
        fleet.hullCount = fleet.hullCount - hulls
        storeFleet(fleet)
        fleets.append(born)
        return(born.id)
    }

    /*
     * Issue a move/sit travel order for a sitting fleet.
     *
     * Purpose: policy entry for sit/move and explore-style hops
     * before the next tick. Mid-dispatch locked fleets refuse.
     *
     * Parameters:
     *   fleetId — sitting fleet to order.
     *   order — "move", "explore", "take", "trade", or "ambush".
     *   destPlanetId — destination rock.
     *
     * Returns: true when the order was queued as pendingDeparture.
     */
    bool issueOrder(
        int64 fleetId,
        String order,
        int64 destPlanetId) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0) {
            return(false)
        }
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            return(false)
        }
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            return(false)
        }
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (destPlanetId < 0
            or destPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (fleet.hullCount < 1 or fleet.designId < 0) {
            return(false)
        }
        Player seat = players[fleet.ownerId]
        Design design = designs[fleet.designId]
        Design slow = design
        if (fleet.escortDesignId >= 0
            and fleet.escortDesignId < designs.length
            and fleet.escortHullCount > 0) {
            Design escort = designs[fleet.escortDesignId]
            if (escort.speed < slow.speed) {
                slow = escort
            }
        }
        Planet origin = galaxy.planets[fleet.locationPlanetId]
        Planet dest = galaxy.planets[destPlanetId]
        int64 eta = travel.etaTicks(
            scenario,
            seat,
            slow,
            origin,
            dest)
        bool ok = fleet.issueTravel(order, destPlanetId, eta)
        if (ok) {
            storeFleet(fleet)
        }
        return(ok)
    }

    /*
     * Peel optional hulls then issue a travel order.
     *
     * Purpose: one call for split-dispatch from a multi-hull sit
     * stack (Fleets hulls Entry / PUT /order trailing count).
     *
     * Parameters:
     *   fleetId — sitting stack to order or peel-from.
     *   order — "move", "explore", "take", or "ambush".
     *   destPlanetId — destination rock.
     *   hulls — subset size; 0 means the whole stack.
     *
     * Returns: true when peel (if any) and issueOrder succeeded.
     */
    bool issueOrderHulls(
        int64 fleetId,
        String order,
        int64 destPlanetId,
        int64 hulls) {
        int64 orderId = peelSittingHulls(fleetId, hulls)
        if (orderId < 0) {
            return(false)
        }
        return(issueOrder(orderId, order, destPlanetId))
    }

    /*
     * Request recall (cancel if pending, else turn home).
     *
     * Purpose: policy entry for RULES §5.2.
     *
     * Parameters:
     *   fleetId — fleet to recall.
     *
     * Returns: true when a recall request was recorded.
     */
    bool recallFleet(int64 fleetId) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0) {
            return(false)
        }
        bool ok = fleet.requestRecall()
        if (ok) {
            storeFleet(fleet)
        }
        return(ok)
    }

    /*
     * Propose a player–player trade agreement on size S.
     *
     * Purpose: RULES §8.1 — pair plus S; both must still accept.
     * Canonicalizes so playerA < playerB. Does not clip S.
     *
     * Parameters:
     *   playerX — one empire id.
     *   playerY — other empire id.
     *   sizeS — standing cargo size.
     *
     * Returns: new agreement id, or -1 on bad seats / same player.
     */
    int64 proposeAgreement(
        int64 playerX,
        int64 playerY,
        fp64 sizeS) {
        if (playerX < 0 or playerX >= players.length) {
            return(-1)
        }
        if (playerY < 0 or playerY >= players.length) {
            return(-1)
        }
        if (playerX == playerY) {
            return(-1)
        }
        if (sizeS < 0.0) {
            return(-1)
        }
        int64 a = playerX
        int64 b = playerY
        if (b < a) {
            a = playerY
            b = playerX
        }
        Agreement pact = Agreement(nextAgreementId)
        nextAgreementId = nextAgreementId + 1
        pact.playerA = a
        pact.playerB = b
        pact.sizeS = sizeS
        agreements.append(pact)
        return(pact.id)
    }

    /*
     * Accept an agreement for one empire; opens when both accept.
     *
     * Purpose: RULES §8.1 dual acceptance gate.
     *
     * Parameters:
     *   agreementId — pact id from proposeAgreement.
     *   playerId — accepting empire.
     *
     * Returns: true when acceptance was recorded.
     */
    bool acceptAgreement(int64 agreementId, int64 playerId) {
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.id == agreementId) {
                bool ok = pact.accept(playerId)
                agreements[index] = pact
                return(ok)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Close an open (or pending) agreement.
     *
     * Purpose: RULES §8.4 — exchange stops; in-flight finish hops.
     *
     * Parameters:
     *   agreementId — pact to close.
     *
     * Returns: true when a matching pact was closed.
     */
    bool closeAgreement(int64 agreementId) {
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.id == agreementId) {
                pact.close()
                agreements[index] = pact
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Find an agreement by id.
     *
     * Purpose: tests and issueTrade read S / open without scanning.
     *
     * Parameters:
     *   agreementId — Agreement.id.
     *
     * Returns: matching Agreement, or Agreement(-1) if missing.
     */
    Agreement findAgreement(int64 agreementId) {
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.id == agreementId) {
                return(pact)
            }
            index = index + 1
        }
        return(Agreement(-1))
    }

    /*
     * Find a live agreement between two empires.
     *
     * Purpose: issueTrade binds a fleet to the standing S.
     *
     * Parameters:
     *   playerX — one empire.
     *   playerY — other empire.
     *
     * Returns: live Agreement, or Agreement(-1) if none.
     */
    Agreement findLiveAgreement(int64 playerX, int64 playerY) {
        int64 index = 0
        while (index < agreements.length) {
            Agreement pact = agreements[index]
            if (pact.isLive()
                and pact.involves(playerX)
                and pact.involves(playerY)) {
                return(pact)
            }
            index = index + 1
        }
        return(Agreement(-1))
    }

    /*
     * Set an empire's role string.
     *
     * Purpose: D2 role-off-trader break tests and policy entry.
     * Refuses leaving pirate while ambush fleets still wait
     * (RULES §4 role stickiness).
     *
     * Parameters:
     *   playerId — empire seat.
     *   role — "neutral", "trader", "conqueror", "pirate", …
     *
     * Returns: true when the seat was updated.
     */
    bool setRole(int64 playerId, String role) {
        if (playerId < 0 or playerId >= players.length) {
            return(false)
        }
        Player seat = players[playerId]
        if (seat.role.equals("pirate") and not role.equals("pirate")) {
            if (hasAmbushFleets(playerId)) {
                return(false)
            }
        }
        seat.role = role
        players[playerId] = seat
        return(true)
    }

    /*
     * True when the empire still has ambush fleets outstanding.
     *
     * Purpose: pirate role lock while waiting on ambush (§4).
     *
     * Parameters:
     *   playerId — empire id.
     *
     * Returns: true when any fleet is ambushing for that owner.
     */
    bool hasAmbushFleets(int64 playerId) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == playerId
                and fleet.hullCount > 0
                and (fleet.ambushInPosition
                    or fleet.order.equals("ambush"))) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Issue an ambush order at the midpoint of a hop to farPlanet.
     *
     * Purpose: RULES §6 / §10 — only pirate role; ETA is half the
     * full hop (integer division). Edge endpoints stored for
     * midpoint matching.
     *
     * Parameters:
     *   fleetId — sitting pirate fleet.
     *   farPlanetId — far end of the watched A–B trajectory.
     *
     * Returns: true when the ambush order was queued.
     */
    bool issueAmbush(int64 fleetId, int64 farPlanetId) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0) {
            return(false)
        }
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            return(false)
        }
        Player seat = players[fleet.ownerId]
        if (not seat.role.equals("pirate")) {
            return(false)
        }
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            return(false)
        }
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (farPlanetId < 0
            or farPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (farPlanetId == fleet.locationPlanetId) {
            return(false)
        }
        Design design = designs[fleet.designId]
        Planet origin = galaxy.planets[fleet.locationPlanetId]
        Planet dest = galaxy.planets[farPlanetId]
        int64 fullEta = travel.etaTicks(
            scenario,
            seat,
            design,
            origin,
            dest)
        int64 half = fullEta / 2
        bool ok = fleet.issueTravel("ambush", farPlanetId, half)
        if (not ok) {
            return(false)
        }
        fleet.outboundEta = fullEta
        fleet.ambushEdgeA = fleet.locationPlanetId
        fleet.ambushEdgeB = farPlanetId
        fleet.ambushInPosition = false
        fleet.ambushIdleLeft = 0
        storeFleet(fleet)
        return(true)
    }

    /*
     * Issue a trade order bound to an agreement or self-trade.
     *
     * Purpose: fill cargo fields from S, attach optional escorts,
     * and queue pendingDeparture. Holds must cover S at dispatch
     * time (RULES §5.1 / §8). Self-trade uses agreementId -1.
     *
     * Parameters:
     *   fleetId — sitting cargo fleet.
     *   destPlanetId — far rock (own or partner).
     *   agreementId — live pact id, or -1 for self-trade.
     *   escortDesignId — escort template id, or -1.
     *   escortHulls — escort hull count (0 = none).
     *
     * Returns: true when the trade order was queued.
     */
    bool issueTrade(
        int64 fleetId,
        int64 destPlanetId,
        int64 agreementId,
        int64 escortDesignId,
        int64 escortHulls) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0) {
            return(false)
        }
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            return(false)
        }
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            return(false)
        }
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (destPlanetId < 0
            or destPlanetId >= galaxy.planets.length) {
            return(false)
        }
        Design design = designs[fleet.designId]
        fp64 sizeS = 0.0
        if (agreementId >= 0) {
            Agreement pact = findAgreement(agreementId)
            if (pact.id < 0 or not pact.isLive()) {
                return(false)
            }
            if (not pact.involves(fleet.ownerId)) {
                return(false)
            }
            Planet dest = galaxy.planets[destPlanetId]
            if (dest.ownerId < 0
                or not pact.involves(dest.ownerId)) {
                return(false)
            }
            sizeS = pact.sizeS
        } else {
            Planet dest = galaxy.planets[destPlanetId]
            if (dest.ownerId != fleet.ownerId) {
                return(false)
            }
            sizeS = design.holdCapacity(fleet.hullCount)
        }
        if (escortDesignId >= 0) {
            if (escortDesignId >= designs.length or escortHulls < 1) {
                return(false)
            }
        } else {
            escortHulls = 0
        }
        Player seat = players[fleet.ownerId]
        Planet origin = galaxy.planets[fleet.locationPlanetId]
        Planet destRock = galaxy.planets[destPlanetId]
        int64 eta = travel.etaTicks(
            scenario,
            seat,
            design,
            origin,
            destRock)
        bool ok = fleet.issueTravel("trade", destPlanetId, eta)
        if (not ok) {
            return(false)
        }
        fleet.agreementId = agreementId
        fleet.tradeSize = sizeS
        fleet.cargoWealth = sizeS
        fleet.cargoResources = sizeS
        fleet.cargoFilled = false
        fleet.tradeOutbound = true
        fleet.tradeFarPlanetId = destPlanetId
        fleet.escortDesignId = escortDesignId
        fleet.escortHullCount = escortHulls
        storeFleet(fleet)
        return(true)
    }

    /*
     * Queue a yard hull build on a productive shipyard.
     *
     * Purpose: non-instant production (RULES §5.3). Spends a
     * placeholder resource cost from the empire pool.
     *
     * Parameters:
     *   ownerId — empire paying.
     *   planetId — shipyard planet.
     *   designId — ready design to build.
     *
     * Returns: true when the BuildJob was queued.
     */
    bool queueYardBuild(
        int64 ownerId,
        int64 planetId,
        int64 designId) {
        if (ownerId < 0 or ownerId >= players.length) {
            return(false)
        }
        if (planetId < 0 or planetId >= galaxy.planets.length) {
            return(false)
        }
        if (designId < 0 or designId >= designs.length) {
            return(false)
        }
        Planet rock = galaxy.planets[planetId]
        if (not rock.shipyard or rock.ownerId != ownerId) {
            return(false)
        }
        Design design = designs[designId]
        if (not design.isReady()) {
            return(false)
        }
        Player seat = players[ownerId]
        fp64 cost = design.size * scenario.yardBuildCostPerSize
        if (seat.resources < cost) {
            return(false)
        }
        seat.resources = seat.resources - cost
        players[ownerId] = seat
        BuildJob job = BuildJob(
            nextBuildId,
            ownerId,
            planetId,
            designId,
            scenario.yardBuildTicks,
            cost)
        nextBuildId = nextBuildId + 1
        builds.append(job)
        return(true)
    }

    /*
     * Begin developing a new hull design (non-instant).
     *
     * Purpose: designing a type takes designDevelopTicks and mostly
     * wealth (RULES §5.3). Instant design is out. CPL-101: noop
     * (return existing id, no wealth charge) when an open design
     * already matches all type knobs for this seat or a shared
     * system template; reject when the requested name collides
     * with a different open type owned by this seat.
     *
     * Parameters:
     *   ownerId — empire paying development wealth.
     *   draft — design template to append (id rewritten).
     *
     * Returns: design id (new or existing noop), or −1 on failure.
     */
    int64 queueDesignDevelop(int64 ownerId, Design draft) {
        lastInventoryError = ""
        if (ownerId < 0 or ownerId >= players.length) {
            lastInventoryError = "invalid player"
            return(-1)
        }
        int64 index = 0
        while (index < designs.length) {
            Design existing = designs[index]
            if (not existing.closed
                and existing.sameParameters(draft)
                and (existing.ownerId == ownerId
                    or existing.ownerId < 0)) {
                # Develop noop — type-by-parameters already exists.
                return(existing.id)
            }
            index = index + 1
        }
        if (draft.name.length > 0) {
            index = 0
            while (index < designs.length) {
                Design named = designs[index]
                if (not named.closed
                    and named.ownerId == ownerId
                    and named.name.equals(draft.name)
                    and not named.sameParameters(draft)) {
                    lastInventoryError = format(
                        "ship type name '{}' already in use",
                        draft.name)
                    return(-1)
                }
                index = index + 1
            }
        }
        Player seat = players[ownerId]
        fp64 cost = (
            draft.size
            * scenario.designDevelopCostPerSize
            * scenario.designSpeedCostCoeff)
        cost = cost * scenario.designRangeCostCoeff
        if (seat.wealth < cost) {
            lastInventoryError = "insufficient wealth"
            return(-1)
        }
        seat.wealth = seat.wealth - cost
        players[ownerId] = seat
        draft.id = nextDesignId
        draft.ownerId = ownerId
        nextDesignId = nextDesignId + 1
        draft.beginDevelop(scenario.designDevelopTicks)
        designs.append(draft)
        return(draft.id)
    }

    /*
     * Create a named empty sitting fleet at an owned planet.
     *
     * Purpose: CPL-101 fleet create is a separate operation from
     * build and assign. Name must be unique among this seat's
     * fleets.
     *
     * Parameters:
     *   ownerId — empire creating the fleet.
     *   fleetName — unique per-seat label (non-empty).
     *   planetId — owned planet where the empty fleet sits.
     *
     * Returns: new fleet id, or −1 on failure.
     */
    int64 createNamedFleet(
        int64 ownerId, String fleetName, int64 planetId) {
        lastInventoryError = ""
        if (ownerId < 0 or ownerId >= players.length) {
            lastInventoryError = "invalid player"
            return(-1)
        }
        if (fleetName.length < 1) {
            lastInventoryError = "fleet name required"
            return(-1)
        }
        if (planetId < 0 or planetId >= galaxy.planets.length) {
            lastInventoryError = "invalid planet"
            return(-1)
        }
        Planet rock = galaxy.planets[planetId]
        if (rock.ownerId != ownerId) {
            lastInventoryError = "planet not owned"
            return(-1)
        }
        int64 index = 0
        while (index < fleets.length) {
            Fleet other = fleets[index]
            if (other.ownerId == ownerId
                and other.name.equals(fleetName)) {
                lastInventoryError = format(
                    "fleet name '{}' already in use", fleetName)
                return(-1)
            }
            index = index + 1
        }
        Fleet born = Fleet(nextFleetId, ownerId, planetId, -1, 0)
        born.name = fleetName
        nextFleetId = nextFleetId + 1
        fleets.append(born)
        return(born.id)
    }

    /*
     * Assign type name + quantity from unassigned stock into a fleet.
     *
     * Purpose: CPL-101 assign pulls from inventory staged at the
     * fleet's location planet. Over-assign is a hard reject (no
     * silent truncate). Mixed types use primary + escort slots
     * (existing multi-design path).
     *
     * Parameters:
     *   ownerId — empire owning fleet and stock.
     *   fleetId — sitting unlocked fleet at a planet.
     *   typeName — design name to assign.
     *   qty — hulls to move (> 0).
     *
     * Returns: true when assigned; false on reject (see
     * lastInventoryError).
     */
    bool assignHullsToFleet(
        int64 ownerId,
        int64 fleetId,
        String typeName,
        int64 qty) {
        lastInventoryError = ""
        if (ownerId < 0 or ownerId >= players.length) {
            lastInventoryError = "invalid player"
            return(false)
        }
        if (qty <= 0) {
            lastInventoryError = "quantity must be positive"
            return(false)
        }
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0 or fleet.ownerId != ownerId) {
            lastInventoryError = "fleet missing or not owned"
            return(false)
        }
        if (not fleet.sitting
            or fleet.pendingDeparture
            or fleet.departed
            or fleet.stranded
            or fleet.engagementId >= 0) {
            lastInventoryError = "fleet not sitting"
            return(false)
        }
        int64 designId = findOpenDesignByName(ownerId, typeName)
        if (designId < 0) {
            lastInventoryError = format(
                "ship type '{}' not found", typeName)
            return(false)
        }
        Design design = designs[designId]
        if (not design.isReady()) {
            lastInventoryError = "ship type not ready"
            return(false)
        }
        int64 available = inventory.available(
            stocks, ownerId, designId, fleet.locationPlanetId)
        if (qty > available) {
            lastInventoryError = format(
                "over-assign: requested {} but only {} available",
                qty, available)
            return(false)
        }
        if (fleet.hullCount <= 0 or fleet.designId < 0) {
            if (not inventory.debit(
                stocks, ownerId, designId,
                fleet.locationPlanetId, qty)) {
                lastInventoryError = "stock debit failed"
                return(false)
            }
            fleet.designId = designId
            fleet.hullCount = qty
            storeFleet(fleet)
            return(true)
        }
        if (fleet.designId == designId) {
            if (not inventory.debit(
                stocks, ownerId, designId,
                fleet.locationPlanetId, qty)) {
                lastInventoryError = "stock debit failed"
                return(false)
            }
            fleet.hullCount = fleet.hullCount + qty
            storeFleet(fleet)
            return(true)
        }
        if (fleet.escortDesignId < 0 or fleet.escortHullCount <= 0) {
            if (not inventory.debit(
                stocks, ownerId, designId,
                fleet.locationPlanetId, qty)) {
                lastInventoryError = "stock debit failed"
                return(false)
            }
            fleet.escortDesignId = designId
            fleet.escortHullCount = qty
            storeFleet(fleet)
            return(true)
        }
        if (fleet.escortDesignId == designId) {
            if (not inventory.debit(
                stocks, ownerId, designId,
                fleet.locationPlanetId, qty)) {
                lastInventoryError = "stock debit failed"
                return(false)
            }
            fleet.escortHullCount = fleet.escortHullCount + qty
            storeFleet(fleet)
            return(true)
        }
        lastInventoryError = (
            "fleet already has two ship types; create another fleet")
        return(false)
    }

    /*
     * Find an open design by name usable by a seat.
     *
     * Purpose: assign-by-type-name resolves player-owned designs
     * first, then shared system templates with the same name.
     *
     * Parameters:
     *   ownerId — requesting seat.
     *   typeName — design name.
     *
     * Returns: design id, or −1 when not found / closed.
     */
    int64 findOpenDesignByName(int64 ownerId, String typeName) {
        int64 index = 0
        while (index < designs.length) {
            Design design = designs[index]
            if (not design.closed
                and design.ownerId == ownerId
                and design.name.equals(typeName)) {
                return(design.id)
            }
            index = index + 1
        }
        index = 0
        while (index < designs.length) {
            Design design = designs[index]
            if (not design.closed
                and design.ownerId < 0
                and design.name.equals(typeName)) {
                return(design.id)
            }
            index = index + 1
        }
        return(-1)
    }

    /*
     * Close a design and free its name when no hulls remain.
     *
     * Purpose: CPL-101 — when all hulls of a type are reclaimed
     * (stock + fleets + pending builds/reclaims = 0), close the
     * design so the name may be reused.
     *
     * Parameters:
     *   designId — design to consider freeing.
     *
     * Returns: true when the design was closed.
     */
    bool maybeFreeDesign(int64 designId) {
        if (designId < 0 or designId >= designs.length) {
            return(false)
        }
        Design design = designs[designId]
        if (design.closed) {
            return(false)
        }
        int64 ownerId = design.ownerId
        if (ownerId < 0) {
            # Shared system templates stay open.
            return(false)
        }
        if (inventory.totalForDesign(stocks, ownerId, designId) > 0) {
            return(false)
        }
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.ownerId == ownerId) {
                if (fleet.designId == designId
                    and fleet.hullCount > 0) {
                    return(false)
                }
                if (fleet.escortDesignId == designId
                    and fleet.escortHullCount > 0) {
                    return(false)
                }
            }
            index = index + 1
        }
        index = 0
        while (index < builds.length) {
            BuildJob job = builds[index]
            if (job.ownerId == ownerId and job.designId == designId) {
                return(false)
            }
            index = index + 1
        }
        index = 0
        while (index < reclaims.length) {
            ReclaimJob job = reclaims[index]
            if (job.ownerId == ownerId and job.designId == designId) {
                return(false)
            }
            index = index + 1
        }
        design.closed = true
        designs[designId] = design
        return(true)
    }

    /*
     * Queue reclaim of unassigned stock at a shipyard planet.
     *
     * Purpose: Ships inventory reclaim path for staged hulls
     * (RULES §5.2 / CPL-101). Hard-rejects over-reclaim.
     *
     * Parameters:
     *   ownerId — empire owning the stock.
     *   planetId — owned shipyard planet.
     *   designId — type to reclaim.
     *   hulls — count to reclaim (> 0).
     *
     * Returns: true when a ReclaimJob was queued.
     */
    bool queueReclaimStock(
        int64 ownerId,
        int64 planetId,
        int64 designId,
        int64 hulls) {
        lastInventoryError = ""
        if (ownerId < 0 or ownerId >= players.length) {
            lastInventoryError = "invalid player"
            return(false)
        }
        if (hulls <= 0) {
            lastInventoryError = "quantity must be positive"
            return(false)
        }
        if (planetId < 0 or planetId >= galaxy.planets.length) {
            lastInventoryError = "invalid planet"
            return(false)
        }
        if (designId < 0 or designId >= designs.length) {
            lastInventoryError = "invalid design"
            return(false)
        }
        Planet rock = galaxy.planets[planetId]
        if (not rock.shipyard or rock.ownerId != ownerId) {
            lastInventoryError = "not an owned shipyard"
            return(false)
        }
        int64 available = inventory.available(
            stocks, ownerId, designId, planetId)
        if (hulls > available) {
            lastInventoryError = format(
                "over-reclaim: requested {} but only {} available",
                hulls, available)
            return(false)
        }
        Design design = designs[designId]
        fp64 basis = (
            design.size
            * scenario.yardBuildCostPerSize
            * fp64(hulls))
        if (not inventory.debit(
            stocks, ownerId, designId, planetId, hulls)) {
            lastInventoryError = "stock debit failed"
            return(false)
        }
        ReclaimJob job = ReclaimJob(
            nextReclaimId,
            ownerId,
            planetId,
            designId,
            hulls,
            scenario.yardBuildTicks,
            basis)
        nextReclaimId = nextReclaimId + 1
        reclaims.append(job)
        return(true)
    }

    /*
     * Queue reclaim of sitting hulls at a shipyard planet.
     *
     * Purpose: reclaim only at a yard; takes yardBuildTicks; returns
     * reclaimPercent of production resources (RULES §5.2).
     *
     * Parameters:
     *   fleetId — sitting fleet at a yard.
     *   hulls — how many hulls to reclaim (<= fleet.hullCount).
     *
     * Returns: true when a ReclaimJob was queued.
     */
    bool queueReclaim(int64 fleetId, int64 hulls) {
        Fleet fleet = findFleet(fleetId)
        if (fleet.id < 0 or hulls <= 0) {
            return(false)
        }
        if (not fleet.sitting
            or fleet.pendingDeparture
            or fleet.departed
            or fleet.engagementId >= 0) {
            return(false)
        }
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= galaxy.planets.length) {
            return(false)
        }
        if (fleet.designId < 0 or fleet.designId >= designs.length) {
            return(false)
        }
        Planet rock = galaxy.planets[fleet.locationPlanetId]
        if (not rock.shipyard or rock.ownerId != fleet.ownerId) {
            return(false)
        }
        if (hulls > fleet.hullCount) {
            lastInventoryError = format(
                "over-reclaim: requested {} but fleet has {}",
                hulls, fleet.hullCount)
            return(false)
        }
        Design design = designs[fleet.designId]
        fp64 basis = (
            design.size
            * scenario.yardBuildCostPerSize
            * fp64(hulls))
        ReclaimJob job = ReclaimJob(
            nextReclaimId,
            fleet.ownerId,
            rock.id,
            fleet.designId,
            hulls,
            scenario.yardBuildTicks,
            basis)
        nextReclaimId = nextReclaimId + 1
        fleet.hullCount = fleet.hullCount - hulls
        storeFleet(fleet)
        reclaims.append(job)
        return(true)
    }

    /*
     * Mark a human seat as voluntarily quit.
     *
     * Purpose: all-humans-quit end (RULES §2 / §15). No rejoin in v1.
     * Re-checks end immediately so the server need not wait a tick.
     *
     * Parameters:
     *   playerId — seat to mark.
     *
     * Returns: true when the seat was updated.
     */
    bool quitPlayer(int64 playerId) {
        if (playerId < 0 or playerId >= players.length) {
            return(false)
        }
        Player seat = players[playerId]
        seat.markQuit()
        players[playerId] = seat
        refreshEndStatus()
        return(true)
    }

    /*
     * Mark a human seat as dropped (zombie last-policy).
     *
     * Purpose: lost contact while the live game continues; zombie
     * falls to normal play (RULES §2 / §15). If this was the last
     * human, the game ends (no AI-only zombie match).
     *
     * Parameters:
     *   playerId — seat to mark.
     *
     * Returns: true when the seat was updated.
     */
    bool dropPlayer(int64 playerId) {
        if (playerId < 0 or playerId >= players.length) {
            return(false)
        }
        Player seat = players[playerId]
        seat.markDrop()
        players[playerId] = seat
        refreshEndStatus()
        return(true)
    }

    /*
     * Mark a seat as AI (not human).
     *
     * Purpose: all-humans-quit ignores AI clients.
     *
     * Parameters:
     *   playerId — seat to mark.
     *
     * Returns: true when updated.
     */
    bool markPlayerAi(int64 playerId) {
        if (playerId < 0 or playerId >= players.length) {
            return(false)
        }
        Player seat = players[playerId]
        seat.markAi()
        players[playerId] = seat
        return(true)
    }

    /*
     * Re-run end-game checks without advancing the galaxy.
     *
     * Purpose: quit/drop can end the live instance between ticks.
     *
     * Parameters: none.
     *
     * Returns: nothing; may set ended / endReason / winnerId.
     */
    void refreshEndStatus() {
        if (ended) {
            return()
        }
        list events = []
        EndGame check = EndGame()
        check.run(
            scenario,
            galaxy.planets,
            players,
            events,
            ended)
        if (check.endedOut) {
            ended = true
            endReason = check.endReasonOut
            winnerId = check.winnerIdOut
        }
    }

    /*
     * Run one pure tick; return the event list.
     *
     * Purpose: lib-only step for tests and cplanets-tick (PLAN §1).
     * Locks setup on first tick. Skips advance when already ended.
     *
     * Parameters: none (mutates this State).
     *
     * Returns: list of TickEvent from this step.
     */
    list tick() {
        lockSetup()
        list events = []
        if (ended) {
            return(events)
        }
        driver.run(
            scenario,
            galaxy.planets,
            players,
            designs,
            builds,
            reclaims,
            stocks,
            fleets,
            engagements,
            agreements,
            confiscationArms,
            events,
            rng,
            nextFleetId,
            nextEngagementId,
            ended)
        nextFleetId = driver.nextFleetIdOut
        nextEngagementId = driver.nextEngagementIdOut
        if (driver.endedOut) {
            ended = true
            endReason = driver.endReasonOut
            winnerId = driver.winnerIdOut
        }
        # Free player type names when reclaim drained the last hulls.
        int64 designIndex = 0
        while (designIndex < designs.length) {
            maybeFreeDesign(designIndex)
            designIndex = designIndex + 1
        }
        tickCount = tickCount + 1
        return(events)
    }

    /*
     * Count open engagements.
     *
     * Purpose: fn tests assert productive takes never free-occupy.
     *
     * Parameters: none.
     *
     * Returns: number of engagements with open == true.
     */
    int64 countOpenEngagements() {
        int64 found = 0
        int64 index = 0
        while (index < engagements.length) {
            Engagement fight = engagements[index]
            if (fight.open) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }
}
