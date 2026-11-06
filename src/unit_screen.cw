/*
 * src/unit_screen.cw — screened heavies lose fewer hulls.
 *
 * Fixed fixtures: frigates screen destroyers; heavies alone take
 * the full hit (PLAN D4 / RULES §12).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial screening unit program.
 */

include "lib/design.cw"
include "lib/fleet.cw"
include "lib/screen.cw"

start {
    Screen screen = Screen()
    bool ok = true

    Design frig = Design(0)
    frig.makeFrigate(3.0)
    Design dest = Design(1)
    dest.makeDestroyer(3.0)
    Design colony = Design(2)
    colony.makeColony(1.0)

    if (not screen.canScreen(frig)) {
        ok = false
    }
    if (screen.canScreen(dest)) {
        ok = false
    }
    if (screen.canScreen(colony)) {
        ok = false
    }
    if (not screen.isHeavy(dest)) {
        ok = false
    }
    if (screen.isHeavy(frig)) {
        ok = false
    }

    list designs = []
    designs.append(frig)
    designs.append(dest)

    # Screened: 4 frigates + 2 destroyers take a 16-strength hit.
    list screened = []
    screened.append(Fleet(1, 0, 0, 0, 4))
    screened.append(Fleet(2, 0, 0, 1, 2))
    Fleet a = screened[0]
    a.engagementId = 1
    screened[0] = a
    Fleet b = screened[1]
    b.engagementId = 1
    screened[1] = b
    fp64 hit = 16.0
    screen.applyHit(screened, designs, 1, 0, 0, hit)
    int64 heavyLeftScreened = 0
    int64 i = 0
    while (i < screened.length) {
        Fleet f = screened[i]
        if (f.designId == 1) {
            heavyLeftScreened = f.hullCount
        }
        i = i + 1
    }

    # Unscreened: 2 destroyers alone take the same hit.
    list alone = []
    alone.append(Fleet(3, 0, 0, 1, 2))
    Fleet c = alone[0]
    c.engagementId = 2
    alone[0] = c
    screen.applyHit(alone, designs, 2, 0, 0, hit)
    int64 heavyLeftAlone = 0
    i = 0
    while (i < alone.length) {
        Fleet f = alone[i]
        if (f.designId == 1) {
            heavyLeftAlone = f.hullCount
        }
        i = i + 1
    }

    if (heavyLeftScreened <= heavyLeftAlone) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
