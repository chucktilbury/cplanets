/*
 * src/client/guiFleetInventoryPage.cw — Fleets→Inventory dialog page.
 *
 * Named fleets + unassigned stock lines with a selectable fleet
 * DropDown. Dialog Apply opens Examine for the selection
 * (CPL-110 / CPL-101).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Fleets Inventory dialog page.
 */

include "appCore.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"

/*
 * GuiFleetInventoryPage owns Fleets→Inventory dialog widgets.
 *
 * Select a named fleet; Apply examines it. Lists show unassigned
 * stock separately from assigned fleets.
 */
class GuiFleetInventoryPage {
    AppCore core
    Gtk.Label stockList
    Gtk.Label fleetList
    GuiChoiceRow fleetChoice
    Gtk.Label selectedHint

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
        stockList = null
        fleetList = null
        fleetChoice = GuiChoiceRow()
        selectedHint = null
    }

    /*
     * Build the Fleets Inventory dialog widget tree.
     *
     * Purpose: stock + fleet lists + selectable fleet detail.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label("Unassigned stock (not a fleet)"))
        stockList = Gtk.Label("(no unassigned hulls)")
        stockList.setHExpand(true)
        stockList.setTooltip(
            "Hulls staged at yard planets until assign.")
        page.append(stockList)
        page.append(Gtk.Label("Named fleets"))
        fleetList = Gtk.Label("(no fleets)")
        fleetList.setHExpand(true)
        fleetList.setVExpand(true)
        fleetList.setTooltip(
            "Visible fleets for this seat (server publish flags).")
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(fleetList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        page.append(Gtk.Label("Select fleet"))
        page.append(fleetChoice.buildWidget(
            "Owned fleets by name — Apply examines selection."))
        selectedHint = Gtk.Label("(select a fleet)")
        selectedHint.setHExpand(true)
        selectedHint.setTooltip(
            "Selected fleet summary; Apply opens Examine.")
        page.append(selectedHint)
        return(page)
    }

    /*
     * Refresh stock / fleet lists / choices / selected hint.
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
        syncFleetChoices()
        refreshSelectedHint()
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
        fleetChoice.bindSelected(fleetChoice.onSelected)
    }

    /*
     * Rebuild fleet name choices from owned visible fleets.
     *
     * Purpose: DropDown by fleet name for Examine.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFleetChoices() {
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
     * Read the selected fleet id.
     *
     * Purpose: Examine fleet id (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: fleet id, or -1 when unresolved.
     */
    int64 fleetIdValue() {
        return(core.view.resolveFleetChoice(fleetChoice.value()))
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
