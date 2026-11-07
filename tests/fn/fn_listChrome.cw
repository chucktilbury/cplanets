/*
 * tests/fn/fn_listChrome.cw — TUNING B list chrome (in-process).
 *
 * Pause gate, owned issue/recall, chrome trailer decode (pause +
 * progress durations + design catalog), owned design/build queue,
 * explored-track signature flips. No TCP / GTK.
 *
 * Created: 2026-11-06
 * Author: Auto
 *
 * Changelog:
 *   2026-11-06  Initial list-chrome function program.
 *   2026-11-07  Design develop / yard build + catalog decode.
 *   2026-11-07  Budget + known-competitor compose asserts.
 *   2026-11-07  Budget allocationPct spend on production tick.
 */

include "client/exploredTrack.cw"
include "client/publishDecode.cw"
include "lib/state.cw"
include "server/driver.cw"
include "server/policyTable.cw"
include "server/publish.cw"

start {
    bool ok = true

    # --- one-human pause offered; two-human rejected ---
    State solo = State()
    solo.startClosed(17u, 1)
    GameDriver soloDrv = GameDriver(
        solo, true, "", false, 10000u)
    if (ok and not soloDrv.pauseOffered()) {
        ok = false
    }
    if (ok and not soloDrv.setPaused(true)) {
        ok = false
    }
    if (ok and not soloDrv.paused) {
        ok = false
    }
    soloDrv.close()

    State duo = State()
    duo.startClosed(19u, 2)
    GameDriver duoDrv = GameDriver(
        duo, true, "", false, 10000u)
    if (ok and duoDrv.pauseOffered()) {
        ok = false
    }
    if (ok and duoDrv.setPaused(true)) {
        ok = false
    }
    duoDrv.close()

    # --- owned dispatch + recall ---
    State game = State()
    game.startClosed(23u, 1)
    GameDriver drv = GameDriver(
        game, true, "", false, 10000u)
    if (ok and not drv.issueOwnedOrder(0, 1, "explore", 1, 0)) {
        ok = false
    }
    Fleet pending = drv.game.findFleet(1)
    if (ok and not pending.pendingDeparture) {
        ok = false
    }
    if (ok and drv.issueOwnedOrder(0, 1, "take", 1, 0)) {
        # mid-dispatch lock must refuse rewrite
        ok = false
    }
    if (ok and not drv.recallOwnedFleet(0, 1)) {
        ok = false
    }
    Fleet recalled = drv.game.findFleet(1)
    if (ok and not recalled.recallRequested) {
        ok = false
    }
    # Wrong owner rejected.
    if (ok and drv.issueOwnedOrder(9, 1, "explore", 1, 0)) {
        ok = false
    }

    # --- chrome trailer on publish ---
    PublishCodec codec = PublishCodec()
    buffer blob = codec.encodeStateView(
        drv.game, drv.policies, 0, drv.paused)
    PublishDecode decoder = PublishDecode()
    ClientStateView view = decoder.decodeState(blob, 0)
    if (ok and view.humanCount != 1) {
        ok = false
    }
    if (ok and not view.pauseOffered()) {
        ok = false
    }
    if (ok and view.designDevelopTicks < 1) {
        ok = false
    }
    if (ok and view.yardBuildTicks < 1) {
        ok = false
    }
    if (ok and view.designs.length < 1) {
        ok = false
    }
    DesignRow scoutRow = view.findDesign(0)
    if (ok and scoutRow.id != 0) {
        ok = false
    }
    if (ok and not scoutRow.ready) {
        ok = false
    }
    FleetRow row = view.findFleet(1)
    if (ok and row.id != 1) {
        ok = false
    }
    if (ok and not row.orderLocked()) {
        ok = false
    }

    # --- owned design develop + yard build ---
    Player seat = drv.game.players[0]
    seat.wealth = seat.wealth + 10000.0
    seat.resources = seat.resources + 10000.0
    drv.game.players[0] = seat
    Design draft = Design(-1)
    draft.name = "gunboat"
    draft.speed = 1.5
    draft.hopReach = 4.0
    draft.size = 2.0
    draft.cargoHold = 0.0
    int64 did = drv.queueOwnedDesign(0, draft)
    if (ok and did < 0) {
        ok = false
    }
    Design developing = drv.game.designs[did]
    if (ok and developing.developTicksLeft < 1) {
        ok = false
    }
    # Not ready yet — yard build must refuse.
    if (ok and drv.queueOwnedBuild(0, 0, did)) {
        ok = false
    }
    # Ready scout (id 0) can queue at home yard.
    if (ok and not drv.queueOwnedBuild(0, 0, 0)) {
        ok = false
    }
    if (ok and drv.game.builds.length < 1) {
        ok = false
    }
    blob = codec.encodeStateView(
        drv.game, drv.policies, 0, drv.paused)
    view = decoder.decodeState(blob, 0)
    if (ok and view.progressLines.length < 1) {
        ok = false
    }
    DesignRow developingRow = view.findDesign(did)
    if (ok and developingRow.id != did) {
        ok = false
    }
    if (ok and developingRow.developTicksLeft < 1) {
        ok = false
    }
    if (ok and view.wealthMilli < 1) {
        ok = false
    }

    # --- explored track ---
    ExploredTrack track = ExploredTrack()
    PlanetRow home = PlanetRow()
    home.id = 0
    home.visible = true
    home.qualityKnown = true
    home.productive = false
    home.populated = false
    PlanetRow first = track.nextToPresent([home])
    if (ok and first.id != 0) {
        ok = false
    }
    PlanetRow again = track.nextToPresent([home])
    if (ok and again.id >= 0) {
        ok = false
    }
    home.productive = true
    PlanetRow flipped = track.nextToPresent([home])
    if (ok and flipped.id != 0) {
        ok = false
    }

    # --- planet budget → production spend ---
    if (ok and not drv.setOwnedBudget(0, 0, 0)) {
        ok = false
    }
    Planet rock = drv.game.galaxy.planets[0]
    if (ok and rock.allocationPct != 0) {
        ok = false
    }
    Player beforeZero = drv.game.primaryPlayer()
    fp64 wZero = beforeZero.wealth
    drv.game.tick()
    Player afterZero = drv.game.primaryPlayer()
    if (ok and afterZero.wealth != wZero) {
        ok = false
    }
    if (ok and not drv.setOwnedBudget(0, 0, 100)) {
        ok = false
    }
    rock = drv.game.galaxy.planets[0]
    if (ok and rock.allocationPct != 100) {
        ok = false
    }
    Player beforeFull = drv.game.primaryPlayer()
    fp64 wFull = beforeFull.wealth
    drv.game.tick()
    Player afterFull = drv.game.primaryPlayer()
    if (ok and afterFull.wealth <= wFull) {
        ok = false
    }
    if (ok and drv.setOwnedBudget(9, 0, 10)) {
        ok = false
    }
    blob = codec.encodeStateView(
        drv.game, drv.policies, 0, drv.paused)
    view = decoder.decodeState(blob, 0)
    PlanetRow budgetRow = view.findPlanet(0)
    if (ok and budgetRow.allocationPct != 100) {
        ok = false
    }

    # --- known competitors + private compose ---
    Player seat0 = drv.game.players[0]
    seat0.addCompetitor(1)
    drv.game.players[0] = seat0
    if (ok and drv.postOwnedMessage(0, 9, "nope", false)) {
        ok = false
    }
    if (ok and not drv.postOwnedMessage(
        0, 1, "hello", false)) {
        ok = false
    }
    if (ok and not drv.postOwnedMessage(
        0, 0, "all", true)) {
        ok = false
    }
    buffer dig0 = drv.digestForSeat(0)
    ClientStateView digView = ClientStateView(0)
    if (ok and not decoder.decodeDigest(dig0, digView)) {
        ok = false
    }
    if (ok and digView.digest.length < 2) {
        ok = false
    }
    buffer dig1 = drv.digestForSeat(1)
    ClientStateView otherView = ClientStateView(1)
    if (ok and not decoder.decodeDigest(dig1, otherView)) {
        ok = false
    }
    if (ok and otherView.digest.length < 1) {
        ok = false
    }
    buffer dig2 = drv.digestForSeat(2)
    ClientStateView stranger = ClientStateView(2)
    if (ok and not decoder.decodeDigest(dig2, stranger)) {
        ok = false
    }
    if (ok and stranger.digest.length != 0) {
        ok = false
    }
    blob = codec.encodeStateView(
        drv.game, drv.policies, 0, drv.paused)
    view = decoder.decodeState(blob, 0)
    if (ok and view.knownCompetitors.length < 1) {
        ok = false
    }

    drv.close()

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
