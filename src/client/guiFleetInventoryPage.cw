/*
 * src/client/guiFleetInventoryPage.cw — Fleets→Inventory dialog.
 *
 * Per-planet fleet inventory with multi-select unassigned stock,
 * Assign / Un-assign into a named fleet at that planet, and
 * Examine via Apply (CPL-111). Fleets→Assign menu entry removed —
 * assign lives here.
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Fleets Inventory dialog page.
 *   2026-11-11  Planet scope; multi-select stock; Assign /
 *               Un-assign buttons (CPL-111).
 */

include "appCore.cw"
include "designRow.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"
include "guiScaleRange.cw"
include "planetRow.cw"
include "stockRow.cw"

/*
 * GuiFleetInventoryPage owns Fleets→Inventory dialog widgets.
 *
 * Planet DropDown scopes stock and fleets. Stock rows are
 * CheckButtons (multi-select). Assign moves selected stock into
 * the chosen fleet at that planet; Un-assign frees those type
 * names from the fleet back to stock. Apply examines the fleet.
 */
class GuiFleetInventoryPage {
    AppCore core
    GuiChoiceRow planetChoice
    Gtk.ScrolledWindow stockScroll
    list stockChecks
    list stockLabels
    Gtk.Label fleetList
    GuiChoiceRow fleetChoice
    Gtk.Label selectedHint
    Gtk.SpinButton qtySpin
    Gtk.Label qtyLabel
    Gtk.Button assignBtn
    Gtk.Button unassignBtn
    void<> assignAction
    void<> unassignAction
    void<fp64> qtyChangedAction
    bool suppressQty

    /*
     * Construct an Inventory page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetInventoryPage ready for buildPage.
     */
    GuiFleetInventoryPage(AppCore appCore) {
        core = appCore
        planetChoice = GuiChoiceRow()
        stockScroll = null
        stockChecks = []
        stockLabels = []
        fleetList = null
        fleetChoice = GuiChoiceRow()
        selectedHint = null
        qtySpin = null
        qtyLabel = null
        assignBtn = null
        unassignBtn = null
        assignAction = null
        unassignAction = null
        qtyChangedAction = null
        suppressQty = false
    }

    /*
     * Build the Fleets Inventory dialog widget tree.
     *
     * Purpose: planet scope + multi-select stock + fleet picks +
     * Assign / Un-assign actions.
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
            "Fleets inventory (per planet; assign / un-assign)"))
        page.append(Gtk.Label("Planet"))
        page.append(planetChoice.buildWidget(
            "Owned planet — stock and fleets at this location."))
        page.append(Gtk.Label(
            "Unassigned stock (multi-select)"))
        stockScroll = Gtk.ScrolledWindow()
        stockScroll.setHExpand(true)
        stockScroll.setVExpand(true)
        stockScroll.setTooltip(
            "Check types at this planet to Assign into a fleet.")
        page.append(stockScroll)
        page.append(Gtk.Label("Fleets at planet"))
        fleetList = Gtk.Label("(no fleets)")
        fleetList.setHExpand(true)
        fleetList.setTooltip(
            "Named fleets sitting at the selected planet.")
        Gtk.ScrolledWindow fleetScroll = Gtk.ScrolledWindow()
        fleetScroll.setChild(fleetList)
        fleetScroll.setHExpand(true)
        fleetScroll.setVExpand(true)
        page.append(fleetScroll)
        page.append(Gtk.Label("Select fleet"))
        page.append(fleetChoice.buildWidget(
            "Fleet at this planet — Assign / Un-assign / Examine."))
        selectedHint = Gtk.Label("(select a fleet)")
        selectedHint.setHExpand(true)
        page.append(selectedHint)
        qtyLabel = Gtk.Label("Qty (1)")
        page.append(qtyLabel)
        qtySpin = Gtk.SpinButton()
        GuiScaleRange initQty = GuiScaleRange()
        initQty.normalize(1.0, 1.0, 99.0, 1.0)
        qtySpin.configure(
            initQty.value, initQty.lower, initQty.upper, initQty.step)
        qtySpin.setTooltip(
            "Hulls per selected type for Assign / Un-assign.")
        if (qtyChangedAction != null) {
            qtySpin.onValueChanged(qtyChangedAction)
        }
        page.append(qtySpin)
        Gtk.Box actions = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        assignBtn = Gtk.Button("Assign")
        assignBtn.setTooltip(
            "Move selected stock types into the selected fleet.")
        if (assignAction != null) {
            assignBtn.onClicked(assignAction)
        }
        actions.append(assignBtn)
        unassignBtn = Gtk.Button("Un-assign")
        unassignBtn.setTooltip(
            "Free selected types from the fleet back to stock.")
        if (unassignAction != null) {
            unassignBtn.onClicked(unassignAction)
        }
        actions.append(unassignBtn)
        page.append(actions)
        rebuildStockChecks()
        return(page)
    }

    /*
     * Refresh planet / stock / fleet chrome from core.view.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        syncPlanetChoices()
        rebuildStockChecks()
        refreshFleetList()
        syncFleetChoices()
        refreshSelectedHint()
        refreshQtyLabel()
    }

    /*
     * Bind DropDown selection handlers.
     *
     * Purpose: GuiMain activate wiring.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void bindChoices() {
        planetChoice.bindSelected(planetChoice.onSelected)
        fleetChoice.bindSelected(fleetChoice.onSelected)
    }

    /*
     * Rebuild owned-planet choices for inventory scope.
     *
     * Purpose: fleets and stock are inventoried per planet.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncPlanetChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 0) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        planetChoice.setChoices(names)
        int64 homeYard = core.view.firstOwnedYardId()
        if (homeYard >= 0) {
            PlanetRow home = core.view.findPlanet(homeYard)
            String cur = planetChoice.value()
            if (cur.length < 1) {
                planetChoice.setValue(home.choiceLabel())
            }
        }
    }

    /*
     * Rebuild multi-select CheckButtons for stock at this planet.
     *
     * Purpose: preserve checked type names across refresh when the
     * type is still present. Replaces the ScrolledWindow child.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void rebuildStockChecks() {
        if (stockScroll == null) {
            return()
        }
        list priorChecked = []
        int64 i = 0
        while (i < stockChecks.length) {
            Gtk.CheckButton cb = stockChecks[i]
            if (cb.active()) {
                priorChecked.append(stockLabels[i])
            }
            i = i + 1
        }
        stockChecks = []
        stockLabels = []
        Gtk.Box fresh = Gtk.Box(Gtk.Box.VERTICAL, 2)
        int64 planetId = planetIdValue()
        int64 index = 0
        int64 shown = 0
        while (index < core.view.stocks.length) {
            StockRow row = core.view.stocks[index]
            if (row.count > 0
                and (planetId < 0 or row.planetId == planetId)) {
                DesignRow design = core.view.findDesign(row.designId)
                String typeName = design.choiceLabel()
                if (typeName.length < 1) {
                    typeName = format("design {}", row.designId)
                }
                String label = format(
                    "{} — {} available", typeName, row.count)
                Gtk.CheckButton cb = Gtk.CheckButton(label)
                int64 p = 0
                while (p < priorChecked.length) {
                    String want = priorChecked[p]
                    if (want.equals(typeName)) {
                        cb.setActive(true)
                        break
                    }
                    p = p + 1
                }
                fresh.append(cb)
                stockChecks.append(cb)
                stockLabels.append(typeName)
                shown = shown + 1
            }
            index = index + 1
        }
        if (shown < 1) {
            fresh.append(Gtk.Label("(no unassigned hulls here)"))
        }
        stockScroll.setChild(fresh)
    }

    /*
     * Refresh the fleets-at-planet text list.
     *
     * Purpose: show named fleets sitting at the selected planet.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshFleetList() {
        if (fleetList == null) {
            return()
        }
        int64 planetId = planetIdValue()
        String fleets = ""
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 1
                and (planetId < 0
                    or row.locationPlanetId == planetId)) {
                fleets.append(row.listLabel())
                fleets.append("\n")
            }
            index = index + 1
        }
        if (fleets.length < 1) {
            fleets = "(no fleets at this planet)\n"
        }
        fleetList.setText(fleets)
    }

    /*
     * Rebuild fleet name choices scoped to the selected planet.
     *
     * Purpose: Assign / Un-assign / Examine target.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFleetChoices() {
        list names = []
        int64 planetId = planetIdValue()
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 1
                and (planetId < 0
                    or row.locationPlanetId == planetId)) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        fleetChoice.setChoices(names)
        String cur = fleetChoice.value()
        if (cur.length < 1 and names.length > 0) {
            fleetChoice.setValue(names[0])
        }
    }

    /*
     * Refresh the selected-fleet detail label.
     *
     * Purpose: show listLabel for the current DropDown pick.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshSelectedHint() {
        if (selectedHint == null) {
            return()
        }
        FleetRow row = core.view.findFleet(fleetIdValue())
        if (row.id < 0) {
            selectedHint.setText("(select a fleet)")
            return()
        }
        selectedHint.setText(row.listLabel())
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
     * Read the selected planet id.
     *
     * Purpose: scope stock / fleets.
     *
     * Parameters: none.
     *
     * Returns: planet id, or -1 when unresolved.
     */
    int64 planetIdValue() {
        return(core.view.resolvePlanetChoice(planetChoice.value()))
    }

    /*
     * Read the selected fleet id.
     *
     * Purpose: Examine / Assign / Un-assign fleet id.
     *
     * Parameters: none.
     *
     * Returns: fleet id, or -1 when unresolved.
     */
    int64 fleetIdValue() {
        return(core.view.resolveFleetChoice(fleetChoice.value()))
    }

    /*
     * Read assign/unassign quantity from the SpinButton.
     *
     * Purpose: PUT /assign and PUT /unassign qty field.
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

    /*
     * Collect checked stock type names.
     *
     * Purpose: multi-select Assign / Un-assign payloads.
     *
     * Parameters: none.
     *
     * Returns: list of type-name strings currently checked.
     */
    list selectedTypeNames() {
        list out = []
        int64 index = 0
        while (index < stockChecks.length) {
            Gtk.CheckButton cb = stockChecks[index]
            if (cb.active()) {
                out.append(stockLabels[index])
            }
            index = index + 1
        }
        return(out)
    }

    /*
     * Pin the fleet DropDown to a row label.
     *
     * Purpose: Examine path keeps selection across refresh.
     *
     * Parameters:
     *   label — fleet choiceLabel() text.
     *
     * Returns: nothing.
     */
    void setFleetChoice(String label) {
        fleetChoice.setValue(label)
        refreshSelectedHint()
    }
}
