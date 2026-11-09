/*
 * src/client/guiProgressChrome.cw — develop / build ProgressBars.
 *
 * Shared footer chrome for Ships and Fleets panel dialogs.
 * Horizontal bars + detail label sit in a vertical Box inside the
 * non-modal Fleets / Ships TransientWindows (CPL-72 /
 * DIALOGS §6). Nothing here depends on Notebook tab chrome.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial GuiProgressChrome (fraction / pulse).
 *   2026-11-09  Hosted in Fleets / Ships panel dialogs.
 *   2026-11-09  Tooltips on develop/build bars (View usable).
 */

include "appCore.cw"
include "progressJob.cw"

/*
 * GuiProgressChrome owns two Gtk.ProgressBar widgets plus a detail
 * Label for multi-job / reclaim text.
 *
 * Lead develop and lead build jobs drive the bars from
 * ticksLeft / setup totals; unknown totals pulse. Refresh on every
 * snapshot pull / tick redraw.
 */
class GuiProgressChrome {
    AppCore core
    Gtk.ProgressBar developBar
    Gtk.ProgressBar buildBar
    Gtk.Label detailLabel

    /*
     * Construct progress chrome bound to an AppCore.
     *
     * Purpose: delay widget build until buildWidget().
     *
     * Parameters:
     *   appCore — shared headless coordinator (view source).
     *
     * Returns: GuiProgressChrome ready for buildWidget.
     */
    GuiProgressChrome(AppCore appCore) {
        core = appCore
        developBar = null
        buildBar = null
        detailLabel = null
    }

    /*
     * Build the develop/build progress footer widget tree.
     *
     * Purpose: dialog-friendly vertical stack — section labels,
     * ProgressBars with showText, then a multi-line detail Label
     * for reclaim rows and multi-job lists.
     *
     * Parameters: none.
     *
     * Returns: footer Box for page.append (or a future dialog).
     */
    Gtk.Widget buildWidget() {
        Gtk.Box footer = Gtk.Box(Gtk.Box.VERTICAL, 4)
        footer.append(Gtk.Label("Design develop progress"))
        developBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
        developBar.setShowText(true)
        developBar.setHExpand(true)
        developBar.setText("develop idle")
        developBar.setFraction(0.0)
        developBar.setTooltip(
            "Lead design-develop job: done ticks / setup total.")
        footer.append(developBar)
        footer.append(Gtk.Label("Yard build progress"))
        buildBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
        buildBar.setShowText(true)
        buildBar.setHExpand(true)
        buildBar.setText("build idle")
        buildBar.setFraction(0.0)
        buildBar.setTooltip(
            "Lead yard-build job: done ticks / setup total.")
        footer.append(buildBar)
        detailLabel = Gtk.Label("(progress)")
        detailLabel.setHExpand(true)
        detailLabel.setTooltip(
            "Setup durations, reclaim rows, and multi-job detail.")
        footer.append(Gtk.Label("Active jobs (detail)"))
        footer.append(detailLabel)
        return(footer)
    }

    /*
     * Refresh bars and detail text from core.view.
     *
     * Purpose: after pull / fillFromGame / tick snapshot refresh.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        applyBar(
            developBar,
            core.view.leadDevelopJob(),
            core.view.designDevelopTicks,
            core.view.developJobs.length,
            "develop idle")
        applyBar(
            buildBar,
            core.view.leadBuildJob(),
            core.view.yardBuildTicks,
            core.view.buildJobs.length,
            "build idle")
        if (detailLabel != null) {
            detailLabel.setText(core.view.progressText())
        }
    }

    /*
     * Drive one ProgressBar from a lead job and setup total.
     *
     * Purpose: determinate fraction when total > 0; pulse when a
     * job is active but the duration is unknown (total <= 0);
     * idle text at fraction 0 when no jobs.
     *
     * Parameters:
     *   bar — develop or build ProgressBar (may be null).
     *   job — lead ProgressJob (id < 0 when none).
     *   total — designDevelopTicks or yardBuildTicks.
     *   jobCount — how many jobs of this kind are active.
     *   idleText — overlay when jobCount is 0.
     *
     * Returns: nothing.
     */
    void applyBar(
        Gtk.ProgressBar bar,
        ProgressJob job,
        int64 total,
        int64 jobCount,
        String idleText) {
        if (bar == null) {
            return()
        }
        if (jobCount < 1 or job.id < 0) {
            bar.setFraction(0.0)
            bar.setText(idleText)
            return()
        }
        String label = job.barLabel()
        if (jobCount > 1) {
            label = format("{} (+{} more)", label, jobCount - 1)
        }
        bar.setText(label)
        if (total <= 0) {
            bar.pulse()
            return()
        }
        bar.setFraction(job.fractionOf(total))
    }
}
