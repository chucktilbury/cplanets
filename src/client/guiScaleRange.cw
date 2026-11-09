/*
 * src/client/guiScaleRange.cw — safe Gtk.Scale.configure args.
 *
 * Cwhip GTK Scale.configure fatals when !(upper > lower) or
 * !(step > 0). Hull Scales (dispatch peel / reclaim) can hit
 * empty fleets, zero hulls, or a single-hull stack where the
 * logical min equals the logical max — this helper widens the
 * range just enough for GTK while callers keep clamping reads.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial normalize for hull Scale crash fix.
 */

/*
 * GuiScaleRange holds one sanitized Scale.configure quadruple.
 *
 * Call normalize() before every configure() that may see an
 * empty selection or a degenerate hull count.
 */
class GuiScaleRange {
    fp64 value
    fp64 lower
    fp64 upper
    fp64 step

    /*
     * Construct an empty (zeroed) range holder.
     *
     * Purpose: allocate before normalize fills fields.
     *
     * Parameters: none.
     *
     * Returns: GuiScaleRange with all zeros.
     */
    GuiScaleRange() {
        value = 0.0
        lower = 0.0
        upper = 0.0
        step = 0.0
    }

    /*
     * Sanitize value/lower/upper/step for Gtk.Scale.configure.
     *
     * Purpose: guarantee upper > lower and step > 0 so the GTK
     * binding never fatals "invalid scale range or step".
     *
     * Parameters:
     *   nextValue — desired thumb position (clamped into range).
     *   nextLower — requested inclusive minimum.
     *   nextUpper — requested inclusive maximum (may equal lower).
     *   nextStep — requested positive increment (repaired if <= 0).
     *
     * Returns: nothing (fields updated in place).
     */
    void normalize(
            fp64 nextValue, fp64 nextLower, fp64 nextUpper,
            fp64 nextStep) {
        step = nextStep
        if (step <= 0.0) {
            step = 1.0
        }
        lower = nextLower
        upper = nextUpper
        if (upper <= lower) {
            upper = lower + step
        }
        value = nextValue
        if (value < lower) {
            value = lower
        }
        if (value > upper) {
            value = upper
        }
    }
}
