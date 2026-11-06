/*
 * tests/unit/unit_combat.cw — combat needsFight / strength helpers.
 *
 * Fixed fixtures: unowned free, productive inherent never free,
 * satellites defend, short-circuit gap (PLAN D1 / RULES §11–§12).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial combat unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/combat.cw"
include "lib/design.cw"
include "lib/fleet.cw"
include "lib/planet.cw"
include "lib/scenario.cw"

start {
    Combat combat = Combat()
    Scenario scenario = Scenario()
    bool ok = true

    Planet unowned = Planet(1)
    if (combat.needsFight(scenario, unowned, 0, 0.0)) {
        ok = false
    }

    Planet emptyOwned = Planet(2)
    emptyOwned.ownerId = 1
    emptyOwned.productive = false
    if (combat.needsFight(scenario, emptyOwned, 0, 0.0)) {
        ok = false
    }

    Planet productive = Planet(3)
    productive.ownerId = 1
    productive.productive = true
    if (not combat.needsFight(scenario, productive, 0, 0.0)) {
        ok = false
    }
    fp64 inherent = combat.defenderStrength(scenario, productive, 0.0)
    if (inherent != scenario.productiveInherentDefense) {
        ok = false
    }

    Planet sats = Planet(4)
    sats.ownerId = 1
    sats.productive = false
    sats.satelliteDefense = 2.5
    if (not combat.needsFight(scenario, sats, 0, 0.0)) {
        ok = false
    }
    if (combat.defenderStrength(scenario, sats, 1.0) != 3.5) {
        ok = false
    }

    Design scout = Design(0)
    scout.makeScout(3.0)
    Fleet fleet = Fleet(1, 0, 0, 0, 4)
    fp64 atk = combat.fleetStrength(fleet, scout)
    if (atk != 2.0) {
        ok = false
    }
    Design colony = Design(1)
    colony.makeColony(1.0)
    Fleet col = Fleet(2, 0, 0, 1, 2)
    fp64 weak = combat.fleetStrength(col, colony)
    if (weak != 2.5) {
        # 2 * 5.0 * 0.25 = 2.5
        ok = false
    }

    if (not combat.shortCircuits(scenario, 10.0, 1.0)) {
        ok = false
    }
    if (combat.shortCircuits(scenario, 2.0, 1.0)) {
        # gap 2 < default battleShortCircuitGap 3
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
