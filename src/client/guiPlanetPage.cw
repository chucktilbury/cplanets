/*
 * src/client/guiPlanetPage.cw — planets list + budget Scales.
 *
 * Visibility-limited planet list plus per-owned-planet allocation
 * Scale (DIALOGS §4.2). PUT /budget stores allocationPct; the
 * production tick scales empire-pool credit by pct/100. Hosted in
 * the Planets menubar non-modal panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial planets + budget chrome page.
 *   2026-11-07  Default Scale 100 matches full production.
 *   2026-11-07  Map ContextMenu: setPlanetId for budget Entry.
 *   2026-11-09  Hosted in View→Planets panel dialog.
 *   2026-11-09  Menubar opener is Planets→Open (not View).
 *   2026-11-09  Planet id choice row + tooltips (View usable).
 */

include "appCore.cw"
include "guiChoiceRow.cw"
include "planetRow.cw"

/*
 * GuiPlanetPage owns the Planets panel dialog widgets.
 *
 * Planet id uses GuiChoiceRow; Scale sets allocationPct;
 * Apply → PUT /budget when live.
 */
class GuiPlanetPage {
    AppCore core
    Gtk.Label planetList
    GuiChoiceRow planetChoice
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
        planetChoice = GuiChoiceRow()
        budgetScale = null
        budgetLabel = null
        showExploredAction = null
        budgetAction = null
        budgetChangedAction = null
        suppressScale = false
    }

    /*
     * Build the Planets panel dialog widget tree.
     *
     * Purpose: scrolled list + explored button + budget Scale.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        planetList = Gtk.Label("(no planets)")
        planetList.setHExpand(true)
        planetList.setVExpand(true)
        planetList.setTooltip(
            "Visible planets for this seat (server publish flags).")
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(planetList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        Gtk.Button exploreBtn = Gtk.Button("Show first explored")
        exploreBtn.setTooltip(
            "Open the explored-planet dialog for the first known rock.")
        if (showExploredAction != null) {
            exploreBtn.onClicked(showExploredAction)
        }
        page.append(exploreBtn)
        page.append(Gtk.Label(
            "Planet budget (owned; allocation %)"))
        page.append(Gtk.Label("Planet id"))
        page.append(planetChoice.buildWidget(
            "Cycle visible planets (owned rocks for Apply budget)."))
        budgetLabel = Gtk.Label("Allocation % (100)")
        budgetLabel.setTooltip(
            "Production fraction for this rock (default 100).")
        page.append(budgetLabel)
        budgetScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        budgetScale.configure(100.0, 0.0, 100.0, 1.0)
        budgetScale.setTooltip(
            "Allocation % — slider stand-in for a spin (0–100).")
        if (budgetChangedAction != null) {
            budgetScale.onValueChanged(budgetChangedAction)
        }
        page.append(budgetScale)
        Gtk.Button apply = Gtk.Button("Apply budget")
        apply.setTooltip("PUT /budget for the selected owned planet.")
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
        syncPlanetChoices()
        syncBudgetFromSelection()
    }

    /*
     * Rebuild planet id choices from visible rocks.
     *
     * Purpose: Combo stand-in for the budget Entry.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncPlanetChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible and row.id >= 0) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        planetChoice.setChoices(ids)
    }

    /*
     * Load allocationPct for the selected planet into the Scale.
     *
     * Purpose: echo published budget after refresh / id change.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncBudgetFromSelection() {
        if (budgetScale == null) {
            return()
        }
        int64 planetId = planetIdValue()
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
     * Planet choice stepped — reload allocation Scale.
     *
     * Purpose: GuiChoiceRow.changedAction.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onPlanetChoiceChanged() {
        syncBudgetFromSelection()
    }

    /*
     * Planet id from the budget choice row.
     *
     * Purpose: Apply budget handler.
     *
     * Parameters: none.
     *
     * Returns: selected planet id (may be 0 when empty).
     */
    int64 planetIdValue() {
        return(planetChoice.intValue())
    }

    /*
     * Write the budget planet choice from a map pick.
     *
     * Purpose: GuiMapPage ContextMenu "Budget this planet" fills
     * the Planets panel allocation chrome without a second budget
     * surface.
     *
     * Parameters:
     *   planetId — rock id to load into the choice / Scale.
     *
     * Returns: nothing.
     */
    void setPlanetId(int64 planetId) {
        String text = format("{}", planetId)
        if (not planetChoice.setValue(text)) {
            list ids = []
            ids.append(text)
            int64 index = 0
            while (index < planetChoice.choices.length) {
                String item = planetChoice.choices[index]
                if (not item.equals(text)) {
                    ids.append(item)
                }
                index = index + 1
            }
            planetChoice.setChoices(ids)
            planetChoice.setValue(text)
        }
        syncBudgetFromSelection()
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
