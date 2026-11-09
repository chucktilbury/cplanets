/*
 * tests/unit/unit_fleetExamine.cw — fleet / design examine dialog text.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial fleet + design examine body unit.
 */

include "client/designRow.cw"
include "client/fleetRow.cw"

start {
    bool ok = true

    FleetRow fleet = FleetRow()
    fleet.id = 4
    fleet.visible = true
    fleet.sitting = true
    fleet.ownerId = 0
    fleet.order = "sit"
    fleet.hullCount = 3
    fleet.locationPlanetId = 0
    fleet.destPlanetId = -1
    String fleetText = fleet.examineDialogText()
    if (fleetText.find("Fleet 4") < 0) {
        ok = false
    }
    if (ok and fleetText.find("sitting") < 0) {
        ok = false
    }
    if (ok and fleetText.find("Hulls: 3") < 0) {
        ok = false
    }
    FleetRow missing = FleetRow()
    if (ok and missing.examineDialogText().length != 0) {
        ok = false
    }

    DesignRow design = DesignRow()
    design.id = 0
    design.name = "scout"
    design.scout = true
    design.ready = true
    design.speedMilli = 1000
    design.hopMilli = 5000
    design.sizeMilli = 1000
    String designText = design.examineDialogText()
    if (ok and designText.find("Design 0") < 0) {
        ok = false
    }
    if (ok and designText.find("scout") < 0) {
        ok = false
    }
    if (ok and designText.find("ready to build") < 0) {
        ok = false
    }
    DesignRow blank = DesignRow()
    if (ok and blank.examineDialogText().length != 0) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
