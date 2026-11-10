/*
 * src/client/guiShipDevelopPage.cw — Ships→Develop dialog page.
 *
 * Design-parameter Entries + kind DropDown. Dialog Apply queues
 * PUT /design; ProgressBar tracks develop ticks (CPL-110).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Develop dialog page (split from yard page).
 */

include "appCore.cw"
include "guiChoiceRow.cw"
include "guiProgressChrome.cw"

/*
 * GuiShipDevelopPage owns Ships→Develop dialog widgets.
 *
 * Apply (dialog footer) → PUT /design. Develop is a silent noop
 * when the same parameters already exist for the seat.
 */
class GuiShipDevelopPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Entry nameEntry
    Gtk.Entry speedEntry
    Gtk.Entry hopEntry
    Gtk.Entry sizeEntry
    Gtk.Entry cargoEntry
    GuiChoiceRow kindChoice

    /*
     * Construct a Develop page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiShipDevelopPage ready for buildPage.
     */
    GuiShipDevelopPage(AppCore appCore) {
        core = appCore
        progressChrome = GuiProgressChrome(appCore)
        progressChrome.setKindMask(GuiProgressChrome.KIND_DEVELOP)
        nameEntry = null
        speedEntry = null
        hopEntry = null
        sizeEntry = null
        cargoEntry = null
        kindChoice = GuiChoiceRow()
    }

    /*
     * Build the Develop dialog widget tree.
     *
     * Purpose: design editor fields + develop ProgressBar.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label(
            "Start design develop (wealth; timed)"))
        nameEntry = Gtk.Entry("custom")
        nameEntry.setTooltip("New design name.")
        speedEntry = Gtk.Entry("1.0")
        speedEntry.setTooltip("Design speed (float).")
        hopEntry = Gtk.Entry("5.0")
        hopEntry.setTooltip("Hop reach distance (float).")
        sizeEntry = Gtk.Entry("1.0")
        sizeEntry.setTooltip("Size / cost basis (float).")
        cargoEntry = Gtk.Entry("0.0")
        cargoEntry.setTooltip("Cargo hold capacity (float).")
        kindChoice.setChoices(kindChoices())
        kindChoice.setValue("war")
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
        page.append(kindChoice.buildWidget(
            "Design kind: scout, colony, defense, or war."))
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Fixed design kind list.
     *
     * Purpose: kindChoice seed.
     *
     * Parameters: none.
     *
     * Returns: list of kind strings.
     */
    list kindChoices() {
        list out = []
        out.append("scout")
        out.append("colony")
        out.append("defense")
        out.append("war")
        return(out)
    }

    /*
     * Refresh develop ProgressBar from core.view.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (progressChrome != null) {
            progressChrome.refresh()
        }
    }

    /*
     * Bind the kind DropDown selection handler.
     *
     * Purpose: GuiMain activate wiring.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void bindChoices() {
        kindChoice.bindSelected(kindChoice.onSelected)
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
     * Read the selected design kind.
     *
     * Purpose: PUT /design kind field.
     *
     * Parameters: none.
     *
     * Returns: kind string (scout/colony/defense/war).
     */
    String kindValue() {
        String kind = kindChoice.value()
        if (kind.length < 1) {
            return("war")
        }
        return(kind)
    }
}
