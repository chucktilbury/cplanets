/*
 * src/client/guiPlanetPage.cw — planets list + budget SpinButton.
 *
 * Visibility-limited planet list plus per-owned-planet allocation
 * SpinButton (DIALOGS §4.2). PUT /budget stores allocationPct; the
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
 *   2026-11-09  Menubar opener is root Planets click (no Open submenu).
 *   2026-11-09  Planet id choice row + tooltips (View usable).
 *   2026-11-09  DropDown + SpinButton replace GuiChoiceRow/Scale stand-ins.
 *   2026-11-10  Planet DropDown by name (Home / Planet N).
 */

include "appCore.cw"
include "guiChoiceRow.cw"
include "planetRow.cw"

/*
 * GuiPlanetPage owns the Planets panel dialog widgets.
 *
 * Planet id uses GuiChoiceRow (DropDown); SpinButton sets
 * allocationPct; Apply → PUT /budget when live.
 */
class GuiPlanetPage {
    AppCore core
    Gtk.Label planetList
    GuiChoiceRow planetChoice
    Gtk.SpinButton budgetSpin
    Gtk.Label budgetLabel
    void<> showExploredAction
    void<> budgetAction
    void<fp64> budgetChangedAction
    bool suppressSpin

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
        budgetSpin = null
        budgetLabel = null
        showExploredAction = null
        budgetAction = null
        budgetChangedAction = null
        suppressSpin = false
    }

    /*
     * Build the Planets panel dialog widget tree.
     *
     * Purpose: scrolled list + explored button + budget SpinButton.
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
        page.append(Gtk.Label("Planet"))
        page.append(planetChoice.buildWidget(
            "Select a visible planet (owned rocks for Apply budget)."))
        budgetLabel = Gtk.Label("Allocation % (100)")
        budgetLabel.setTooltip(
            "Production fraction for this rock (default 100).")
        page.append(budgetLabel)
        budgetSpin = Gtk.SpinButton()
        budgetSpin.configure(100.0, 0.0, 100.0, 1.0)
        budgetSpin.setTooltip("Allocation % (0–100).")
        if (budgetChangedAction != null) {
            budgetSpin.onValueChanged(budgetChangedAction)
        }
        page.append(budgetSpin)
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
     * Purpose: DropDown for the budget planet picker.
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
            if (row.visible and row.id >= 0) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        planetChoice.setChoices(names)
    }

    /*
     * Load allocationPct for the selected planet into the SpinButton.
     *
     * Purpose: echo published budget after refresh / id change.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncBudgetFromSelection() {
        if (budgetSpin == null) {
            return()
        }
        int64 planetId = planetIdValue()
        PlanetRow row = core.view.findPlanet(planetId)
        int64 pct = 50
        if (row.id >= 0) {
            pct = row.allocationPct
        }
        suppressSpin = true
        budgetSpin.setValue(fp64(pct))
        suppressSpin = false
        refreshBudgetLabel()
    }

    /*
     * Planet choice changed — reload allocation SpinButton.
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
     * Planet id from the budget DropDown.
     *
     * Purpose: Apply budget handler (resolve name → id).
     *
     * Parameters: none.
     *
     * Returns: selected planet id, or -1 when unresolved.
     */
    int64 planetIdValue() {
        return(core.view.resolvePlanetChoice(planetChoice.value()))
    }

    /*
     * Write the budget planet choice from a map pick.
     *
     * Purpose: GuiMapPage ContextMenu "Budget this planet" fills
     * the Planets panel allocation chrome without a second budget
     * surface.
     *
     * Parameters:
     *   planetId — rock id to load into the choice / SpinButton.
     *
     * Returns: nothing.
     */
    void setPlanetId(int64 planetId) {
        PlanetRow row = core.view.findPlanet(planetId)
        String text = row.choiceLabel()
        if (text.length < 1) {
            text = format("Planet {}", planetId)
        }
        if (not planetChoice.setValue(text)) {
            list names = []
            names.append(text)
            int64 index = 0
            while (index < planetChoice.pendingChoices.length) {
                String item = planetChoice.pendingChoices[index]
                if (not item.equals(text)) {
                    names.append(item)
                }
                index = index + 1
            }
            planetChoice.setChoices(names)
            planetChoice.setValue(text)
        }
        syncBudgetFromSelection()
    }

    /*
     * Allocation % from the budget SpinButton.
     *
     * Purpose: Apply budget handler.
     *
     * Parameters: none.
     *
     * Returns: nearest 0..100 int.
     */
    int64 allocationValue() {
        int64 pct = int64(budgetSpin.value() + 0.5)
        if (pct < 0) {
            return(0)
        }
        if (pct > 100) {
            return(100)
        }
        return(pct)
    }

    /*
     * Refresh the allocation caption from the SpinButton.
     *
     * Purpose: live label next to the spin.
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
     * Budget SpinButton moved.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new spin value.
     *
     * Returns: nothing.
     */
    void onBudgetChanged(fp64 value) {
        if (suppressSpin) {
            return()
        }
        refreshBudgetLabel()
    }
}
