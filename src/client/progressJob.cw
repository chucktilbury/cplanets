/*
 * src/client/progressJob.cw — one develop / build / reclaim job.
 *
 * Structured chrome-trailer rows so Ships (and Fleets) can drive
 * Gtk.ProgressBar fraction from ticksLeft / setup total, instead
 * of text-only progress labels (DIALOGS §6 / CPL-72).
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial ProgressJob for develop/build bars.
 */

/*
 * ProgressJob is one in-flight design develop, yard build, or
 * reclaim countdown published in the chrome trailer.
 *
 * ticksLeft is remaining; fraction uses a caller-supplied setup
 * total (designDevelopTicks or yardBuildTicks). kind distinguishes
 * bar / label wording without parallel list types.
 */
class ProgressJob {
    enum {
        KIND_DEVELOP = 0,
        KIND_BUILD = 1,
        KIND_RECLAIM = 2
    }

    int64 kind
    int64 id
    int64 ownerId
    int64 planetId
    int64 designId
    int64 hulls
    int64 ticksLeft

    /*
     * Construct an empty progress job.
     *
     * Purpose: decode target and missing-job sentinel.
     *
     * Parameters: none.
     *
     * Returns: ProgressJob with KIND_DEVELOP and id -1.
     */
    ProgressJob() {
        kind = KIND_DEVELOP
        id = -1
        ownerId = -1
        planetId = -1
        designId = -1
        hulls = 0
        ticksLeft = 0
    }

    /*
     * Determinate fraction for a known setup duration.
     *
     * Purpose: ProgressBar.setFraction when total ticks > 0.
     * Completed work is (total - ticksLeft) / total, clamped to
     * [0, 1]. Callers pulse instead when total <= 0.
     *
     * Parameters:
     *   total — setup designDevelopTicks or yardBuildTicks.
     *
     * Returns: 0..1 filled fraction; 0 when total <= 0.
     */
    fp64 fractionOf(int64 total) {
        if (total <= 0) {
            return(0.0)
        }
        int64 done = total - ticksLeft
        if (done < 0) {
            done = 0
        }
        if (done > total) {
            done = total
        }
        return(fp64(done) / fp64(total))
    }

    /*
     * Short overlay label for a ProgressBar with showText.
     *
     * Purpose: identify the lead job without a modal wait dialog.
     *
     * Parameters: none.
     *
     * Returns: one-line develop / build / reclaim summary.
     */
    String barLabel() {
        if (kind == KIND_BUILD) {
            return(format(
                "build {} planet={} design={} left={}",
                id, planetId, designId, ticksLeft))
        }
        if (kind == KIND_RECLAIM) {
            return(format(
                "reclaim {} planet={} hulls={} left={}",
                id, planetId, hulls, ticksLeft))
        }
        return(format(
            "design {} developing left={}", id, ticksLeft))
    }

    /*
     * Multi-line detail line matching the prior progressText shape.
     *
     * Purpose: keep the scrolled/detail Label useful when several
     * jobs run; bar shows only the lead job.
     *
     * Parameters: none.
     *
     * Returns: one progress detail line (no trailing newline).
     */
    String detailLine() {
        if (kind == KIND_BUILD) {
            return(format(
                "build {} owner={} planet={} design={} ticksLeft={}",
                id, ownerId, planetId, designId, ticksLeft))
        }
        if (kind == KIND_RECLAIM) {
            return(format(
                "reclaim {} owner={} planet={} design={} hulls={} ticksLeft={}",
                id, ownerId, planetId, designId, hulls, ticksLeft))
        }
        return(format(
            "design {} developing ticksLeft={}", id, ticksLeft))
    }
}
