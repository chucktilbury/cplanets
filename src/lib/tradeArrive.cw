/*
 * src/lib/tradeArrive.cw — trade cycle on node arrivals (Phase D2).
 *
 * RULES §7.6 / §8: cargo full both ways; escorts return with the
 * freighters; sender-only loading already paid on leave; far-side
 * exchange + return bounce; sender return profit; re-cycle until
 * recall, closed agreement, or role-off-trader. Self-trade is
 * cost-only (no two-party bump).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial trade arrival / cycle for Phase D2.
 */

include "agreement.cw"
include "design.cw"
include "event.cw"
include "fleet.cw"
include "planet.cw"
include "player.cw"
include "scenario.cw"
include "travel.cw"

/*
 * TradeArrive resolves arriving trade orders into exchange,
 * return bounce, profit, and optional re-dispatch.
 *
 * Runs after Motion.arrivals and before Take so pendingArrivalOrder
 * still names "trade". Clears that flag for trade fleets only.
 */
class TradeArrive {
    Travel travel

    /*
     * Construct a trade-arrival phase with Travel for return ETA.
     *
     * Purpose: bounce legs need the same ETA/teleport math as
     * issue-order.
     *
     * Parameters: none.
     *
     * Returns: TradeArrive ready for processArrivals.
     */
    TradeArrive() {
        travel = Travel()
    }

    /*
     * Handle every fleet that arrived with a trade order.
     *
     * Purpose: RULES §8 cycle — far exchange or fail, return
     * bounce, sender profit, re-cycle when the pact is still live.
     *
     * Parameters:
     *   scenario — tradeBump and teleport knobs.
     *   planets — mutable galaxy.
     *   players — empire pools (wealth/resources/role).
     *   designs — hull templates.
     *   fleets — mutable fleet list.
     *   agreements — player–player pacts.
     *   events — tick event log.
     *
     * Returns: nothing; mutates fleets/players.
     */
    void processArrivals(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events) {
        int64 index = 0
        while (index < fleets.length) {
            Fleet fleet = fleets[index]
            if (fleet.pendingArrivalOrder.equals("trade")) {
                resolveTradeArrival(
                    scenario,
                    planets,
                    players,
                    designs,
                    fleets,
                    agreements,
                    events,
                    index)
            }
            index = index + 1
        }
    }

    /*
     * Resolve one arriving trade fleet at its location.
     *
     * Purpose: outbound vs return legs differ (exchange vs profit
     * / re-cycle). Clears pendingArrivalOrder for this fleet.
     *
     * Parameters:
     *   scenario — knobs.
     *   planets — galaxy.
     *   players — seats.
     *   designs — templates.
     *   fleets — mutable list.
     *   agreements — pacts.
     *   events — log.
     *   index — fleet index.
     *
     * Returns: nothing.
     */
    void resolveTradeArrival(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        fleet.pendingArrivalOrder = ""
        fleets[index] = fleet
        if (fleet.tradeOutbound) {
            handleOutboundArrival(
                scenario,
                planets,
                players,
                designs,
                fleets,
                agreements,
                events,
                index)
        } else {
            handleReturnArrival(
                scenario,
                planets,
                players,
                designs,
                fleets,
                agreements,
                events,
                index)
        }
    }

    /*
     * Find an agreement by id.
     *
     * Purpose: resolve live S / open flag for a fleet's pact.
     *
     * Parameters:
     *   agreements — pact list.
     *   agreementId — Agreement.id.
     *
     * Returns: matching Agreement, or Agreement(-1) if missing.
     */
    Agreement findAgreement(list agreements, int64 agreementId) {
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
     * True when two-party exchange / cycle is still allowed.
     *
     * Purpose: closed agreement or sender role-off-trader breaks
     * (RULES §8.4). Self-trade (no pact) is never "live".
     *
     * Parameters:
     *   fleet — arriving trade fleet.
     *   players — seats (sender role).
     *   agreements — pacts.
     *
     * Returns: true when pact is live and sender role is trader.
     */
    bool exchangeAllowed(
        Fleet fleet,
        list players,
        list agreements) {
        if (fleet.agreementId < 0) {
            return(false)
        }
        Agreement pact = findAgreement(agreements, fleet.agreementId)
        if (pact.id < 0 or not pact.isLive()) {
            return(false)
        }
        if (fleet.ownerId < 0 or fleet.ownerId >= players.length) {
            return(false)
        }
        Player seat = players[fleet.ownerId]
        if (not seat.role.equals("trader")) {
            return(false)
        }
        return(true)
    }

    /*
     * True when the destination rock is owned by the sender.
     *
     * Purpose: self-trade is cost-only (RULES §8.3).
     *
     * Parameters:
     *   fleet — trade fleet.
     *   planets — galaxy.
     *
     * Returns: true when location owner equals fleet.ownerId.
     */
    bool isSelfTrade(Fleet fleet, list planets) {
        if (fleet.locationPlanetId < 0
            or fleet.locationPlanetId >= planets.length) {
            return(false)
        }
        Planet rock = planets[fleet.locationPlanetId]
        return(rock.ownerId == fleet.ownerId)
    }

    /*
     * Receiver inbound wealth bump (smaller than sender return).
     *
     * Purpose: RULES §8.2 — inbound bump is half the return profit
     * magnitude for the same S and tradeBump.
     *
     * Parameters:
     *   scenario — tradeBump.
     *   sizeS — standing cargo size.
     *
     * Returns: wealth added to the receiver on successful exchange.
     */
    fp64 inboundBump(Scenario scenario, fp64 sizeS) {
        fp64 full = sizeS * (scenario.tradeBump - 1.0)
        return(full * 0.5)
    }

    /*
     * Sender return wealth profit (trade bump).
     *
     * Purpose: RULES §8.2 — wealth-only return profit when filled.
     *
     * Parameters:
     *   scenario — tradeBump.
     *   sizeS — standing cargo size.
     *
     * Returns: wealth added to the sender on filled return.
     */
    fp64 returnProfit(Scenario scenario, fp64 sizeS) {
        return(sizeS * (scenario.tradeBump - 1.0))
    }

    /*
     * Attempt far-side exchange; always bounce home afterward.
     *
     * Purpose: cover-S check, inbound bump, cargoFilled flag, then
     * free return leg with escorts (RULES §8.2). Self-trade and
     * broken pacts skip exchange but still bounce.
     *
     * Parameters:
     *   scenario — knobs.
     *   planets — galaxy.
     *   players — seats.
     *   designs — templates.
     *   fleets — mutable list.
     *   agreements — pacts.
     *   events — log.
     *   index — fleet index.
     *
     * Returns: nothing.
     */
    void handleOutboundArrival(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        bool self = isSelfTrade(fleet, planets)
        bool live = exchangeAllowed(fleet, players, agreements)
        fleet.cargoFilled = false
        if (not self and live) {
            Planet rock = planets[fleet.locationPlanetId]
            if (rock.ownerId >= 0 and rock.ownerId < players.length) {
                Player recv = players[rock.ownerId]
                if (recv.wealth >= fleet.tradeSize
                    and recv.resources >= fleet.tradeSize) {
                    fp64 bump = inboundBump(scenario, fleet.tradeSize)
                    recv.wealth = recv.wealth + bump
                    players[rock.ownerId] = recv
                    fleet.cargoFilled = true
                    events.append(
                        TickEvent(
                            "trade_exchange",
                            fleet.id,
                            rock.id,
                            rock.ownerId,
                            int64(fleet.tradeSize)))
                } else {
                    events.append(
                        TickEvent(
                            "trade_nodeal",
                            fleet.id,
                            rock.id,
                            rock.ownerId,
                            0))
                }
            }
        } else (self) {
            events.append(
                TickEvent(
                    "trade_self",
                    fleet.id,
                    fleet.locationPlanetId,
                    fleet.ownerId,
                    0))
        } else {
            events.append(
                TickEvent(
                    "trade_break",
                    fleet.id,
                    fleet.locationPlanetId,
                    fleet.ownerId,
                    0))
        }
        fleets[index] = fleet
        startReturnLeg(
            scenario,
            planets,
            players,
            designs,
            fleets,
            events,
            index)
    }

    /*
     * Begin the free return leg toward the original sender.
     *
     * Purpose: escorts and cargo turn around together without a
     * new dispatch/loading charge (RULES §8.2).
     *
     * Parameters:
     *   scenario — teleport mapping.
     *   planets — galaxy.
     *   players — technology for ETA.
     *   designs — cargo design for speed.
     *   fleets — mutable list.
     *   events — log.
     *   index — fleet index.
     *
     * Returns: nothing.
     */
    void startReturnLeg(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        if (fleet.senderPlanetId < 0
            or fleet.senderPlanetId >= planets.length
            or fleet.ownerId < 0
            or fleet.ownerId >= players.length
            or fleet.designId < 0
            or fleet.designId >= designs.length) {
            fleet.becomeSitting()
            fleets[index] = fleet
            return()
        }
        Player seat = players[fleet.ownerId]
        Design design = designs[fleet.designId]
        Planet here = planets[fleet.locationPlanetId]
        Planet home = planets[fleet.senderPlanetId]
        int64 eta = travel.etaTicks(
            scenario,
            seat,
            design,
            here,
            home)
        fleet.tradeOutbound = false
        fleet.destPlanetId = fleet.senderPlanetId
        fleet.eta = eta
        fleet.outboundEta = eta
        fleet.ticksTraveled = 0
        fleet.order = "trade"
        fleet.pendingDeparture = false
        fleet.departed = true
        fleet.sitting = false
        fleet.recallRequested = false
        fleets[index] = fleet
        events.append(
            TickEvent(
                "trade_bounce",
                fleet.id,
                fleet.senderPlanetId,
                fleet.ownerId,
                eta))
    }

    /*
     * Apply return profit and optionally re-queue the next cycle.
     *
     * Purpose: filled return pays tradeBump wealth; live pacts
     * re-depart (pay dispatch/loading again) with escorts still
     * attached (RULES §8.2 / §8.4).
     *
     * Parameters:
     *   scenario — knobs.
     *   planets — galaxy.
     *   players — seats.
     *   designs — unused (kept for call symmetry).
     *   fleets — mutable list.
     *   agreements — pacts.
     *   events — log.
     *   index — fleet index.
     *
     * Returns: nothing.
     */
    void handleReturnArrival(
        Scenario scenario,
        list planets,
        list players,
        list designs,
        list fleets,
        list agreements,
        list events,
        int64 index) {
        Fleet fleet = fleets[index]
        bool self = false
        if (fleet.tradeFarPlanetId >= 0
            and fleet.tradeFarPlanetId < planets.length) {
            Planet far = planets[fleet.tradeFarPlanetId]
            self = far.ownerId == fleet.ownerId
        }
        bool live = exchangeAllowed(fleet, players, agreements)
        if (fleet.cargoFilled and not self and live) {
            if (fleet.ownerId >= 0 and fleet.ownerId < players.length) {
                Player seat = players[fleet.ownerId]
                fp64 profit = returnProfit(scenario, fleet.tradeSize)
                seat.wealth = seat.wealth + profit
                players[fleet.ownerId] = seat
                events.append(
                    TickEvent(
                        "trade_profit",
                        fleet.id,
                        fleet.locationPlanetId,
                        fleet.ownerId,
                        int64(fleet.tradeSize)))
            }
        } else (not fleet.cargoFilled and not self) {
            events.append(
                TickEvent(
                    "trade_empty",
                    fleet.id,
                    fleet.locationPlanetId,
                    fleet.ownerId,
                    0))
        }
        if (live and not self and fleet.tradeFarPlanetId >= 0) {
            fleet.tradeOutbound = true
            fleet.cargoFilled = false
            fleet.cargoWealth = fleet.tradeSize
            fleet.cargoResources = fleet.tradeSize
            fleet.destPlanetId = fleet.tradeFarPlanetId
            fleet.senderPlanetId = fleet.locationPlanetId
            fleet.order = "trade"
            fleet.pendingDeparture = true
            fleet.departed = false
            fleet.sitting = true
            fleet.eta = 0
            fleet.outboundEta = 0
            fleet.ticksTraveled = 0
            fleets[index] = fleet
            events.append(
                TickEvent(
                    "trade_recycle",
                    fleet.id,
                    fleet.tradeFarPlanetId,
                    fleet.ownerId,
                    0))
        } else {
            fleet.tradeOutbound = true
            fleet.cargoFilled = false
            fleet.cargoWealth = 0.0
            fleet.cargoResources = 0.0
            fleet.becomeSitting()
            fleets[index] = fleet
            events.append(
                TickEvent(
                    "trade_stop",
                    fleet.id,
                    fleet.locationPlanetId,
                    fleet.ownerId,
                    0))
        }
    }
}
