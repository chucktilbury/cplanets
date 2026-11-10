/*
 * src/client/guiShipBuildPage.cw — Ships→Build dialog page.
 *
 * Yard planet + ship type DropDowns. Dialog Apply queues PUT
 * /build; ProgressBar tracks yard-build ticks (CPL-110).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Build dialog page (split from yard page).
 */

include "appCore.cw"
include "designRow.cw"
include "guiChoiceRow.cw"
include "guiProgressChrome.cw"
include "planetRow.cw"

/*
 * GuiShipBuildPage owns Ships→Build dialog widgets.
 *
 * Apply (dialog footer) → PUT /build at a productive owned yard.
 * Completed hulls stage as unassigned stock (CPL-101).
 */
class GuiShipBuildPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Label yardHint
    GuiChoiceRow planetChoice
    GuiChoiceRow designChoice

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
    }

    /*
     * Build the Build dialog widget tree.
     *
     * Purpose: yard/type picks + build ProgressBar.
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
        page.append(Gtk.Label("Ship type"))
        page.append(designChoice.buildWidget(
            "Catalog ship types by name for build."))
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Refresh yards / choices / build ProgressBar.
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
     * Rebuild design name choices from the catalog.
     *
     * Purpose: DropDown by ship type name for Queue build.
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
}
