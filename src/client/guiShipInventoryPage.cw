/*
 * src/client/guiShipInventoryPage.cw — Ships→Inventory dialog page.
 *
 * Type inventory (specs + unassigned available) with a selectable
 * design DropDown. Dialog Apply opens Examine for the selection
 * (CPL-110 / CPL-101).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Ships Inventory dialog page.
 */

include "appCore.cw"
include "designRow.cw"
include "guiChoiceRow.cw"

/*
 * GuiShipInventoryPage owns Ships→Inventory dialog widgets.
 *
 * Select a ship type by name; Apply examines it. List shows type
 * inventory with specs and available unassigned counts.
 */
class GuiShipInventoryPage {
    AppCore core
    Gtk.Label designList
    Gtk.Label yardHint
    GuiChoiceRow designChoice
    Gtk.Label selectedHint

    /*
     * Construct an Inventory page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiShipInventoryPage ready for buildPage.
     */
    GuiShipInventoryPage(AppCore appCore) {
        core = appCore
        designList = null
        yardHint = null
        designChoice = GuiChoiceRow()
        selectedHint = null
    }

    /*
     * Build the Ships Inventory dialog widget tree.
     *
     * Purpose: inventory list + selectable type + selected detail.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        designList = Gtk.Label("(no ship types)")
        designList.setHExpand(true)
        designList.setVExpand(true)
        designList.setTooltip(
            "Ship inventory: type name, specs, unassigned available.")
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(designList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(Gtk.Label(
            "Ship inventory (type + specs + available)"))
        page.append(scroll)
        yardHint = Gtk.Label("(yards)")
        yardHint.setHExpand(true)
        yardHint.setTooltip("Owned shipyard planets.")
        page.append(yardHint)
        page.append(Gtk.Label("Select ship type"))
        page.append(designChoice.buildWidget(
            "Catalog ship types by name — Apply examines selection."))
        selectedHint = Gtk.Label("(select a type)")
        selectedHint.setHExpand(true)
        selectedHint.setTooltip(
            "Selected type summary; Apply opens Examine.")
        page.append(selectedHint)
        return(page)
    }

    /*
     * Refresh inventory list / choices / selected hint.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (designList != null) {
            designList.setText(core.view.inventoryByTypeText())
        }
        if (yardHint != null) {
            yardHint.setText(core.view.yardPlanetsText())
        }
        syncDesignChoices()
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
        designChoice.bindSelected(designChoice.onSelected)
    }

    /*
     * Rebuild design name choices from the catalog.
     *
     * Purpose: DropDown by ship type name for Examine.
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
            if (row.id >= 0) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        designChoice.setChoices(names)
    }

    /*
     * Refresh the selected-type detail label.
     *
     * Purpose: show specs for the current DropDown pick.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshSelectedHint() {
        if (selectedHint == null) {
            return()
        }
        DesignRow row = core.view.findDesign(designIdValue())
        if (row.id < 0) {
            selectedHint.setText("(select a type)")
            return()
        }
        selectedHint.setText(row.listLabel())
    }

    /*
     * Read the design id choice.
     *
     * Purpose: Examine design id (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: design id, or -1 when unresolved.
     */
    int64 designIdValue() {
        return(core.view.resolveDesignChoice(designChoice.value()))
    }

    /*
     * Pin the design DropDown to a row label.
     *
     * Purpose: Examine path keeps selection across refresh.
     *
     * Parameters:
     *   label — design choiceLabel() text.
     *
     * Returns: nothing.
     */
    void setDesignChoice(String label) {
        designChoice.setValue(label)
        refreshSelectedHint()
    }
}
