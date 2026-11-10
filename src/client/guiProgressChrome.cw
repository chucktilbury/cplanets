/*
 * src/client/guiProgressChrome.cw — develop / build / reclaim bars.
 *
 * Shared ProgressBar chrome for Ships submenu dialogs (and Deploy
 * travel is separate). Horizontal bars + detail label sit in a
 * vertical Box inside non-modal TransientWindows (CPL-72 /
 * CPL-110 / DIALOGS §6).
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial GuiProgressChrome (fraction / pulse).
 *   2026-11-09  Hosted in Fleets / Ships panel dialogs.
 *   2026-11-09  Tooltips on develop/build bars (View usable).
 *   2026-11-10  CPL-110: kind filter + reclaim ProgressBar.
 */

include "appCore.cw"
include "progressJob.cw"

/*
 * GuiProgressChrome owns optional Gtk.ProgressBar widgets plus a
 * detail Label for multi-job text.
 *
 * kindMask selects which bars to build (develop / build / reclaim).
 * Lead jobs drive bars from ticksLeft / setup totals; unknown
 * totals pulse. Refresh on every snapshot pull / tick redraw.
 */
class GuiProgressChrome {
    enum {
        KIND_DEVELOP = 1,
        KIND_BUILD = 2,
        KIND_RECLAIM = 4,
        KIND_ALL = 7
    }

    AppCore core
    int64 kindMask
    Gtk.ProgressBar developBar
    Gtk.ProgressBar buildBar
    Gtk.ProgressBar reclaimBar
    Gtk.Label detailLabel

    /*
     * Construct progress chrome bound to an AppCore.
     *
     * Purpose: delay widget build until buildWidget(); default
     * mask shows develop + build (legacy Ships/Fleets footer).
     *
     * Parameters:
     *   appCore — shared headless coordinator (view source).
     *
     * Returns: GuiProgressChrome ready for buildWidget.
     */
    GuiProgressChrome(AppCore appCore) {
        core = appCore
        kindMask = KIND_DEVELOP + KIND_BUILD
        developBar = null
        buildBar = null
        reclaimBar = null
        detailLabel = null
    }

    /*
     * Select which ProgressBars buildWidget will create.
     *
     * Purpose: Ships Develop / Build / Reclaim dialogs show only
     * the bar that matches their job (CPL-110).
     *
     * Parameters:
     *   mask — KIND_DEVELOP / KIND_BUILD / KIND_RECLAIM bits.
     *
     * Returns: nothing.
     */
    void setKindMask(int64 mask) {
        kindMask = mask
    }

    /*
     * Build the progress footer widget tree for the kind mask.
     *
     * Purpose: dialog-friendly vertical stack — section labels,
     * ProgressBars with showText, then a multi-line detail Label.
     *
     * Parameters: none.
     *
     * Returns: footer Box for page.append.
     */
    Gtk.Widget buildWidget() {
        Gtk.Box footer = Gtk.Box(Gtk.Box.VERTICAL, 4)
        if ((kindMask & KIND_DEVELOP) != 0) {
            footer.append(Gtk.Label("Design develop progress"))
            developBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
            developBar.setShowText(true)
            developBar.setHExpand(true)
            developBar.setText("develop idle")
            developBar.setFraction(0.0)
            developBar.setTooltip(
                "Lead design-develop job: done ticks / setup total.")
            footer.append(developBar)
        }
        if ((kindMask & KIND_BUILD) != 0) {
            footer.append(Gtk.Label("Yard build progress"))
            buildBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
            buildBar.setShowText(true)
            buildBar.setHExpand(true)
            buildBar.setText("build idle")
            buildBar.setFraction(0.0)
            buildBar.setTooltip(
                "Lead yard-build job: done ticks / setup total.")
            footer.append(buildBar)
        }
        if ((kindMask & KIND_RECLAIM) != 0) {
            footer.append(Gtk.Label("Reclaim progress"))
            reclaimBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
            reclaimBar.setShowText(true)
            reclaimBar.setHExpand(true)
            reclaimBar.setText("reclaim idle")
            reclaimBar.setFraction(0.0)
            reclaimBar.setTooltip(
                "Lead reclaim job: done ticks / yard-build total.")
            footer.append(reclaimBar)
        }
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
        applyBar(
            reclaimBar,
            core.view.leadReclaimJob(),
            core.view.yardBuildTicks,
            core.view.reclaimJobs.length,
            "reclaim idle")
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
     *   bar — develop / build / reclaim ProgressBar (may be null).
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
