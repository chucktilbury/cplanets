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
 *   2026-11-07  Hulls Entry for split-dispatch of sitting stacks.
 *   2026-11-07  Fleet id Entry defaults/syncs to a sitting stack
 *               (never leave 0 — fleets start at 1).
 */

include "appCore.cw"
include "fleetRow.cw"

/*
 * GuiFleetPage owns the Fleets notebook page widgets.
 *
 * Dispatch Entries feed PUT /order; Recall uses PUT /recall.
 * Hulls Entry peels a subset from a multi-hull sitting stack
 * (0 = whole fleet). Progress label shows setup durations +
 * active jobs (B4).
 */
class GuiFleetPage {
    AppCore core
    Gtk.Label fleetList
    Gtk.Label progressLabel
    Gtk.Entry fleetIdEntry
    Gtk.Entry orderEntry
    Gtk.Entry destEntry
    Gtk.Entry hullsEntry
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
        hullsEntry = null
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
        fleetIdEntry = Gtk.Entry("1")
        orderEntry = Gtk.Entry("explore")
        destEntry = Gtk.Entry("1")
        hullsEntry = Gtk.Entry("0")
        page.append(Gtk.Label("Fleet id (sitting stack)"))
        page.append(fleetIdEntry)
        page.append(Gtk.Label("Order"))
        page.append(orderEntry)
        page.append(Gtk.Label("Dest planet id"))
        page.append(destEntry)
        page.append(Gtk.Label(
            "Hulls to send (0 = whole sitting stack)"))
        page.append(hullsEntry)
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
        syncFleetIdEntry()
        syncLockChrome()
    }

    /*
     * Pin Fleet id Entry to a live sitting owned stack.
     *
     * Purpose: Entry must not stay on 0 (no fleet has id 0) or on
     * a stale id after yard builds spawn / merge sit fleets. Prefer
     * the lowest sitting owned id when the field is empty, 0, or
     * names a fleet missing from the snapshot.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFleetIdEntry() {
        if (fleetIdEntry == null) {
            return()
        }
        int64 sit = core.view.firstSittingOwnedFleetId()
        if (sit < 0) {
            return()
        }
        String text = fleetIdEntry.text()
        if (text.length < 1) {
            fleetIdEntry.setText(format("{}", sit))
            return()
        }
        int64 current = text.toInt64()
        if (current < 1 or not core.view.isOwnedFleet(current)) {
            fleetIdEntry.setText(format("{}", sit))
        }
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

    /*
     * Read the hulls-to-send Entry.
     *
     * Purpose: peel a subset from a multi-hull sitting stack
     * before PUT /order (0 = dispatch the whole fleet).
     *
     * Parameters: none.
     *
     * Returns: hull count from the Entry text.
     */
    int64 hullsValue() {
        if (hullsEntry == null) {
            return(0)
        }
        return(hullsEntry.text().toInt64())
    }

    /*
     * Write the destination planet Entry from a map pick.
     *
     * Purpose: GuiMapPage primary-click / ContextMenu dispatch
     * feeds the existing Fleets-tab PUT /order chrome (fewest
     * hoops — no second dest control).
     *
     * Parameters:
     *   planetId — rock id to send toward.
     *
     * Returns: nothing.
     */
    void setDestPlanet(int64 planetId) {
        if (destEntry == null) {
            return()
        }
        destEntry.setText(format("{}", planetId))
        syncLockChrome()
    }
}
