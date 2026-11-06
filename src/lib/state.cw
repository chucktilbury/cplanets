/*
 * src/lib/state.cw — game state bootstrap and pure tick entry.
 *
 * Assembles scenario, galaxy, empire pools, designs, fleets, and
 * seeded RNG. Phase C adds tick(); D1 adds engagements for take
 * combat — still no TCP/SQLite/scheduler (PLAN §4.B–D / RULES §7).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial closed-game start helpers.
 *   2026-11-05  Phase C: fleets, designs, builds, tick entry,
 *               order helpers (dispatch/recall/sit/move).
 *   2026-11-05  Phase D1: engagements list + take combat wiring.
 */

include "design.cw"
include "event.cw"
include "fleet.cw"
include "galaxy.cw"
include "setupParse.cw"
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
    list engagements
    SeededRng rng
    Travel travel
    TickDriver driver
    bool locked
    int64 tickCount
    int64 nextFleetId
    int64 nextDesignId
    int64 nextBuildId
    int64 nextEngagementId

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
        engagements = []
        rng = SeededRng(1u)
        travel = Travel()
        driver = TickDriver()
        locked = false
        tickCount = 0
        nextFleetId = 1
        nextDesignId = 0
        nextBuildId = 1
        nextEngagementId = 1
    }

    /*
     * Start a closed-scenario game from the default fixture.
     *
     * Purpose: one-call bootstrap for unit tests and the tick CLI
     * host — home yard, scout rocks, empire pools, seeded RNG,
     * default designs and a home scout fleet.
     *
     * Parameters:
     *   seed — PRNG seed (0 remapped inside SeededRng).
     *   playerCount — number of empire seats (>= 1).
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
     *   playerCount — number of empire seats (>= 1).
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
     * Shared galaxy / pool / design wiring after scenario is set.
     *
     * Purpose: keep startClosed and startFromText aligned on player
     * seats, home ownership, default designs, and RNG.
     *
     * Parameters:
     *   seed — PRNG seed.
     *   playerCount — empire seats; values < 1 become 1.
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
        engagements = []
        nextFleetId = 1
        nextDesignId = 0
        nextBuildId = 1
        nextEngagementId = 1
        int64 seats = playerCount
        if (seats < 1) {
            seats = 1
        }
        int64 index = 0
        while (index < seats) {
            Player seat = Player(index)
            seat.applyStartingPools(scenario)
            players.append(seat)
            index = index + 1
        }
        galaxy = Galaxy()
        galaxy.buildFrom(scenario, rng, 0)
        seedDefaultDesigns()
        seedHomeFleet()
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
        scout.makeScout(scenario.scoutRange)
        designs.append(scout)
        Design colony = Design(nextDesignId)
        nextDesignId = nextDesignId + 1
        colony.makeColony(scenario.scoutRange * 0.5)
        designs.append(colony)
    }

    /*
     * Park a small scout fleet on the home yard.
     *
     * Purpose: give dispatch/recall/move tests a starting stock
     * without yard production first.
     *
     * Parameters: none.
     *
     * Returns: nothing; appends to fleets.
     */
    void seedHomeFleet() {
        if (designs.length < 1 or players.length < 1) {
            return()
        }
        Fleet home = Fleet(nextFleetId, 0, 0, 0, 3)
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
        Player seat = players[fleet.ownerId]
        Design design = designs[fleet.designId]
        Planet origin = galaxy.planets[fleet.locationPlanetId]
        Planet dest = galaxy.planets[destPlanetId]
        int64 eta = travel.etaTicks(
            scenario,
            seat,
            design,
            origin,
            dest)
        bool ok = fleet.issueTravel(order, destPlanetId, eta)
        if (ok) {
            storeFleet(fleet)
        }
        return(ok)
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
        fp64 cost = design.size * 10.0
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
     * Run one pure tick; return the event list.
     *
     * Purpose: lib-only step for tests and cplanets-tick (PLAN §1).
     * Locks setup on first tick.
     *
     * Parameters: none (mutates this State).
     *
     * Returns: list of TickEvent from this step.
     */
    list tick() {
        lockSetup()
        list events = []
        driver.run(
            scenario,
            galaxy.planets,
            players,
            designs,
            builds,
            fleets,
            engagements,
            events,
            nextFleetId,
            nextEngagementId)
        nextFleetId = driver.nextFleetIdOut
        nextEngagementId = driver.nextEngagementIdOut
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
