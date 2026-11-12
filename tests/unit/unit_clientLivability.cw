/*
 * tests/unit/unit_clientLivability.cw — explored dialog 1–10 text (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "client/planetRow.cw"

start {
    bool ok = true
    PlanetRow row = PlanetRow()
    row.id = 3
    row.qualityKnown = true
    row.livabilityDisplay = 7
    row.resourcesDisplay = 4
    row.airDisplay = 8
    row.waterDisplay = 6
    row.commonMineralsDisplay = 5
    row.rareMineralsDisplay = 3
    row.airAccessDisplay = 9
    row.waterAccessDisplay = 8
    row.commonMineralsAccessDisplay = 4
    row.rareMineralsAccessDisplay = 2
    row.productive = true
    row.populated = true
    if (not row.dialogMayChange()) {
        ok = false
    }
    String text = row.exploredDialogText()
    if (ok and text.length < 10) {
        ok = false
    }
    if (ok and text.find("Farming (air+water): 7") < 0) {
        ok = false
    }
    if (ok and text.find("Air: 8 (access 9)") < 0) {
        ok = false
    }
    if (ok and text.find("may change") < 0) {
        ok = false
    }
    PlanetRow unknown = PlanetRow()
    unknown.id = 1
    if (ok and unknown.exploredDialogText().length != 0) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
