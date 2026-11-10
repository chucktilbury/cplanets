/*
 * src/client/guiFleetAssignPage.cw — Fleets→Assign dialog page.
 *
 * Move type+qty from unassigned stock into a sitting fleet.
 * Dialog Apply → PUT /assign; over-assign → error dialog
 * (CPL-110 / CPL-101).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Assign dialog page (split from fleet page).
 */

include "appCore.cw"
include "designRow.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"
include "guiScaleRange.cw"

/*
 * GuiFleetAssignPage owns Fleets→Assign dialog widgets.
 *
 * Apply assigns type name + quantity from unassigned stock at the
 * fleet's location planet into that fleet.
 */
class GuiFleetAssignPage {
    AppCore core
    Gtk.Label stockList
    GuiChoiceRow assignFleetChoice
    GuiChoiceRow assignTypeChoice
    Gtk.SpinButton assignQtySpin
    Gtk.Label assignQtyLabel
    void<fp64> assignQtyChangedAction
    bool suppressAssignQty

    /*
     * Construct an Assign page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetAssignPage ready for buildPage.
     */
    GuiFleetAssignPage(AppCore appCore) {
        core = appCore
        stockList = null
        assignFleetChoice = GuiChoiceRow()
        assignTypeChoice = GuiChoiceRow()
        assignQtySpin = null
        assignQtyLabel = null
        assignQtyChangedAction = null
        suppressAssignQty = false
    }

    /*
     * Build the Assign dialog widget tree.
     *
     * Purpose: stock hint + fleet/type/qty controls.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label("Unassigned stock (same planet as fleet)"))
        stockList = Gtk.Label("(no unassigned hulls)")
        stockList.setHExpand(true)
        stockList.setTooltip(
            "Hulls staged at yard planets until assign.")
        page.append(stockList)
        page.append(Gtk.Label("Fleet"))
        page.append(assignFleetChoice.buildWidget(
            "Sitting owned fleet to fill from stock at its location."))
        page.append(Gtk.Label("Ship type"))
        page.append(assignTypeChoice.buildWidget(
            "Ship type name to assign from unassigned stock."))
        assignQtyLabel = Gtk.Label("Qty (1)")
        assignQtyLabel.setTooltip(
            "Hulls to move from unassigned stock into the fleet.")
        page.append(assignQtyLabel)
        assignQtySpin = Gtk.SpinButton()
        GuiScaleRange initAssign = GuiScaleRange()
        initAssign.normalize(1.0, 1.0, 1.0, 1.0)
        assignQtySpin.configure(
            initAssign.value, initAssign.lower, initAssign.upper,
            initAssign.step)
        assignQtySpin.setTooltip("Assign quantity (over-assign rejects).")
        if (assignQtyChangedAction != null) {
            assignQtySpin.onValueChanged(assignQtyChangedAction)
        }
        page.append(assignQtySpin)
        return(page)
    }

    /*
     * Refresh stock list / choices / qty Spin.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (stockList != null) {
            stockList.setText(core.view.stocksListText())
        }
        syncAssignFleetChoices()
        syncAssignTypeChoices()
        syncAssignQtySpin()
    }

    /*
     * Bind DropDown / Spin handlers.
     *
     * Purpose: GuiMain activate wiring.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void bindChoices() {
        assignFleetChoice.bindSelected(assignFleetChoice.onSelected)
        assignTypeChoice.bindSelected(assignTypeChoice.onSelected)
    }

    /*
     * Rebuild assign fleet choices from owned fleets.
     *
     * Purpose: assign chrome fleet name DropDown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAssignFleetChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 1) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        assignFleetChoice.setChoices(names)
        String cur = assignFleetChoice.value()
        if (cur.length < 1 and names.length > 0) {
            assignFleetChoice.setValue(names[0])
        }
    }

    /*
     * Rebuild assign ship-type choices from the design catalog.
     *
     * Purpose: assign chrome lists types by name (not design id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAssignTypeChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.designs.length) {
            DesignRow row = core.view.designs[index]
            if (row.id >= 0 and not row.closed) {
                String label = row.choiceLabel()
                if (label.length > 0) {
                    names.append(label)
                }
            }
            index = index + 1
        }
        assignTypeChoice.setChoices(names)
        String cur = assignTypeChoice.value()
        if (cur.length < 1 and names.length > 0) {
            assignTypeChoice.setValue(names[0])
        }
    }

    /*
     * Reconfigure assign qty SpinButton (1..reasonable).
     *
     * Purpose: keep a usable range; over-assign is still a server
     * reject shown via AlertDialog.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAssignQtySpin() {
        if (assignQtySpin == null) {
            return()
        }
        fp64 cur = assignQtySpin.value()
        GuiScaleRange qtyRange = GuiScaleRange()
        qtyRange.normalize(cur, 1.0, 99.0, 1.0)
        if (qtyRange.value < 1.0) {
            qtyRange.value = 1.0
        }
        suppressAssignQty = true
        assignQtySpin.configure(
            qtyRange.value, qtyRange.lower, qtyRange.upper,
            qtyRange.step)
        suppressAssignQty = false
        refreshAssignQtyLabel()
    }

    /*
     * Assign qty SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onAssignQtyChanged(fp64 value) {
        if (suppressAssignQty) {
            return()
        }
        refreshAssignQtyLabel()
    }

    /*
     * Refresh assign qty caption from the SpinButton.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshAssignQtyLabel() {
        if (assignQtyLabel == null) {
            return()
        }
        assignQtyLabel.setText(format(
            "Qty ({})", assignQtyValue()))
    }

    /*
     * Read the assign fleet id.
     *
     * Purpose: PUT /assign fleet field (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: fleet id, or -1 when unresolved.
     */
    int64 assignFleetValue() {
        return(core.view.resolveFleetChoice(
            assignFleetChoice.value()))
    }

    /*
     * Read the assign type name DropDown.
     *
     * Purpose: PUT /assign typeName field.
     *
     * Parameters: none.
     *
     * Returns: selected design / type name.
     */
    String assignTypeValue() {
        return(assignTypeChoice.value())
    }

    /*
     * Read assign quantity from the SpinButton.
     *
     * Purpose: PUT /assign qty field.
     *
     * Parameters: none.
     *
     * Returns: hull count (>= 1 when SpinButton exists).
     */
    int64 assignQtyValue() {
        if (assignQtySpin == null) {
            return(1)
        }
        int64 qty = int64(assignQtySpin.value() + 0.5)
        if (qty < 1) {
            return(1)
        }
        return(qty)
    }
}
