/*
 * src/client/guiFleetPage.cw — fleets tab + dispatch/recall chrome.
 *
 * List stand-in for map pick-to-dispatch (TUNING-PLAYABLE B2).
 * Entries + buttons only — no DrawingArea / Scale.
 *
 * Created: 2026-11-06
 * Author: Auto
 *
 * Changelog:
 *   2026-11-06  Initial fleet dispatch/recall / progress page.
 */

include "appCore.cw"
include "fleetRow.cw"

/*
 * GuiFleetPage owns the Fleets notebook page widgets.
 *
 * Dispatch Entries feed PUT /order; Recall uses PUT /recall.
 * Progress label shows setup durations + active jobs (B4).
 */
class GuiFleetPage {
    AppCore core
    Gtk.Label fleetList
    Gtk.Label progressLabel
    Gtk.Entry fleetIdEntry
    Gtk.Entry orderEntry
    Gtk.Entry destEntry
    Gtk.Button dispatchBtn
    Gtk.Button recallBtn
    Gtk.Label lockHint
    void<> dispatchAction
    void<> recallAction

    /*
     * Construct a fleet page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetPage ready for buildPage.
     */
    GuiFleetPage(AppCore appCore) {
        core = appCore
        fleetList = null
        progressLabel = null
        fleetIdEntry = null
        orderEntry = null
        destEntry = null
        dispatchBtn = null
        recallBtn = null
        lockHint = null
        dispatchAction = null
        recallAction = null
    }

    /*
     * Build the Fleets notebook page widget tree.
     *
     * Purpose: scrolled list + Entry dispatch/recall + progress.
     *
     * Parameters: none.
     *
     * Returns: page widget for Notebook.appendPage.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        fleetList = Gtk.Label("(no fleets)")
        fleetList.setHExpand(true)
        fleetList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(fleetList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        page.append(Gtk.Label(
            "Dispatch (explore/take/trade/move/ambush)"))
        fleetIdEntry = Gtk.Entry("0")
        orderEntry = Gtk.Entry("explore")
        destEntry = Gtk.Entry("1")
        page.append(Gtk.Label("Fleet id"))
        page.append(fleetIdEntry)
        page.append(Gtk.Label("Order"))
        page.append(orderEntry)
        page.append(Gtk.Label("Dest planet id"))
        page.append(destEntry)
        lockHint = Gtk.Label(
            "In-flight lock: rewrite disabled; use Recall.")
        page.append(lockHint)
        Gtk.Box row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        dispatchBtn = Gtk.Button("Dispatch")
        recallBtn = Gtk.Button("Recall")
        if (dispatchAction != null) {
            dispatchBtn.onClicked(dispatchAction)
        }
        if (recallAction != null) {
            recallBtn.onClicked(recallAction)
        }
        row.append(dispatchBtn)
        row.append(recallBtn)
        page.append(row)
        progressLabel = Gtk.Label("(progress)")
        progressLabel.setHExpand(true)
        page.append(Gtk.Label("Design / build progress"))
        page.append(progressLabel)
        return(page)
    }

    /*
     * Refresh list / progress / lock sensitivity from core.view.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        String fleets = ""
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible) {
                fleets.append(row.listLabel())
                fleets.append("\n")
            }
            index = index + 1
        }
        if (fleets.length < 1) {
            fleets = "(no visible fleets)\n"
        }
        if (fleetList != null) {
            fleetList.setText(fleets)
        }
        if (progressLabel != null) {
            progressLabel.setText(core.view.progressText())
        }
        syncLockChrome()
    }

    /*
     * Update Dispatch sensitivity from the selected fleet lock.
     *
     * Purpose: mid-dispatch lock UX without freezing the UI.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncLockChrome() {
        if (dispatchBtn == null or fleetIdEntry == null) {
            return()
        }
        int64 fleetId = fleetIdEntry.text().toInt64()
        FleetRow row = core.view.findFleet(fleetId)
        bool locked = false
        if (row.id >= 0) {
            locked = row.orderLocked()
        }
        dispatchBtn.setSensitive(not locked)
        if (lockHint != null) {
            if (locked) {
                lockHint.setText(
                    "Fleet locked in-flight — Recall only.")
            } else {
                lockHint.setText(
                    "Sitting: Dispatch OK. Locked: Recall only.")
            }
        }
    }

    /*
     * Read the fleet id Entry.
     *
     * Purpose: Dispatch / Recall PUT fleet field.
     *
     * Parameters: none.
     *
     * Returns: fleet id from the Entry text.
     */
    int64 fleetIdValue() {
        return(fleetIdEntry.text().toInt64())
    }

    /*
     * Read the order Entry text.
     *
     * Purpose: Dispatch PUT order field.
     *
     * Parameters: none.
     *
     * Returns: trimmed-enough order string from the Entry.
     */
    String orderValue() {
        return(orderEntry.text())
    }

    /*
     * Read the destination planet Entry.
     *
     * Purpose: Dispatch PUT dest field.
     *
     * Parameters: none.
     *
     * Returns: dest planet id.
     */
    int64 destValue() {
        return(destEntry.text().toInt64())
    }
}
