/*
 * src/client/guiShipBuildPage.cw — Ships→Build dialog page.
 *
 * Yard planet + seat-developed ship type DropDowns + quantity
 * SpinButton. Dialog Apply queues PUT /build; ProgressBar tracks
 * yard-build ticks (CPL-110 / CPL-111).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Build dialog page (split from yard page).
 *   2026-11-11  Qty SpinButton; Build lists only seat-developed
 *               ready types (no phantom scout/colony).
 */

include "appCore.cw"
include "designRow.cw"
include "guiChoiceRow.cw"
include "guiProgressChrome.cw"
include "guiScaleRange.cw"
include "planetRow.cw"

/*
 * GuiShipBuildPage owns Ships→Build dialog widgets.
 *
 * Apply (dialog footer) → PUT /build at a productive owned yard.
 * Completed hulls stage as unassigned stock (CPL-101). Quantity
 * scales server build cost and ticks (CPL-111).
 */
class GuiShipBuildPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Label yardHint
    GuiChoiceRow planetChoice
    GuiChoiceRow designChoice
    Gtk.SpinButton qtySpin
    Gtk.Label qtyLabel
    void<fp64> qtyChangedAction
    bool suppressQty

    /*
     * Construct a Build page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiShipBuildPage ready for buildPage.
     */
    GuiShipBuildPage(AppCore appCore) {
        core = appCore
        progressChrome = GuiProgressChrome(appCore)
        progressChrome.setKindMask(GuiProgressChrome.KIND_BUILD)
        yardHint = null
        planetChoice = GuiChoiceRow()
        designChoice = GuiChoiceRow()
        qtySpin = null
        qtyLabel = null
        qtyChangedAction = null
        suppressQty = false
    }

    /*
     * Build the Build dialog widget tree.
     *
     * Purpose: yard/type/qty picks + build ProgressBar.
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
            "Yard build (resources; timed; productive yard)"))
        yardHint = Gtk.Label("(yards)")
        yardHint.setHExpand(true)
        yardHint.setTooltip("Owned shipyard planets.")
        page.append(yardHint)
        page.append(Gtk.Label("Yard planet"))
        page.append(planetChoice.buildWidget(
            "Owned shipyard planets by name for Queue build."))
        page.append(Gtk.Label("Ship type (developed)"))
        page.append(designChoice.buildWidget(
            "Seat-developed ready ship types by name."))
        qtyLabel = Gtk.Label("Qty (1)")
        qtyLabel.setTooltip(
            "Hulls in this build batch; extra hulls add settable time.")
        page.append(qtyLabel)
        qtySpin = Gtk.SpinButton()
        GuiScaleRange initQty = GuiScaleRange()
        initQty.normalize(1.0, 1.0, 99.0, 1.0)
        qtySpin.configure(
            initQty.value, initQty.lower, initQty.upper, initQty.step)
        qtySpin.setTooltip("Build quantity (>= 1).")
        if (qtyChangedAction != null) {
            qtySpin.onValueChanged(qtyChangedAction)
        }
        page.append(qtySpin)
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Refresh yards / choices / qty caption / build ProgressBar.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (yardHint != null) {
            yardHint.setText(core.view.yardPlanetsText())
        }
        if (progressChrome != null) {
            progressChrome.refresh()
        }
        syncYardPlanetChoices()
        syncDesignChoices()
        refreshQtyLabel()
    }

    /*
     * Bind DropDown / Spin selection handlers.
     *
     * Purpose: GuiMain activate wiring.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void bindChoices() {
        planetChoice.bindSelected(planetChoice.onSelected)
        designChoice.bindSelected(designChoice.onSelected)
    }

    /*
     * Rebuild yard planet choices from owned shipyards.
     *
     * Purpose: prefer first owned yard when current pick is stale.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncYardPlanetChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible
                and row.shipyard
                and row.ownerId == core.view.viewerId) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        planetChoice.setChoices(names)
        int64 homeYard = core.view.firstOwnedYardId()
        if (homeYard >= 0) {
            PlanetRow home = core.view.findPlanet(homeYard)
            String cur = planetChoice.value()
            int64 curId = core.view.resolvePlanetChoice(cur)
            if (cur.length < 1 or not core.view.isOwnedYard(curId)) {
                planetChoice.setValue(home.choiceLabel())
            }
        }
    }

    /*
     * Rebuild design name choices from seat-developed ready types.
     *
     * Purpose: CPL-111 — Build must not list shared phantom
     * scout/colony templates unless this seat developed them
     * (DesignRow.mine).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncDesignChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.designs.length) {
            DesignRow row = core.view.designs[index]
            if (row.id >= 0
                and row.mine
                and row.ready
                and not row.closed) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        designChoice.setChoices(names)
    }

    /*
     * Qty SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onQtyChanged(fp64 value) {
        if (suppressQty) {
            return()
        }
        refreshQtyLabel()
    }

    /*
     * Refresh qty caption from the SpinButton.
     *
     * Purpose: live label next to the spin.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshQtyLabel() {
        if (qtyLabel == null) {
            return()
        }
        qtyLabel.setText(format("Qty ({})", qtyValue()))
    }

    /*
     * Read the yard planet choice.
     *
     * Purpose: PUT /build planet id (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: planet id, or -1 when unresolved.
     */
    int64 planetValue() {
        return(core.view.resolvePlanetChoice(planetChoice.value()))
    }

    /*
     * Read the design id choice.
     *
     * Purpose: PUT /build design id (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: design id, or -1 when unresolved.
     */
    int64 designIdValue() {
        return(core.view.resolveDesignChoice(designChoice.value()))
    }

    /*
     * Read build quantity from the SpinButton.
     *
     * Purpose: PUT /build qty field.
     *
     * Parameters: none.
     *
     * Returns: hull count (>= 1).
     */
    int64 qtyValue() {
        if (qtySpin == null) {
            return(1)
        }
        int64 qty = int64(qtySpin.value() + 0.5)
        if (qty < 1) {
            return(1)
        }
        return(qty)
    }
}
