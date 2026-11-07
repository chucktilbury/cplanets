/*
 * src/client/guiPlanetPage.cw — planets list + budget Scales.
 *
 * Visibility-limited planet list plus per-owned-planet allocation
 * Scale (DIALOGS §4.2). PUT /budget stores allocationPct; the
 * production tick scales empire-pool credit by pct/100.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial planets + budget chrome page.
 *   2026-11-07  Default Scale 100 matches full production.
 */

include "appCore.cw"
include "planetRow.cw"

/*
 * GuiPlanetPage owns the Planets notebook page widgets.
 *
 * Budget Entry picks a planet id; Scale sets allocationPct;
 * Apply → PUT /budget when live.
 */
class GuiPlanetPage {
    AppCore core
    Gtk.Label planetList
    Gtk.Entry planetIdEntry
    Gtk.Scale budgetScale
    Gtk.Label budgetLabel
    void<> showExploredAction
    void<> budgetAction
    void<fp64> budgetChangedAction
    bool suppressScale

    /*
     * Construct a planets page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiPlanetPage ready for buildPage.
     */
    GuiPlanetPage(AppCore appCore) {
        core = appCore
        planetList = null
        planetIdEntry = null
        budgetScale = null
        budgetLabel = null
        showExploredAction = null
        budgetAction = null
        budgetChangedAction = null
        suppressScale = false
    }

    /*
     * Build the Planets notebook page widget tree.
     *
     * Purpose: scrolled list + explored button + budget Scale.
     *
     * Parameters: none.
     *
     * Returns: page widget for Notebook.appendPage.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        planetList = Gtk.Label("(no planets)")
        planetList.setHExpand(true)
        planetList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(planetList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        Gtk.Button exploreBtn = Gtk.Button("Show first explored")
        if (showExploredAction != null) {
            exploreBtn.onClicked(showExploredAction)
        }
        page.append(exploreBtn)
        page.append(Gtk.Label(
            "Planet budget (owned; allocation %)"))
        planetIdEntry = Gtk.Entry("0")
        page.append(Gtk.Label("Planet id"))
        page.append(planetIdEntry)
        budgetLabel = Gtk.Label("Allocation % (100)")
        page.append(budgetLabel)
        budgetScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        budgetScale.configure(100.0, 0.0, 100.0, 1.0)
        if (budgetChangedAction != null) {
            budgetScale.onValueChanged(budgetChangedAction)
        }
        page.append(budgetScale)
        Gtk.Button apply = Gtk.Button("Apply budget")
        if (budgetAction != null) {
            apply.onClicked(budgetAction)
        }
        page.append(apply)
        return(page)
    }

    /*
     * Rebuild the planet list label from core.view.
     *
     * Purpose: GuiMain.refreshLists hook.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        String planets = ""
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible) {
                planets.append(row.listLabel())
                planets.append("\n")
            }
            index = index + 1
        }
        if (planets.length < 1) {
            planets = "(no visible planets)\n"
        }
        if (planetList != null) {
            planetList.setText(planets)
        }
        syncBudgetFromSelection()
    }

    /*
     * Load allocationPct for the planet id Entry into the Scale.
     *
     * Purpose: echo published budget after refresh / id edit.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncBudgetFromSelection() {
        if (budgetScale == null or planetIdEntry == null) {
            return()
        }
        int64 planetId = planetIdEntry.text().toInt64()
        PlanetRow row = core.view.findPlanet(planetId)
        int64 pct = 50
        if (row.id >= 0) {
            pct = row.allocationPct
        }
        suppressScale = true
        budgetScale.setValue(fp64(pct))
        suppressScale = false
        refreshBudgetLabel()
    }

    /*
     * Planet id from the budget Entry.
     *
     * Purpose: Apply budget handler.
     *
     * Parameters: none.
     *
     * Returns: parsed planet id (may be invalid).
     */
    int64 planetIdValue() {
        return(planetIdEntry.text().toInt64())
    }

    /*
     * Allocation % from the budget Scale.
     *
     * Purpose: Apply budget handler.
     *
     * Parameters: none.
     *
     * Returns: nearest 0..100 int.
     */
    int64 allocationValue() {
        int64 pct = int64(budgetScale.value() + 0.5)
        if (pct < 0) {
            return(0)
        }
        if (pct > 100) {
            return(100)
        }
        return(pct)
    }

    /*
     * Refresh the allocation caption from the Scale.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshBudgetLabel() {
        if (budgetLabel == null) {
            return()
        }
        budgetLabel.setText(format(
            "Allocation % ({})", allocationValue()))
    }

    /*
     * Budget Scale moved.
     *
     * Purpose: Gtk.Scale.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onBudgetChanged(fp64 value) {
        if (suppressScale) {
            return()
        }
        refreshBudgetLabel()
    }
}
