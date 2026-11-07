/*
 * tests/unit/unit_mapMath.cw — map transform / hop / pick (I).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial Phase I map math unit.
 */

include "client/fleetRow.cw"
include "client/mapMath.cw"
include "client/planetRow.cw"

start {
    bool ok = true
    MapMath math = MapMath()
    fp64 sx = math.worldToScreenX(0.0, 200.0, 0.0, 1.0)
    if (ok and sx != 100.0) {
        ok = false
    }
    fp64 wx = math.screenToWorldX(100.0, 200.0, 0.0, 1.0)
    if (ok and wx != 0.0) {
        ok = false
    }
    PlanetRow own = PlanetRow()
    own.id = 0
    own.visible = true
    own.ownerId = 0
    own.productive = true
    own.x = 0.0
    own.y = 0.0
    if (ok and math.statusG(own, 0) < 0.5) {
        ok = false
    }
    PlanetRow enemy = PlanetRow()
    enemy.id = 2
    enemy.visible = true
    enemy.ownerId = 1
    enemy.x = 5.0
    enemy.y = 0.0
    if (ok and math.statusR(enemy, 0) < 0.5) {
        ok = false
    }
    list planets = []
    planets.append(own)
    planets.append(enemy)
    int64 hit = math.pickPlanet(
        planets, 100.0, 100.0, 200.0, 200.0, 0.0, 0.0, 1.0)
    if (ok and hit != 0) {
        ok = false
    }
    FleetRow fleet = FleetRow()
    fleet.departed = true
    fleet.locationPlanetId = 0
    fleet.destPlanetId = 2
    fleet.outboundEta = 10
    fleet.eta = 4
    fp64 prog = math.fleetProgress(fleet)
    if (ok and prog < 0.59) {
        ok = false
    }
    if (ok and prog > 0.61) {
        ok = false
    }
    if (ok and not fleet.mapPathActive()) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
