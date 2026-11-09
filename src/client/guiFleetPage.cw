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
 * Dispatch chrome feeds PUT /order; Recall uses PUT /recall.
 * Hulls SpinButton peels a subset from a multi-hull sitting stack
 * (0 = whole fleet). Travel bar uses eta / outboundEta.
 */
class GuiFleetPage {
    AppCore core
    GuiProgressChrome progressChrome
    Gtk.Label fleetList
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
    void<> dispatchAction
    void<> recallAction
    void<> examineAction
    void<fp64> hullsChangedAction
    bool suppressHulls

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
        fleetList = null
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
        dispatchAction = null
        recallAction = null
        examineAction = null
        hullsChangedAction = null
        suppressHulls = false
    }

    /*
     * Build the Fleets panel dialog widget tree.
     *
     * Purpose: scrolled list + choice dispatch/recall + travel /
     * develop/build progress bars (footer inside non-modal dialog).
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
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
        syncFleetChoices()
        syncDestChoices()
        syncHullsSpin()
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
