/*
 * src/client/guiFleetDeployPage.cw — Fleets→Deploy dialog page.
 *
 * Dispatch / recall for assigned sitting fleets. Dialog Apply →
 * PUT /order; Recall stays a page button. Travel ProgressBar
 * tracks the selected (or lead in-flight) hop (CPL-110).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial Deploy dialog page (split from fleet page).
 */

include "appCore.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"
include "guiScaleRange.cw"
include "planetRow.cw"

/*
 * GuiFleetDeployPage owns Fleets→Deploy dialog widgets.
 *
 * Apply dispatches the selected fleet. Hulls SpinButton peels a
 * subset from a multi-hull sitting stack (0 = whole fleet).
 */
class GuiFleetDeployPage {
    AppCore core
    GuiChoiceRow fleetChoice
    GuiChoiceRow orderChoice
    GuiChoiceRow destChoice
    Gtk.SpinButton hullsSpin
    Gtk.Label hullsLabel
    Gtk.ProgressBar travelBar
    Gtk.Button recallBtn
    Gtk.Label lockHint
    void<> recallAction
    void<fp64> hullsChangedAction
    bool suppressHulls

    /*
     * Construct a Deploy page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetDeployPage ready for buildPage.
     */
    GuiFleetDeployPage(AppCore appCore) {
        core = appCore
        fleetChoice = GuiChoiceRow()
        orderChoice = GuiChoiceRow()
        destChoice = GuiChoiceRow()
        hullsSpin = null
        hullsLabel = null
        travelBar = null
        recallBtn = null
        lockHint = null
        recallAction = null
        hullsChangedAction = null
        suppressHulls = false
    }

    /*
     * Build the Deploy dialog widget tree.
     *
     * Purpose: fleet/order/dest/hulls + travel ProgressBar + Recall.
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
            "Deploy (explore/take/trade/move/ambush) — Apply dispatches"))
        page.append(Gtk.Label("Fleet (sitting stack)"))
        page.append(fleetChoice.buildWidget(
            "Owned fleets by name. Prefer a sitting unlocked stack."))
        orderChoice.setChoices(orderChoices())
        orderChoice.setValue("explore")
        page.append(Gtk.Label("Order"))
        page.append(orderChoice.buildWidget(
            "Dispatch order: explore, take, trade, move, ambush."))
        page.append(Gtk.Label("Dest planet"))
        page.append(destChoice.buildWidget(
            "Visible planets by name, or pick a rock on the map."))
        hullsLabel = Gtk.Label("Hulls to send (0 = whole stack)")
        hullsLabel.setTooltip(
            "0 sends the whole sitting stack; >0 peels that many.")
        page.append(hullsLabel)
        hullsSpin = Gtk.SpinButton()
        GuiScaleRange initHulls = GuiScaleRange()
        initHulls.normalize(0.0, 0.0, 1.0, 1.0)
        hullsSpin.configure(
            initHulls.value, initHulls.lower, initHulls.upper,
            initHulls.step)
        hullsSpin.setTooltip(
            "Hulls to peel from the sitting stack (0 = all).")
        if (hullsChangedAction != null) {
            hullsSpin.onValueChanged(hullsChangedAction)
        }
        page.append(hullsSpin)
        lockHint = Gtk.Label(
            "In-flight lock: rewrite disabled; use Recall.")
        lockHint.setTooltip(
            "Mid-dispatch fleets are locked until Recall.")
        page.append(lockHint)
        recallBtn = Gtk.Button("Recall")
        recallBtn.setTooltip(
            "PUT /recall — cancel or return the selected fleet.")
        if (recallAction != null) {
            recallBtn.onClicked(recallAction)
        }
        page.append(recallBtn)
        page.append(Gtk.Label("Fleet travel progress"))
        travelBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
        travelBar.setShowText(true)
        travelBar.setHExpand(true)
        travelBar.setText("travel idle")
        travelBar.setFraction(0.0)
        travelBar.setTooltip(
            "Selected or lead in-flight fleet hop progress.")
        page.append(travelBar)
        return(page)
    }

    /*
     * Refresh choices / hulls / travel / lock from core.view.
     *
     * Purpose: after pull or offline redraw.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        syncFleetChoices()
        syncDestChoices()
        syncHullsSpin()
        refreshTravelBar()
        syncLockChrome()
    }

    /*
     * Bind DropDown / Spin / Recall handlers.
     *
     * Purpose: GuiMain activate wiring.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void bindChoices() {
        fleetChoice.bindSelected(fleetChoice.onSelected)
        orderChoice.bindSelected(orderChoice.onSelected)
        destChoice.bindSelected(destChoice.onSelected)
    }

    /*
     * Fixed dispatch order verb list.
     *
     * Purpose: orderChoice seed (RULES travel verbs).
     *
     * Parameters: none.
     *
     * Returns: list of order strings.
     */
    list orderChoices() {
        list out = []
        out.append("explore")
        out.append("take")
        out.append("trade")
        out.append("move")
        out.append("ambush")
        return(out)
    }

    /*
     * Rebuild fleet name choices from owned visible fleets.
     *
     * Purpose: DropDown by fleet name; prefer keeping the prior pick.
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
        if (names.length < 1) {
            int64 sit = core.view.firstSittingOwnedFleetId()
            if (sit >= 1) {
                FleetRow sitRow = core.view.findFleet(sit)
                names.append(sitRow.choiceLabel())
            }
        }
        fleetChoice.setChoices(names)
        int64 prefer = core.view.firstSittingOwnedFleetId()
        if (prefer >= 1) {
            String cur = fleetChoice.value()
            int64 curId = core.view.resolveFleetChoice(cur)
            if (cur.length < 1 or not core.view.isOwnedFleet(curId)) {
                FleetRow preferRow = core.view.findFleet(prefer)
                fleetChoice.setValue(preferRow.choiceLabel())
            }
        }
    }

    /*
     * Rebuild dest planet choices from visible rocks.
     *
     * Purpose: Combo stand-in; map pick still setDestPlanet.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncDestChoices() {
        list names = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible and row.id >= 0) {
                names.append(row.choiceLabel())
            }
            index = index + 1
        }
        destChoice.setChoices(names)
    }

    /*
     * Reconfigure hulls SpinButton upper from the selected fleet.
     *
     * Purpose: SpinButton clamped to the stack size.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncHullsSpin() {
        if (hullsSpin == null) {
            return()
        }
        FleetRow row = core.view.findFleet(fleetIdValue())
        int64 maxHulls = 1
        if (row.id >= 0 and row.hullCount > 0) {
            maxHulls = row.hullCount
        }
        fp64 cur = hullsSpin.value()
        GuiScaleRange hullRange = GuiScaleRange()
        hullRange.normalize(cur, 0.0, fp64(maxHulls), 1.0)
        suppressHulls = true
        hullsSpin.configure(
            hullRange.value, hullRange.lower, hullRange.upper,
            hullRange.step)
        suppressHulls = false
        refreshHullsLabel()
    }

    /*
     * Drive the travel ProgressBar from hop ETA fields.
     *
     * Purpose: non-modal travel chrome for Deploy.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshTravelBar() {
        if (travelBar == null) {
            return()
        }
        FleetRow row = travelFleet()
        if (row.id < 0 or not row.mapPathActive()) {
            travelBar.setFraction(0.0)
            travelBar.setText("travel idle")
            return()
        }
        String label = format(
            "fleet {} {} eta={}/{}",
            row.id, row.order, row.eta, row.outboundEta)
        travelBar.setText(label)
        if (row.outboundEta <= 0) {
            travelBar.pulse()
            return()
        }
        travelBar.setFraction(row.mapHopProgress())
    }

    /*
     * Fleet row that should drive the travel bar.
     *
     * Purpose: prefer the selected fleet when in-flight; else the
     * first owned visible hop; else empty sentinel.
     *
     * Parameters: none.
     *
     * Returns: FleetRow (id −1 when none traveling).
     */
    FleetRow travelFleet() {
        FleetRow selected = core.view.findFleet(fleetIdValue())
        if (selected.id >= 0 and selected.mapPathActive()) {
            return(selected)
        }
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow row = core.view.fleets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.mapPathActive()) {
                return(row)
            }
            index = index + 1
        }
        return(FleetRow())
    }

    /*
     * Fleet choice stepped — refresh hulls / lock / travel.
     *
     * Purpose: GuiChoiceRow.changedAction.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onFleetChoiceChanged() {
        syncHullsSpin()
        syncLockChrome()
        refreshTravelBar()
    }

    /*
     * Hulls SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onHullsChanged(fp64 value) {
        if (suppressHulls) {
            return()
        }
        refreshHullsLabel()
    }

    /*
     * Refresh the hulls caption from the SpinButton.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshHullsLabel() {
        if (hullsLabel == null) {
            return()
        }
        hullsLabel.setText(format(
            "Hulls to send ({}; 0 = whole stack)", hullsValue()))
    }

    /*
     * Update lock hint from the selected fleet.
     *
     * Purpose: mid-dispatch lock UX without freezing the UI.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncLockChrome() {
        int64 fleetId = fleetIdValue()
        FleetRow row = core.view.findFleet(fleetId)
        bool locked = false
        if (row.id >= 0) {
            locked = row.orderLocked()
        }
        if (lockHint != null) {
            if (locked) {
                lockHint.setText(
                    "Fleet locked in-flight — Recall only.")
            } else {
                lockHint.setText(
                    "Sitting: Deploy Apply OK. Locked: Recall only.")
            }
        }
    }

    /*
     * Read the selected fleet id.
     *
     * Purpose: Deploy / Recall PUT fleet field.
     *
     * Parameters: none.
     *
     * Returns: fleet id from the choice row, or -1 when unresolved.
     */
    int64 fleetIdValue() {
        return(core.view.resolveFleetChoice(fleetChoice.value()))
    }

    /*
     * Read the selected order verb.
     *
     * Purpose: Deploy PUT order field.
     *
     * Parameters: none.
     *
     * Returns: order string (explore/take/trade/move/ambush).
     */
    String orderValue() {
        String order = orderChoice.value()
        if (order.length < 1) {
            return("explore")
        }
        return(order)
    }

    /*
     * Read the selected destination planet id.
     *
     * Purpose: Deploy PUT dest field.
     *
     * Parameters: none.
     *
     * Returns: dest planet id, or -1 when unresolved.
     */
    int64 destValue() {
        return(core.view.resolvePlanetChoice(destChoice.value()))
    }

    /*
     * Read hulls-to-send from the SpinButton.
     *
     * Purpose: peel a subset before PUT /order (0 = whole fleet).
     *
     * Parameters: none.
     *
     * Returns: nearest int hull count.
     */
    int64 hullsValue() {
        if (hullsSpin == null) {
            return(0)
        }
        int64 hulls = int64(hullsSpin.value() + 0.5)
        if (hulls < 0) {
            return(0)
        }
        return(hulls)
    }

    /*
     * Write the destination planet choice from a map pick.
     *
     * Purpose: GuiMapPage primary-click / ContextMenu deploy feeds
     * the existing PUT /order chrome.
     *
     * Parameters:
     *   planetId — rock id to send toward.
     *
     * Returns: nothing.
     */
    void setDestPlanet(int64 planetId) {
        PlanetRow row = core.view.findPlanet(planetId)
        String text = row.choiceLabel()
        if (text.length < 1) {
            text = format("Planet {}", planetId)
        }
        if (not destChoice.setValue(text)) {
            list names = []
            names.append(text)
            int64 index = 0
            while (index < destChoice.pendingChoices.length) {
                String item = destChoice.pendingChoices[index]
                if (not item.equals(text)) {
                    names.append(item)
                }
                index = index + 1
            }
            destChoice.setChoices(names)
            destChoice.setValue(text)
        }
        syncLockChrome()
        refreshTravelBar()
    }
}
