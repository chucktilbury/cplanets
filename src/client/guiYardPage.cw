/*
 * src/client/guiYardPage.cw — Ships panel design / yard chrome.
 *
 * Design develop + yard build / reclaim (DIALOGS §6). Kind / yard /
 * design / reclaim-fleet use GuiChoiceRow (DropDown); reclaim hulls
 * use a SpinButton. Float fields stay Entries. Progress
 * footer uses Gtk.ProgressBar. Hosted in Ships menubar panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial Ships notebook page.
 *   2026-11-07  Refresh keeps Yard planet id on first owned yard
 *               (home 0) when the Entry is empty or stale.
 *   2026-11-08  GuiProgressChrome ProgressBars for develop/build.
 *   2026-11-09  Examine design button → GuiShipDialog.
 *   2026-11-09  Hosted in View→Ships panel dialog.
 *   2026-11-09  Menubar opener is root Ships click (no Open submenu).
 *   2026-11-09  Choice rows + reclaim Scale + tooltips (usable).
 *   2026-11-09  Safe Scale range via GuiScaleRange (empty/1 hull).
 *   2026-11-10  CPL-101: inventory by type+specs+available;
 *               reclaim-stock chrome (design+planet+qty).
 */

include "appCore.cw"
include "designRow.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"
include "guiProgressChrome.cw"
include "guiScaleRange.cw"
include "planetRow.cw"
include "stockRow.cw"

/*
 * GuiYardPage owns the Ships panel dialog widgets.
 *
 * Start develop → PUT /design; Queue build → PUT /build;
 * Reclaim stock → PUT /reclaim-stock (preferred for unassigned);
 * Reclaim hulls → PUT /reclaim-hulls for sitting fleets. Lists show
 * inventory by type, owned yards, and active progress.
 */
class GuiYardPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Label designList
    Gtk.Label yardHint
    Gtk.Entry nameEntry
    Gtk.Entry speedEntry
    Gtk.Entry hopEntry
    Gtk.Entry sizeEntry
    Gtk.Entry cargoEntry
    GuiChoiceRow kindChoice
    GuiChoiceRow planetChoice
    GuiChoiceRow designChoice
    GuiChoiceRow reclaimStockDesignChoice
    Gtk.SpinButton reclaimStockHullsSpin
    Gtk.Label reclaimStockHullsLabel
    Gtk.Button reclaimStockBtn
    GuiChoiceRow reclaimFleetChoice
    Gtk.SpinButton reclaimHullsSpin
    Gtk.Label reclaimHullsLabel
    Gtk.Button developBtn
    Gtk.Button buildBtn
    Gtk.Button reclaimBtn
    Gtk.Button examineBtn
    void<> developAction
    void<> buildAction
    void<> reclaimStockAction
    void<> reclaimAction
    void<> examineAction
    void<fp64> reclaimHullsChangedAction
    void<fp64> reclaimStockHullsChangedAction
    bool suppressHulls
    bool suppressStockHulls

    /*
     * Construct a Ships page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiYardPage ready for buildPage.
     */
    GuiYardPage(AppCore appCore) {
        core = appCore
        progressChrome = GuiProgressChrome(appCore)
        designList = null
        yardHint = null
        nameEntry = null
        speedEntry = null
        hopEntry = null
        sizeEntry = null
        cargoEntry = null
        kindChoice = GuiChoiceRow()
        planetChoice = GuiChoiceRow()
        designChoice = GuiChoiceRow()
        reclaimStockDesignChoice = GuiChoiceRow()
        reclaimStockHullsSpin = null
        reclaimStockHullsLabel = null
        reclaimStockBtn = null
        reclaimFleetChoice = GuiChoiceRow()
        reclaimHullsSpin = null
        reclaimHullsLabel = null
        developBtn = null
        buildBtn = null
        reclaimBtn = null
        examineBtn = null
        developAction = null
        buildAction = null
        reclaimStockAction = null
        reclaimAction = null
        examineAction = null
        reclaimHullsChangedAction = null
        reclaimStockHullsChangedAction = null
        suppressHulls = false
        suppressStockHulls = false
    }

    /*
     * Build the Ships panel dialog widget tree.
     *
     * Purpose: design list + editor + yard/reclaim + ProgressBars.
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
        examineBtn = Gtk.Button("Examine design")
        examineBtn.setTooltip(
            "Open TransientWindow inspect for the selected design.")
        if (examineAction != null) {
            examineBtn.onClicked(examineAction)
        }
        page.append(examineBtn)
        yardHint = Gtk.Label("(yards)")
        yardHint.setHExpand(true)
        yardHint.setTooltip("Owned shipyard planets.")
        page.append(yardHint)
        page.append(Gtk.Label(
            "Start design develop (wealth; timed)"))
        nameEntry = Gtk.Entry("custom")
        nameEntry.setTooltip("New design name.")
        speedEntry = Gtk.Entry("1.0")
        speedEntry.setTooltip("Design speed (float).")
        hopEntry = Gtk.Entry("5.0")
        hopEntry.setTooltip("Hop reach distance (float).")
        sizeEntry = Gtk.Entry("1.0")
        sizeEntry.setTooltip("Size / cost basis (float).")
        cargoEntry = Gtk.Entry("0.0")
        cargoEntry.setTooltip("Cargo hold capacity (float).")
        kindChoice.setChoices(kindChoices())
        kindChoice.setValue("war")
        page.append(Gtk.Label("Name"))
        page.append(nameEntry)
        page.append(Gtk.Label("Speed"))
        page.append(speedEntry)
        page.append(Gtk.Label("Hop reach"))
        page.append(hopEntry)
        page.append(Gtk.Label("Size (cost basis)"))
        page.append(sizeEntry)
        page.append(Gtk.Label("Cargo hold"))
        page.append(cargoEntry)
        page.append(Gtk.Label("Kind (scout/colony/defense/war)"))
        page.append(kindChoice.buildWidget(
            "Design kind: scout, colony, defense, or war."))
        developBtn = Gtk.Button("Start develop")
        developBtn.setTooltip(
            "PUT /design — queue timed wealth development.")
        if (developAction != null) {
            developBtn.onClicked(developAction)
        }
        page.append(developBtn)
        page.append(Gtk.Label(
            "Yard build (resources; timed; productive yard)"))
        page.append(Gtk.Label("Yard planet id"))
        page.append(planetChoice.buildWidget(
            "Cycle owned shipyard planets for Queue build."))
        page.append(Gtk.Label("Ready design id"))
        page.append(designChoice.buildWidget(
            "Cycle catalog designs for build / examine."))
        buildBtn = Gtk.Button("Queue build")
        buildBtn.setTooltip(
            "PUT /build — queue timed yard hull production.")
        if (buildAction != null) {
            buildBtn.onClicked(buildAction)
        }
        page.append(buildBtn)
        page.append(Gtk.Label(
            "Reclaim unassigned stock (design + yard + qty)"))
        page.append(Gtk.Label("Stock design id"))
        page.append(reclaimStockDesignChoice.buildWidget(
            "Cycle designs that have unassigned stock to reclaim."))
        reclaimStockHullsLabel = Gtk.Label("Stock hulls (1)")
        reclaimStockHullsLabel.setTooltip(
            "How many unassigned hulls to reclaim at the yard planet.")
        page.append(reclaimStockHullsLabel)
        reclaimStockHullsSpin = Gtk.SpinButton()
        GuiScaleRange initStockHulls = GuiScaleRange()
        initStockHulls.normalize(1.0, 1.0, 1.0, 1.0)
        reclaimStockHullsSpin.configure(
            initStockHulls.value, initStockHulls.lower,
            initStockHulls.upper, initStockHulls.step)
        reclaimStockHullsSpin.setTooltip(
            "Reclaim-stock hull count — SpinButton.")
        if (reclaimStockHullsChangedAction != null) {
            reclaimStockHullsSpin.onValueChanged(
                reclaimStockHullsChangedAction)
        }
        page.append(reclaimStockHullsSpin)
        reclaimStockBtn = Gtk.Button("Reclaim stock")
        reclaimStockBtn.setTooltip(
            "PUT /reclaim-stock for unassigned hulls at the yard.")
        if (reclaimStockAction != null) {
            reclaimStockBtn.onClicked(reclaimStockAction)
        }
        page.append(reclaimStockBtn)
        page.append(Gtk.Label(
            "Reclaim assigned hulls (sitting fleet at yard)"))
        page.append(Gtk.Label("Fleet id"))
        page.append(reclaimFleetChoice.buildWidget(
            "Cycle owned fleets eligible for reclaim."))
        reclaimHullsLabel = Gtk.Label("Hulls (1)")
        reclaimHullsLabel.setTooltip(
            "How many hulls to reclaim from the sitting fleet.")
        page.append(reclaimHullsLabel)
        reclaimHullsSpin = Gtk.SpinButton()
        GuiScaleRange initHulls = GuiScaleRange()
        initHulls.normalize(1.0, 1.0, 1.0, 1.0)
        reclaimHullsSpin.configure(
            initHulls.value, initHulls.lower, initHulls.upper,
            initHulls.step)
        reclaimHullsSpin.setTooltip(
            "Reclaim hull count — SpinButton.")
        if (reclaimHullsChangedAction != null) {
            reclaimHullsSpin.onValueChanged(reclaimHullsChangedAction)
        }
        page.append(reclaimHullsSpin)
        reclaimBtn = Gtk.Button("Reclaim hulls")
        reclaimBtn.setTooltip(
            "PUT /reclaim-hulls at a productive shipyard.")
        if (reclaimAction != null) {
            reclaimBtn.onClicked(reclaimAction)
        }
        page.append(reclaimBtn)
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Fixed design kind list.
     *
     * Purpose: kindChoice seed.
     *
     * Parameters: none.
     *
     * Returns: list of kind strings.
     */
    list kindChoices() {
        list out = []
        out.append("scout")
        out.append("colony")
        out.append("defense")
        out.append("war")
        return(out)
    }

    /*
     * Refresh design list / yards / choices / progress.
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
        if (progressChrome != null) {
            progressChrome.refresh()
        }
        syncYardPlanetChoices()
        syncDesignChoices()
        syncReclaimStockDesignChoices()
        syncReclaimStockHullsSpin()
        syncReclaimFleetChoices()
        syncReclaimHullsSpin()
    }

    /*
     * Rebuild yard planet choices from owned shipyards.
     *
     * Purpose: Combo stand-in; prefer first owned yard.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncYardPlanetChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible
                and row.shipyard
                and row.ownerId == core.view.viewerId) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        planetChoice.setChoices(ids)
        int64 homeYard = core.view.firstOwnedYardId()
        if (homeYard >= 0) {
            String cur = planetChoice.value()
            if (cur.length < 1
                or not core.view.isOwnedYard(cur.toInt64())) {
                planetChoice.setValue(format("{}", homeYard))
            }
        }
    }

    /*
     * Rebuild design id choices from the catalog.
     *
     * Purpose: Combo stand-in for Examine / Queue build.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncDesignChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.designs.length) {
            DesignRow row = core.view.designs[index]
            if (row.id >= 0) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        designChoice.setChoices(ids)
    }

    /*
     * Rebuild reclaim-stock design choices from catalog.
     *
     * Purpose: prefer designs that currently have unassigned stock.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimStockDesignChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.designs.length) {
            DesignRow row = core.view.designs[index]
            if (row.id >= 0
                and not row.closed
                and core.view.stockCountForDesign(row.id) > 0) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        if (ids.length < 1) {
            index = 0
            while (index < core.view.designs.length) {
                DesignRow row = core.view.designs[index]
                if (row.id >= 0) {
                    ids.append(format("{}", row.id))
                }
                index = index + 1
            }
        }
        reclaimStockDesignChoice.setChoices(ids)
    }

    /*
     * Reconfigure reclaim-stock hulls SpinButton from stock count.
     *
     * Purpose: clamp to available unassigned at the selected yard.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimStockHullsSpin() {
        if (reclaimStockHullsSpin == null) {
            return()
        }
        int64 designId = reclaimStockDesignValue()
        int64 planetId = planetValue()
        StockRow stock = core.view.findStock(designId, planetId)
        int64 maxHulls = 1
        if (stock.count > 0) {
            maxHulls = stock.count
        } else {
            int64 designStock = core.view.stockCountForDesign(designId)
            if (designStock > 0) {
                maxHulls = designStock
            }
        }
        fp64 cur = reclaimStockHullsSpin.value()
        GuiScaleRange hullRange = GuiScaleRange()
        hullRange.normalize(cur, 1.0, fp64(maxHulls), 1.0)
        if (hullRange.value > fp64(maxHulls)) {
            hullRange.value = fp64(maxHulls)
        }
        if (hullRange.value < 1.0) {
            hullRange.value = 1.0
        }
        suppressStockHulls = true
        reclaimStockHullsSpin.configure(
            hullRange.value, hullRange.lower, hullRange.upper,
            hullRange.step)
        suppressStockHulls = false
        refreshReclaimStockHullsLabel()
    }

    /*
     * Reclaim-stock design choice stepped — refresh qty Spin.
     *
     * Purpose: GuiChoiceRow.changedAction.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onReclaimStockDesignChanged() {
        syncReclaimStockHullsSpin()
    }

    /*
     * Reclaim-stock hulls SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onReclaimStockHullsChanged(fp64 value) {
        if (suppressStockHulls) {
            return()
        }
        refreshReclaimStockHullsLabel()
    }

    /*
     * Refresh reclaim-stock hulls caption from the SpinButton.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshReclaimStockHullsLabel() {
        if (reclaimStockHullsLabel == null) {
            return()
        }
        reclaimStockHullsLabel.setText(format(
            "Stock hulls ({})", reclaimStockHullsValue()))
    }

    /*
     * Rebuild reclaim fleet choices from owned fleets.
     *
     * Purpose: Combo stand-in for reclaim fleet id.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimFleetChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 1) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        reclaimFleetChoice.setChoices(ids)
    }

    /*
     * Reconfigure reclaim hulls SpinButton from the selected fleet.
     *
     * Purpose: SpinButton clamped to hullCount.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimHullsSpin() {
        if (reclaimHullsSpin == null) {
            return()
        }
        FleetRow row = core.view.findFleet(reclaimFleetValue())
        int64 maxHulls = 1
        if (row.id >= 0 and row.hullCount > 0) {
            maxHulls = row.hullCount
        }
        fp64 cur = reclaimHullsSpin.value()
        GuiScaleRange hullRange = GuiScaleRange()
        hullRange.normalize(cur, 1.0, fp64(maxHulls), 1.0)
        /*
         * normalize may widen upper when maxHulls == 1 so GTK
         * accepts the range; keep the thumb on a real hull count.
         */
        if (hullRange.value > fp64(maxHulls)) {
            hullRange.value = fp64(maxHulls)
        }
        if (hullRange.value < 1.0) {
            hullRange.value = 1.0
        }
        suppressHulls = true
        reclaimHullsSpin.configure(
            hullRange.value, hullRange.lower, hullRange.upper,
            hullRange.step)
        suppressHulls = false
        refreshReclaimHullsLabel()
    }

    /*
     * Reclaim fleet choice stepped — refresh hulls Scale.
     *
     * Purpose: GuiChoiceRow.changedAction.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onReclaimFleetChanged() {
        syncReclaimHullsSpin()
    }

    /*
     * Reclaim hulls SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onReclaimHullsChanged(fp64 value) {
        if (suppressHulls) {
            return()
        }
        refreshReclaimHullsLabel()
    }

    /*
     * Refresh reclaim hulls caption from the SpinButton.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshReclaimHullsLabel() {
        if (reclaimHullsLabel == null) {
            return()
        }
        reclaimHullsLabel.setText(format(
            "Hulls ({})", reclaimHullsValue()))
    }

    /*
     * Read the name Entry text.
     *
     * Purpose: PUT /design name field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String nameValue() {
        return(nameEntry.text())
    }

    /*
     * Read the speed Entry text.
     *
     * Purpose: PUT /design speed field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String speedValue() {
        return(speedEntry.text())
    }

    /*
     * Read the hop Entry text.
     *
     * Purpose: PUT /design hop field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String hopValue() {
        return(hopEntry.text())
    }

    /*
     * Read the size Entry text.
     *
     * Purpose: PUT /design size field (cost basis).
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String sizeValue() {
        return(sizeEntry.text())
    }

    /*
     * Read the cargo Entry text.
     *
     * Purpose: PUT /design cargo field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String cargoValue() {
        return(cargoEntry.text())
    }

    /*
     * Read the selected design kind.
     *
     * Purpose: PUT /design kind field.
     *
     * Parameters: none.
     *
     * Returns: kind string (scout/colony/defense/war).
     */
    String kindValue() {
        String kind = kindChoice.value()
        if (kind.length < 1) {
            return("war")
        }
        return(kind)
    }

    /*
     * Read the yard planet choice.
     *
     * Purpose: PUT /build planet id.
     *
     * Parameters: none.
     *
     * Returns: planet id.
     */
    int64 planetValue() {
        return(planetChoice.intValue())
    }

    /*
     * Read the design id choice.
     *
     * Purpose: PUT /build / Examine design id.
     *
     * Parameters: none.
     *
     * Returns: design id.
     */
    int64 designIdValue() {
        return(designChoice.intValue())
    }

    /*
     * Read the reclaim-stock design id choice.
     *
     * Purpose: PUT /reclaim-stock design field.
     *
     * Parameters: none.
     *
     * Returns: design id.
     */
    int64 reclaimStockDesignValue() {
        return(reclaimStockDesignChoice.intValue())
    }

    /*
     * Read reclaim-stock hulls from the SpinButton.
     *
     * Purpose: PUT /reclaim-stock hull count.
     *
     * Parameters: none.
     *
     * Returns: hull count (>= 1 when SpinButton exists).
     */
    int64 reclaimStockHullsValue() {
        if (reclaimStockHullsSpin == null) {
            return(1)
        }
        int64 hulls = int64(reclaimStockHullsSpin.value() + 0.5)
        if (hulls < 1) {
            hulls = 1
        }
        return(hulls)
    }

    /*
     * Read the reclaim fleet choice.
     *
     * Purpose: PUT /reclaim-hulls fleet id.
     *
     * Parameters: none.
     *
     * Returns: fleet id.
     */
    int64 reclaimFleetValue() {
        return(reclaimFleetChoice.intValue())
    }

    /*
     * Read reclaim hulls from the SpinButton.
     *
     * Purpose: PUT /reclaim-hulls hull count.
     *
     * Parameters: none.
     *
     * Returns: hull count (>= 1 when SpinButton exists).
     */
    int64 reclaimHullsValue() {
        if (reclaimHullsSpin == null) {
            return(1)
        }
        int64 hulls = int64(reclaimHullsSpin.value() + 0.5)
        if (hulls < 1) {
            hulls = 1
        }
        FleetRow row = core.view.findFleet(reclaimFleetValue())
        if (row.id >= 0 and row.hullCount > 0 and hulls > row.hullCount) {
            return(row.hullCount)
        }
        return(hulls)
    }
}
