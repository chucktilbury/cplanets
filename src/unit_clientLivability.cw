/*
 * src/unit_clientLivability.cw — explored dialog 1–10 text (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 */

include "client/planetRow.cw"

start {
    bool ok = true
    PlanetRow row = PlanetRow()
    row.id = 3
    row.qualityKnown = true
    row.livabilityDisplay = 7
    row.resourcesDisplay = 4
    row.productive = true
    row.populated = true
    if (not row.dialogMayChange()) {
        ok = false
    }
    String text = row.exploredDialogText()
    if (ok and text.length < 10) {
        ok = false
    }
    if (ok and text.find("Livability: 7") < 0) {
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
