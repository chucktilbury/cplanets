/*
 * src/client/guiYardPage.cw — Ships tab design / yard chrome.
 *
 * List stand-ins for design develop + yard build / reclaim
 * (DIALOGS §6). Entry fields only — no Scale / DrawingArea.
 * Wires to timed State.queueDesignDevelop / queueYardBuild.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial Ships notebook page.
 */

include "appCore.cw"

/*
 * GuiYardPage owns the Ships notebook page widgets.
 *
 * Start develop → PUT /design; Queue build → PUT /build;
 * Reclaim hulls → PUT /reclaim-hulls. Lists show catalog,
 * owned yards, and active progress.
 */
class GuiYardPage {
    AppCore core
    Gtk.Label designList
    Gtk.Label yardHint
    Gtk.Label progressLabel
    Gtk.Entry nameEntry
    Gtk.Entry speedEntry
    Gtk.Entry hopEntry
    Gtk.Entry sizeEntry
    Gtk.Entry cargoEntry
    Gtk.Entry kindEntry
    Gtk.Entry planetEntry
    Gtk.Entry designIdEntry
    Gtk.Entry reclaimFleetEntry
    Gtk.Entry reclaimHullsEntry
    Gtk.Button developBtn
    Gtk.Button buildBtn
    Gtk.Button reclaimBtn
    void<> developAction
    void<> buildAction
    void<> reclaimAction

    /*
     * Construct a Ships page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiYardPage ready for buildPage.
     */
    GuiYardPage(AppCore appCore) {
        core = appCore
        designList = null
        yardHint = null
        progressLabel = null
        nameEntry = null
        speedEntry = null
        hopEntry = null
        sizeEntry = null
        cargoEntry = null
        kindEntry = null
        planetEntry = null
        designIdEntry = null
        reclaimFleetEntry = null
        reclaimHullsEntry = null
        developBtn = null
        buildBtn = null
        reclaimBtn = null
        developAction = null
        buildAction = null
        reclaimAction = null
    }

    /*
     * Build the Ships notebook page widget tree.
     *
     * Purpose: design list + editor Entries + yard/reclaim
     * Entries + progress (DIALOGS §6 list stand-ins).
     *
     * Parameters: none.
     *
     * Returns: page widget for Notebook.appendPage.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        designList = Gtk.Label("(no designs)")
        designList.setHExpand(true)
        designList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(designList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(Gtk.Label("Designs (inspect)"))
        page.append(scroll)
        yardHint = Gtk.Label("(yards)")
        yardHint.setHExpand(true)
        page.append(yardHint)
        page.append(Gtk.Label(
            "Start design develop (wealth; timed)"))
        nameEntry = Gtk.Entry("custom")
        speedEntry = Gtk.Entry("1.0")
        hopEntry = Gtk.Entry("5.0")
        sizeEntry = Gtk.Entry("1.0")
        cargoEntry = Gtk.Entry("0.0")
        kindEntry = Gtk.Entry("war")
        page.append(Gtk.Label("Name"))
        page.append(nameEntry)
        page.append(Gtk.Label("Speed"))
        page.append(speedEntry)
        page.append(Gtk.Label("Hop reach"))
        page.append(hopEntry)
        page.append(Gtk.Label("Size (cost basis)"))
        page.append(sizeEntry)
        page.append(Gtk.Label("Cargo hold"))
        page.append(cargoEntry)
        page.append(Gtk.Label("Kind (scout/colony/defense/war)"))
        page.append(kindEntry)
        developBtn = Gtk.Button("Start develop")
        if (developAction != null) {
            developBtn.onClicked(developAction)
        }
        page.append(developBtn)
        page.append(Gtk.Label(
            "Yard build (resources; timed; productive yard)"))
        planetEntry = Gtk.Entry("0")
        designIdEntry = Gtk.Entry("0")
        page.append(Gtk.Label("Yard planet id"))
        page.append(planetEntry)
        page.append(Gtk.Label("Ready design id"))
        page.append(designIdEntry)
        buildBtn = Gtk.Button("Queue build")
        if (buildAction != null) {
            buildBtn.onClicked(buildAction)
        }
        page.append(buildBtn)
        page.append(Gtk.Label(
            "Reclaim hulls (sitting fleet at yard)"))
        reclaimFleetEntry = Gtk.Entry("1")
        reclaimHullsEntry = Gtk.Entry("1")
        page.append(Gtk.Label("Fleet id"))
        page.append(reclaimFleetEntry)
        page.append(Gtk.Label("Hulls"))
        page.append(reclaimHullsEntry)
        reclaimBtn = Gtk.Button("Reclaim hulls")
        if (reclaimAction != null) {
            reclaimBtn.onClicked(reclaimAction)
        }
        page.append(reclaimBtn)
        progressLabel = Gtk.Label("(progress)")
        progressLabel.setHExpand(true)
        page.append(Gtk.Label("Active design / build / reclaim"))
        page.append(progressLabel)
        return(page)
    }

    /*
     * Refresh design list / yards / progress from core.view.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (designList != null) {
            designList.setText(core.view.designsText())
        }
        if (yardHint != null) {
            yardHint.setText(core.view.yardPlanetsText())
        }
        if (progressLabel != null) {
            progressLabel.setText(core.view.progressText())
        }
    }

    /*
     * Read the name Entry text.
     *
     * Purpose: PUT /design name field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String nameValue() {
        return(nameEntry.text())
    }

    /*
     * Read the speed Entry text.
     *
     * Purpose: PUT /design speed field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String speedValue() {
        return(speedEntry.text())
    }

    /*
     * Read the hop Entry text.
     *
     * Purpose: PUT /design hop field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String hopValue() {
        return(hopEntry.text())
    }

    /*
     * Read the size Entry text.
     *
     * Purpose: PUT /design size field (cost basis).
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String sizeValue() {
        return(sizeEntry.text())
    }

    /*
     * Read the cargo Entry text.
     *
     * Purpose: PUT /design cargo field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String cargoValue() {
        return(cargoEntry.text())
    }

    /*
     * Read the kind Entry text.
     *
     * Purpose: PUT /design kind field.
     *
     * Parameters: none.
     *
     * Returns: Entry text (scout/colony/defense/war).
     */
    String kindValue() {
        return(kindEntry.text())
    }

    /*
     * Read the yard planet Entry.
     *
     * Purpose: PUT /build planet id.
     *
     * Parameters: none.
     *
     * Returns: planet id.
     */
    int64 planetValue() {
        return(planetEntry.text().toInt64())
    }

    /*
     * Read the design id Entry.
     *
     * Purpose: PUT /build design id.
     *
     * Parameters: none.
     *
     * Returns: design id.
     */
    int64 designIdValue() {
        return(designIdEntry.text().toInt64())
    }

    /*
     * Read the reclaim fleet Entry.
     *
     * Purpose: PUT /reclaim-hulls fleet id.
     *
     * Parameters: none.
     *
     * Returns: fleet id.
     */
    int64 reclaimFleetValue() {
        return(reclaimFleetEntry.text().toInt64())
    }

    /*
     * Read the reclaim hulls Entry.
     *
     * Purpose: PUT /reclaim-hulls hull count.
     *
     * Parameters: none.
     *
     * Returns: hull count.
     */
    int64 reclaimHullsValue() {
        return(reclaimHullsEntry.text().toInt64())
    }
}
