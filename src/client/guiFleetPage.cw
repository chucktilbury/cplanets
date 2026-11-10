/*
 * src/client/guiFleetPage.cw — fleets panel + dispatch/recall chrome.
 *
 * List stand-in for map pick-to-dispatch (TUNING-PLAYABLE B2).
 * Order / fleet / dest use GuiChoiceRow (DropDown); hulls use a
 * SpinButton. Travel ProgressBar tracks the
 * selected (or lead in-flight) fleet. Develop/build bars reuse
 * GuiProgressChrome. Hosted in Fleets menubar panel dialog.
 *
 * Created: 2026-11-06
 * Author: Auto
 *
 * Changelog:
 *   2026-11-06  Initial text dispatch/recall / progress page.
 *   2026-11-07  Hulls Entry for split-dispatch of sitting stacks.
 *   2026-11-07  Fleet id Entry defaults/syncs to a sitting stack
 *               (never leave 0 — fleets start at 1).
 *   2026-11-08  GuiProgressChrome ProgressBars for develop/build.
 *   2026-11-09  Examine fleet button → GuiFleetDialog.
 *   2026-11-09  Hosted in View→Fleets panel dialog.
 *   2026-11-09  Menubar opener is root Fleets click (no Open submenu).
 *   2026-11-09  Choice rows + hull Scale + travel ProgressBar +
 *               tooltips (View dialogs usable).
 *   2026-11-09  Safe Scale range via GuiScaleRange (empty fleets).
 *   2026-11-10  CPL-101: unassigned stock block; create fleet +
 *               assign chrome (PUT /fleet, PUT /assign).
 */

include "appCore.cw"
include "fleetRow.cw"
include "guiChoiceRow.cw"
include "guiProgressChrome.cw"
include "guiScaleRange.cw"
include "planetRow.cw"

/*
 * GuiFleetPage owns the Fleets panel dialog widgets.
 *
 * Unassigned stock lines sit above named fleets. Create / assign
 * feed PUT /fleet and PUT /assign; Dispatch / Recall keep the
 * existing travel path. Hulls SpinButton peels a subset from a
 * multi-hull sitting stack (0 = whole fleet).
 */
class GuiFleetPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Label stockList
    Gtk.Label fleetList
    Gtk.Entry createNameEntry
    GuiChoiceRow createPlanetChoice
    Gtk.Button createFleetBtn
    GuiChoiceRow assignFleetChoice
    Gtk.Entry assignTypeEntry
    Gtk.SpinButton assignQtySpin
    Gtk.Label assignQtyLabel
    Gtk.Button assignBtn
    GuiChoiceRow fleetChoice
    GuiChoiceRow orderChoice
    GuiChoiceRow destChoice
    Gtk.SpinButton hullsSpin
    Gtk.Label hullsLabel
    Gtk.ProgressBar travelBar
    Gtk.Button dispatchBtn
    Gtk.Button recallBtn
    Gtk.Button examineBtn
    Gtk.Label lockHint
    void<> createFleetAction
    void<> assignAction
    void<> dispatchAction
    void<> recallAction
    void<> examineAction
    void<fp64> hullsChangedAction
    void<fp64> assignQtyChangedAction
    bool suppressHulls
    bool suppressAssignQty

    /*
     * Construct a fleet page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiFleetPage ready for buildPage.
     */
    GuiFleetPage(AppCore appCore) {
        core = appCore
        progressChrome = GuiProgressChrome(appCore)
        stockList = null
        fleetList = null
        createNameEntry = null
        createPlanetChoice = GuiChoiceRow()
        createFleetBtn = null
        assignFleetChoice = GuiChoiceRow()
        assignTypeEntry = null
        assignQtySpin = null
        assignQtyLabel = null
        assignBtn = null
        fleetChoice = GuiChoiceRow()
        orderChoice = GuiChoiceRow()
        destChoice = GuiChoiceRow()
        hullsSpin = null
        hullsLabel = null
        travelBar = null
        dispatchBtn = null
        recallBtn = null
        examineBtn = null
        lockHint = null
        createFleetAction = null
        assignAction = null
        dispatchAction = null
        recallAction = null
        examineAction = null
        hullsChangedAction = null
        assignQtyChangedAction = null
        suppressHulls = false
        suppressAssignQty = false
    }

    /*
     * Build the Fleets panel dialog widget tree.
     *
     * Purpose: unassigned stock + create/assign + dispatch/recall
     * + travel / develop/build progress (non-modal dialog).
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
        examineBtn = Gtk.Button("Examine fleet")
        examineBtn.setTooltip(
            "Open TransientWindow inspect for the selected fleet.")
        if (examineAction != null) {
            examineBtn.onClicked(examineAction)
        }
        page.append(examineBtn)
        page.append(Gtk.Label("Create named fleet (empty)"))
        createNameEntry = Gtk.Entry("fleet-1")
        createNameEntry.setTooltip(
            "Unique per-seat fleet name for PUT /fleet.")
        page.append(Gtk.Label("Fleet name"))
        page.append(createNameEntry)
        page.append(Gtk.Label("Park at planet id"))
        page.append(createPlanetChoice.buildWidget(
            "Owned planet where the empty fleet sits (yard OK)."))
        createFleetBtn = Gtk.Button("Create fleet")
        createFleetBtn.setTooltip(
            "PUT /fleet — empty sitting container at the planet.")
        if (createFleetAction != null) {
            createFleetBtn.onClicked(createFleetAction)
        }
        page.append(createFleetBtn)
        page.append(Gtk.Label(
            "Assign from unassigned stock (same planet)"))
        page.append(Gtk.Label("Fleet id"))
        page.append(assignFleetChoice.buildWidget(
            "Sitting owned fleet to fill from stock at its location."))
        assignTypeEntry = Gtk.Entry("scout")
        assignTypeEntry.setTooltip(
            "Ship type name to assign from unassigned stock.")
        page.append(Gtk.Label("Type name"))
        page.append(assignTypeEntry)
        assignQtyLabel = Gtk.Label("Qty (1)")
        assignQtyLabel.setTooltip(
            "Hulls to move from unassigned stock into the fleet.")
        page.append(assignQtyLabel)
        assignQtySpin = Gtk.SpinButton()
        GuiScaleRange initAssign = GuiScaleRange()
        initAssign.normalize(1.0, 1.0, 1.0, 1.0)
        assignQtySpin.configure(
            initAssign.value, initAssign.lower, initAssign.upper,
            initAssign.step)
        assignQtySpin.setTooltip("Assign quantity (over-assign rejects).")
        if (assignQtyChangedAction != null) {
            assignQtySpin.onValueChanged(assignQtyChangedAction)
        }
        page.append(assignQtySpin)
        assignBtn = Gtk.Button("Assign")
        assignBtn.setTooltip(
            "PUT /assign — type+qty from stock at the fleet planet.")
        if (assignAction != null) {
            assignBtn.onClicked(assignAction)
        }
        page.append(assignBtn)
        page.append(Gtk.Label(
            "Dispatch (explore/take/trade/move/ambush)"))
        page.append(Gtk.Label("Fleet id (sitting stack)"))
        page.append(fleetChoice.buildWidget(
            "Cycle owned fleets. Prefer a sitting unlocked stack."))
        orderChoice.setChoices(orderChoices())
        orderChoice.setValue("explore")
        page.append(Gtk.Label("Order"))
        page.append(orderChoice.buildWidget(
            "Dispatch order: explore, take, trade, move, ambush."))
        page.append(Gtk.Label("Dest planet id"))
        page.append(destChoice.buildWidget(
            "Cycle visible planets, or pick a rock on the map."))
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
        Gtk.Box row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        dispatchBtn = Gtk.Button("Dispatch")
        dispatchBtn.setTooltip("PUT /order for the selected fleet.")
        recallBtn = Gtk.Button("Recall")
        recallBtn.setTooltip(
            "PUT /recall — cancel or return the selected fleet.")
        if (dispatchAction != null) {
            dispatchBtn.onClicked(dispatchAction)
        }
        if (recallAction != null) {
            recallBtn.onClicked(recallAction)
        }
        row.append(dispatchBtn)
        row.append(recallBtn)
        page.append(row)
        page.append(Gtk.Label("Fleet travel progress"))
        travelBar = Gtk.ProgressBar(Gtk.ProgressBar.HORIZONTAL)
        travelBar.setShowText(true)
        travelBar.setHExpand(true)
        travelBar.setText("travel idle")
        travelBar.setFraction(0.0)
        travelBar.setTooltip(
            "Selected or lead in-flight fleet hop progress.")
        page.append(travelBar)
        page.append(progressChrome.buildWidget())
        return(page)
    }

    /*
     * Refresh list / choices / travel / lock from core.view.
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
        syncCreatePlanetChoices()
        syncFleetChoices()
        syncAssignFleetChoices()
        syncDestChoices()
        syncHullsSpin()
        syncAssignQtySpin()
        refreshTravelBar()
        if (progressChrome != null) {
            progressChrome.refresh()
        }
        syncLockChrome()
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
     * Rebuild create-fleet planet choices from owned rocks.
     *
     * Purpose: park empty named fleets at an owned planet (yard
     * preferred via firstOwnedYardId default).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncCreatePlanetChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible
                and row.ownerId == core.view.viewerId
                and row.id >= 0) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        createPlanetChoice.setChoices(ids)
        int64 homeYard = core.view.firstOwnedYardId()
        if (homeYard >= 0) {
            String cur = createPlanetChoice.value()
            if (cur.length < 1) {
                createPlanetChoice.setValue(format("{}", homeYard))
            } else {
                PlanetRow pick = core.view.findPlanet(cur.toInt64())
                if (pick.id < 0
                    or pick.ownerId != core.view.viewerId) {
                    createPlanetChoice.setValue(
                        format("{}", homeYard))
                }
            }
        }
    }

    /*
     * Rebuild fleet id choices from owned visible fleets.
     *
     * Purpose: Combo stand-in; prefer keeping the prior pick.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFleetChoices() {
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
        if (ids.length < 1) {
            int64 sit = core.view.firstSittingOwnedFleetId()
            if (sit >= 1) {
                ids.append(format("{}", sit))
            }
        }
        fleetChoice.setChoices(ids)
        int64 prefer = core.view.firstSittingOwnedFleetId()
        if (prefer >= 1) {
            String cur = fleetChoice.value()
            if (cur.length < 1
                or not core.view.isOwnedFleet(cur.toInt64())) {
                fleetChoice.setValue(format("{}", prefer))
            }
        }
    }

    /*
     * Rebuild assign fleet choices from owned fleets.
     *
     * Purpose: assign chrome fleet id DropDown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAssignFleetChoices() {
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
        assignFleetChoice.setChoices(ids)
        String cur = assignFleetChoice.value()
        if (cur.length < 1 and ids.length > 0) {
            assignFleetChoice.setValue(ids[0])
        }
    }

    /*
     * Reconfigure assign qty SpinButton (1..reasonable).
     *
     * Purpose: keep a usable range; over-assign is still a server
     * reject shown via AlertDialog.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAssignQtySpin() {
        if (assignQtySpin == null) {
            return()
        }
        fp64 cur = assignQtySpin.value()
        GuiScaleRange qtyRange = GuiScaleRange()
        qtyRange.normalize(cur, 1.0, 99.0, 1.0)
        if (qtyRange.value < 1.0) {
            qtyRange.value = 1.0
        }
        suppressAssignQty = true
        assignQtySpin.configure(
            qtyRange.value, qtyRange.lower, qtyRange.upper,
            qtyRange.step)
        suppressAssignQty = false
        refreshAssignQtyLabel()
    }

    /*
     * Assign qty SpinButton moved — refresh caption.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onAssignQtyChanged(fp64 value) {
        if (suppressAssignQty) {
            return()
        }
        refreshAssignQtyLabel()
    }

    /*
     * Refresh assign qty caption from the SpinButton.
     *
     * Purpose: live label next to the slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshAssignQtyLabel() {
        if (assignQtyLabel == null) {
            return()
        }
        assignQtyLabel.setText(format(
            "Qty ({})", assignQtyValue()))
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
        list ids = []
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible and row.id >= 0) {
                ids.append(format("{}", row.id))
            }
            index = index + 1
        }
        destChoice.setChoices(ids)
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
     * Purpose: extend develop/build ProgressBar pattern to fleet
     * travel (outboundEta / remaining eta).
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
     * Update Dispatch sensitivity from the selected fleet lock.
     *
     * Purpose: mid-dispatch lock UX without freezing the UI.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncLockChrome() {
        if (dispatchBtn == null) {
            return()
        }
        int64 fleetId = fleetIdValue()
        FleetRow row = core.view.findFleet(fleetId)
        bool locked = false
        if (row.id >= 0) {
            locked = row.orderLocked()
        }
        dispatchBtn.setSensitive(not locked)
        if (lockHint != null) {
            if (locked) {
                lockHint.setText(
                    "Fleet locked in-flight — Recall only.")
            } else {
                lockHint.setText(
                    "Sitting: Dispatch OK. Locked: Recall only.")
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
     * Purpose: PUT /fleet planet field.
     *
     * Parameters: none.
     *
     * Returns: planet id.
     */
    int64 createPlanetValue() {
        return(createPlanetChoice.intValue())
    }

    /*
     * Read the assign fleet id.
     *
     * Purpose: PUT /assign fleet field.
     *
     * Parameters: none.
     *
     * Returns: fleet id.
     */
    int64 assignFleetValue() {
        return(assignFleetChoice.intValue())
    }

    /*
     * Read the assign type name Entry.
     *
     * Purpose: PUT /assign typeName field.
     *
     * Parameters: none.
     *
     * Returns: Entry text.
     */
    String assignTypeValue() {
        if (assignTypeEntry == null) {
            return("")
        }
        return(assignTypeEntry.text())
    }

    /*
     * Read assign quantity from the SpinButton.
     *
     * Purpose: PUT /assign qty field.
     *
     * Parameters: none.
     *
     * Returns: hull count (>= 1 when SpinButton exists).
     */
    int64 assignQtyValue() {
        if (assignQtySpin == null) {
            return(1)
        }
        int64 qty = int64(assignQtySpin.value() + 0.5)
        if (qty < 1) {
            return(1)
        }
        return(qty)
    }

    /*
     * Read the selected fleet id.
     *
     * Purpose: Dispatch / Recall / Examine PUT fleet field.
     *
     * Parameters: none.
     *
     * Returns: fleet id from the choice row.
     */
    int64 fleetIdValue() {
        return(fleetChoice.intValue())
    }

    /*
     * Read the selected order verb.
     *
     * Purpose: Dispatch PUT order field.
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
     * Purpose: Dispatch PUT dest field.
     *
     * Parameters: none.
     *
     * Returns: dest planet id.
     */
    int64 destValue() {
        return(destChoice.intValue())
    }

    /*
     * Read hulls-to-send from the SpinButton.
     *
     * Purpose: peel a subset from a multi-hull sitting stack
     * before PUT /order (0 = dispatch the whole fleet).
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
     * Purpose: GuiMapPage primary-click / ContextMenu dispatch
     * feeds the existing Fleets panel PUT /order chrome.
     *
     * Parameters:
     *   planetId — rock id to send toward.
     *
     * Returns: nothing.
     */
    void setDestPlanet(int64 planetId) {
        String text = format("{}", planetId)
        if (not destChoice.setValue(text)) {
            list ids = []
            ids.append(text)
            int64 index = 0
            while (index < destChoice.pendingChoices.length) {
                String item = destChoice.pendingChoices[index]
                if (not item.equals(text)) {
                    ids.append(item)
                }
                index = index + 1
            }
            destChoice.setChoices(ids)
            destChoice.setValue(text)
        }
        syncLockChrome()
        refreshTravelBar()
    }
}
