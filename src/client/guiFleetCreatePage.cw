/*
 * src/client/guiFleetCreatePage.cw — Fleets→Create dialog page.
 *
 * Named empty fleet at an owned planet. Dialog Apply → PUT /fleet
 * (CPL-110 / CPL-101).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Create dialog page (split from fleet page).
 */

include "appCore.cw"
include "guiChoiceRow.cw"
include "planetRow.cw"

/*
 * GuiFleetCreatePage owns Fleets→Create dialog widgets.
 *
 * Apply creates an empty sitting named fleet at the park planet.
 */
class GuiFleetCreatePage {
    AppCore core
    Gtk.Entry createNameEntry
    GuiChoiceRow createPlanetChoice

    /*
     * Construct a Create page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetCreatePage ready for buildPage.
     */
    GuiFleetCreatePage(AppCore appCore) {
        core = appCore
        createNameEntry = null
        createPlanetChoice = GuiChoiceRow()
    }

    /*
     * Build the Create dialog widget tree.
     *
     * Purpose: name Entry + park planet DropDown.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label("Create named fleet (empty)"))
        createNameEntry = Gtk.Entry("fleet-1")
        createNameEntry.setTooltip(
            "Unique per-seat fleet name for PUT /fleet.")
        page.append(Gtk.Label("Fleet name"))
        page.append(createNameEntry)
        page.append(Gtk.Label("Park at planet"))
        page.append(createPlanetChoice.buildWidget(
            "Owned planet where the empty fleet sits (yard OK)."))
        return(page)
    }

    /*
     * Refresh create-planet choices from owned rocks.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        syncCreatePlanetChoices()
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
        createPlanetChoice.bindSelected(createPlanetChoice.onSelected)
    }

    /*
     * Rebuild create-fleet planet choices from owned rocks.
     *
     * Purpose: prefer home yard when current pick is empty/stale.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncCreatePlanetChoices() {
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
        createPlanetChoice.setChoices(names)
        int64 homeYard = core.view.firstOwnedYardId()
        if (homeYard >= 0) {
            PlanetRow home = core.view.findPlanet(homeYard)
            String homeLabel = home.choiceLabel()
            String cur = createPlanetChoice.value()
            if (cur.length < 1) {
                createPlanetChoice.setValue(homeLabel)
            } else {
                PlanetRow pick = core.view.findPlanetByName(cur)
                if (pick.id < 0
                    or pick.ownerId != core.view.viewerId) {
                    createPlanetChoice.setValue(homeLabel)
                }
            }
        }
    }

    /*
     * Read the create-fleet name Entry.
     *
     * Purpose: PUT /fleet name field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String createNameValue() {
        if (createNameEntry == null) {
            return("")
        }
        return(createNameEntry.text())
    }

    /*
     * Read the create-fleet park planet id.
     *
     * Purpose: PUT /fleet planet field (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: planet id, or -1 when unresolved.
     */
    int64 createPlanetValue() {
        return(core.view.resolvePlanetChoice(
            createPlanetChoice.value()))
    }
}
