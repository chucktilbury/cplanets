/*
 * tests/unit/unit_guiScaleRange.cw — Scale.configure arg guard.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Cover empty / equal / inverted / bad-step cases.
 */

include "client/guiScaleRange.cw"

start {
    bool ok = true
    GuiScaleRange hullRange = GuiScaleRange()

    /* Degenerate reclaim 1..1 must widen so upper > lower. */
    hullRange.normalize(1.0, 1.0, 1.0, 1.0)
    if (ok and not (hullRange.upper > hullRange.lower)) {
        ok = false
    }
    if (ok and not (hullRange.step > 0.0)) {
        ok = false
    }
    if (ok and hullRange.value != 1.0) {
        ok = false
    }

    /* Empty / zero-hull logical max still yields a valid range. */
    hullRange.normalize(0.0, 0.0, 0.0, 1.0)
    if (ok and not (hullRange.upper > hullRange.lower)) {
        ok = false
    }
    if (ok and hullRange.lower != 0.0) {
        ok = false
    }
    if (ok and hullRange.upper != 1.0) {
        ok = false
    }

    /* Inverted lower/upper repaired; value clamped. */
    hullRange.normalize(5.0, 10.0, 3.0, 1.0)
    if (ok and not (hullRange.upper > hullRange.lower)) {
        ok = false
    }
    if (ok and hullRange.lower != 10.0) {
        ok = false
    }
    if (ok and hullRange.upper != 11.0) {
        ok = false
    }
    if (ok and hullRange.value != 10.0) {
        ok = false
    }

    /* Non-positive step becomes 1. */
    hullRange.normalize(2.0, 0.0, 5.0, 0.0)
    if (ok and hullRange.step != 1.0) {
        ok = false
    }
    if (ok and hullRange.value != 2.0) {
        ok = false
    }

    /* Healthy multi-hull peel range passes through. */
    hullRange.normalize(0.0, 0.0, 4.0, 1.0)
    if (ok and hullRange.lower != 0.0) {
        ok = false
    }
    if (ok and hullRange.upper != 4.0) {
        ok = false
    }
    if (ok and hullRange.value != 0.0) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
