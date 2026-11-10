/*
 * src/client/guiShipReclaimPage.cw — Ships→Reclaim dialog page.
 *
 * Unassigned stock reclaim (preferred) plus sitting-fleet reclaim
 * at a yard. Dialog Apply reclaims stock; fleet reclaim keeps a
 * page button. ProgressBar tracks reclaim ticks (CPL-110).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Reclaim dialog page (split from yard page).
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
 * GuiShipReclaimPage owns Ships→Reclaim dialog widgets.
 *
 * Apply → PUT /reclaim-stock. Reclaim hulls button → PUT
 * /reclaim-hulls for sitting assigned fleets at a yard.
 */
class GuiShipReclaimPage {
    AppCore core
    GuiProgressChrome progressChrome
    GuiChoiceRow planetChoice
    GuiChoiceRow reclaimStockDesignChoice
    Gtk.SpinButton reclaimStockHullsSpin
    Gtk.Label reclaimStockHullsLabel
    GuiChoiceRow reclaimFleetChoice
    Gtk.SpinButton reclaimHullsSpin
    Gtk.Label reclaimHullsLabel
    Gtk.Button reclaimFleetBtn
    void<> reclaimFleetAction
    void<fp64> reclaimHullsChangedAction
    void<fp64> reclaimStockHullsChangedAction
    bool suppressHulls
    bool suppressStockHulls

    /*
     * Construct a Reclaim page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiShipReclaimPage ready for buildPage.
     */
    GuiShipReclaimPage(AppCore appCore) {
        core = appCore
        progressChrome = GuiProgressChrome(appCore)
        progressChrome.setKindMask(GuiProgressChrome.KIND_RECLAIM)
        planetChoice = GuiChoiceRow()
        reclaimStockDesignChoice = GuiChoiceRow()
        reclaimStockHullsSpin = null
        reclaimStockHullsLabel = null
        reclaimFleetChoice = GuiChoiceRow()
        reclaimHullsSpin = null
        reclaimHullsLabel = null
        reclaimFleetBtn = null
        reclaimFleetAction = null
        reclaimHullsChangedAction = null
        reclaimStockHullsChangedAction = null
        suppressHulls = false
        suppressStockHulls = false
    }

    /*
     * Build the Reclaim dialog widget tree.
     *
     * Purpose: stock + fleet reclaim controls + ProgressBar.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label("Yard planet (stock + fleet reclaim)"))
        page.append(planetChoice.buildWidget(
            "Owned shipyard planet for reclaim-stock."))
        page.append(Gtk.Label(
            "Reclaim unassigned stock (Apply in footer)"))
        page.append(Gtk.Label("Stock ship type"))
        page.append(reclaimStockDesignChoice.buildWidget(
            "Ship types by name that have unassigned stock."))
        reclaimStockHullsLabel = Gtk.Label("Stock hulls (1)")
        reclaimStockHullsLabel.setTooltip(
            "How many unassigned hulls to reclaim at the yard.")
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
        page.append(Gtk.Label(
            "Reclaim assigned hulls (sitting fleet at yard)"))
        page.append(Gtk.Label("Fleet"))
        page.append(reclaimFleetChoice.buildWidget(
            "Owned fleets by name eligible for reclaim."))
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
        reclaimFleetBtn = Gtk.Button("Reclaim fleet hulls")
        reclaimFleetBtn.setTooltip(
            "PUT /reclaim-hulls at a productive shipyard.")
        if (reclaimFleetAction != null) {
            reclaimFleetBtn.onClicked(reclaimFleetAction)
        }
        page.append(reclaimFleetBtn)
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Refresh choices / spins / reclaim ProgressBar.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (progressChrome != null) {
            progressChrome.refresh()
        }
        syncYardPlanetChoices()
        syncReclaimStockDesignChoices()
        syncReclaimStockHullsSpin()
        syncReclaimFleetChoices()
        syncReclaimHullsSpin()
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
        planetChoice.bindSelected(planetChoice.onSelected)
        reclaimStockDesignChoice.bindSelected(
            reclaimStockDesignChoice.onSelected)
        reclaimFleetChoice.bindSelected(
            reclaimFleetChoice.onSelected)
    }

    /*
     * Rebuild yard planet choices from owned shipyards.
     *
     * Purpose: stock reclaim needs a yard planet.
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
     * Rebuild reclaim-stock design choices from catalog.
     *
     * Purpose: prefer designs that currently have unassigned stock.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimStockDesignChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.designs.length) {
            DesignRow row = core.view.designs[index]
            if (row.id >= 0
                and not row.closed
                and core.view.stockCountForDesign(row.id) > 0) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        if (names.length < 1) {
            index = 0
            while (index < core.view.designs.length) {
                DesignRow row = core.view.designs[index]
                if (row.id >= 0) {
                    names.append(row.choiceLabel())
                }
                index = index + 1
            }
        }
        reclaimStockDesignChoice.setChoices(names)
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
     * Purpose: fleet reclaim DropDown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncReclaimFleetChoices() {
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
        reclaimFleetChoice.setChoices(names)
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
     * Reclaim fleet choice stepped — refresh hulls Spin.
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
     * Read the yard planet choice.
     *
     * Purpose: PUT /reclaim-stock planet id.
     *
     * Parameters: none.
     *
     * Returns: planet id, or -1 when unresolved.
     */
    int64 planetValue() {
        return(core.view.resolvePlanetChoice(planetChoice.value()))
    }

    /*
     * Read the reclaim-stock design id choice.
     *
     * Purpose: PUT /reclaim-stock design field.
     *
     * Parameters: none.
     *
     * Returns: design id, or -1 when unresolved.
     */
    int64 reclaimStockDesignValue() {
        return(core.view.resolveDesignChoice(
            reclaimStockDesignChoice.value()))
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
     * Returns: fleet id, or -1 when unresolved.
     */
    int64 reclaimFleetValue() {
        return(core.view.resolveFleetChoice(
            reclaimFleetChoice.value()))
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
