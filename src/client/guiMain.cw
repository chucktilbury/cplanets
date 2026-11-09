/*
 * src/client/guiMain.cw — GTK human client main window (G / B / I).
 *
 * Map canvas is the main panel. Former Notebook tabs (Planets,
 * Fleets, Ships, Digest, Policy) open as non-modal top-level
 * menubar TransientWindows. Pause gated to one human; fleet
 * dispatch/recall; design/yard; planet budget Scales;
 * known-competitor compose; explored dialog auto-presents on
 * quality / productive changes. Develop/build ProgressBars live
 * in Fleets / Ships panel dialogs.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GuiMain window.
 *   2026-11-06  TUNING B: pause, ticket chrome, explored auto-pop.
 *   2026-11-07  Ships tab: design develop / yard build / reclaim.
 *   2026-11-07  Phase I: map canvas panel beside list notebook.
 *   2026-11-07  Budget Scales + known-competitor compose pages.
 *   2026-11-07  AlertDialog + status on connect / refresh failure.
 *   2026-11-07  Explored dialog hide-on-close; develop/build/reclaim
 *               keep status ack after refresh; fail via AlertDialog.
 *   2026-11-07  Split-dispatch: hulls Entry + clear reject status.
 *   2026-11-07  Dispatch preflight: missing fleet id + server reason.
 *   2026-11-08  AFK CheckButton → PUT /suspended.
 *   2026-11-09  Fleet / design examine TransientWindows (Section C).
 *   2026-11-09  Notebook → View menu + non-modal panel dialogs.
 *   2026-11-09  View dialogs usable: choice rows / Scales / tooltips
 *               / travel ProgressBar wiring.
 *   2026-11-09  Panel openers → top-level menubar menus (not View).
 *   2026-11-09  Panel roots click-activate (flat Buttons; no Open
 *               submenu — GtkPopoverMenuBar cannot host leaf roots).
 */

include "appCore.cw"
include "designRow.cw"
include "exploredTrack.cw"
include "guiDigestPage.cw"
include "guiFleetDialog.cw"
include "guiFleetPage.cw"
include "guiMapPage.cw"
include "guiPanelHost.cw"
include "guiPlanetDialog.cw"
include "guiPlanetPage.cw"
include "guiPolicyPage.cw"
include "guiShipDialog.cw"
include "guiYardPage.cw"
include "fleetRow.cw"
include "planetRow.cw"

/*
 * GuiMain owns the human client window.
 *
 * Policy Apply PUTs standing policy with no dumb-order warnings.
 * Pause CheckButton is sensitive only when pauseOffered().
 * AFK CheckButton sends PUT /suspended (handshake_miss hold).
 * Top-level Planets / Fleets / Ships / Digest / Policy menus
 * raise non-modal panel dialogs for list chrome.
 */
class GuiMain {
    AppCore core
    Gtk.Window window
    Gtk.Label status
    Gtk.CheckButton pauseBtn
    Gtk.CheckButton afkBtn
    GuiPlanetDialog planetDialog
    GuiFleetDialog fleetDialog
    GuiShipDialog shipDialog
    GuiPlanetPage planetPage
    GuiFleetPage fleetPage
    GuiYardPage yardPage
    GuiDigestPage digestPage
    GuiPolicyPage policyPage
    GuiMapPage mapPage
    GuiPanelHost panels
    ExploredTrack explored
    bool suppressPauseToggle
    bool suppressAfkToggle
    bool localSuspended
    void<> activateAction
    void<> refreshAction
    void<> applyAction
    void<> closeAction
    void<> dialogCloseAction
    void<> showExploredAction
    void<> showMapExploredAction
    void<> examineFleetAction
    void<> examineShipAction
    void<> dispatchAction
    void<> recallAction
    void<> developAction
    void<> buildAction
    void<> reclaimAction
    void<> budgetAction
    void<> sendAction
    void<bool> pauseAction
    void<bool> afkAction
    void<> testAction
    void<int64> mapPickAction
    void<> mapDispatchAction
    void<> mapBudgetAction
    bool testMode
    # Non-empty when startup TCP pull failed (host:port detail).
    String startupError

    /*
     * Construct the GUI around an AppCore.
     *
     * Purpose: retain core; delay widget build until activate.
     *
     * Parameters:
     *   appCore — headless coordinator with config/view/draft.
     *
     * Returns: GuiMain ready for onActivate.
     */
    GuiMain(AppCore appCore) {
        core = appCore
        window = null
        status = null
        pauseBtn = null
        afkBtn = null
        planetDialog = GuiPlanetDialog()
        fleetDialog = GuiFleetDialog()
        shipDialog = GuiShipDialog()
        planetPage = GuiPlanetPage(appCore)
        fleetPage = GuiFleetPage(appCore)
        yardPage = GuiYardPage(appCore)
        digestPage = GuiDigestPage(appCore)
        policyPage = GuiPolicyPage(appCore)
        mapPage = GuiMapPage(appCore)
        panels = GuiPanelHost()
        panels.showPlanetsAction = panels.showPlanets
        panels.showFleetsAction = panels.showFleets
        panels.showShipsAction = panels.showShips
        panels.showDigestAction = panels.showDigest
        panels.showPolicyAction = panels.showPolicy
        explored = ExploredTrack()
        suppressPauseToggle = false
        suppressAfkToggle = false
        localSuspended = false
        activateAction = null
        refreshAction = null
        applyAction = null
        closeAction = null
        dialogCloseAction = null
        showExploredAction = null
        showMapExploredAction = null
        examineFleetAction = null
        examineShipAction = null
        dispatchAction = null
        recallAction = null
        developAction = null
        buildAction = null
        reclaimAction = null
        budgetAction = null
        sendAction = null
        pauseAction = null
        afkAction = null
        testAction = null
        mapPickAction = null
        mapDispatchAction = null
        mapBudgetAction = null
        testMode = false
        startupError = ""
    }

    /*
     * Present a connection / pull failure to the operator.
     *
     * Purpose: never fail silently — status line always; AlertDialog
     * when a window exists and we are not in --test auto-quit.
     *
     * Parameters:
     *   detail — host:port failure text (already formatted).
     *
     * Returns: nothing.
     */
    void reportConnectFailure(String detail) {
        reportFailure("Connection failed", detail)
    }

    /*
     * Present an operator-facing failure (status + optional alert).
     *
     * Purpose: shared path for connect errors and Ships-panel verb
     * rejects so Start develop / build / reclaim never fail silent.
     *
     * Parameters:
     *   heading — AlertDialog primary message.
     *   detail — status line and alert detail text.
     *
     * Returns: nothing.
     */
    void reportFailure(String heading, String detail) {
        if (status != null) {
            status.setText(detail)
        }
        if (testMode or window == null or window.disposed()) {
            return()
        }
        Gtk.AlertDialog().show(window, heading, detail)
    }

    /*
     * Append a flat menubar-style panel opener Button.
     *
     * Purpose: raise a non-modal panel dialog on root-label click.
     * GtkPopoverMenuBar cannot host leaf actions as top-level items
     * (GTK requires submenus there), so panel names sit beside File
     * as flat Buttons instead of Open submenus.
     *
     * Parameters:
     *   strip — horizontal menu chrome Box (File MenuBar + openers).
     *   label — button text (Planets / Fleets / Ships / Digest /
     *     Policy).
     *   action — show* callback from GuiPanelHost (may be null).
     *
     * Returns: nothing.
     */
    void appendPanelOpener(Gtk.Box strip, String label, void<> action) {
        Gtk.Button btn = Gtk.Button(label)
        btn.addCssClass("flat")
        btn.setFocusOnClick(false)
        if (action != null) {
            btn.onClicked(action)
        }
        strip.append(btn)
    }

    /*
     * Application activate: build or present the main window.
     *
     * Purpose: Gtk.Application.onActivate entry.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void activate() {
        if (window != null and not window.disposed()) {
            window.present()
            return()
        }
        window = Gtk.Window("CPlanets")
        window.setDefaultSize(960, 640)
        panels.setParent(window)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 0)
        window.setChild(root)
        /* File stays a real MenuBar submenu. Panel openers are flat
         * Buttons beside it: GtkPopoverMenuBar only accepts submenus
         * as top-level GMenu entries, so a nested Open item was the
         * prior workaround. Click-to-activate roots need Buttons (or
         * a future Cwhip MenuBar.addAction). */
        Gtk.Box menuStrip = Gtk.Box(Gtk.Box.HORIZONTAL, 0)
        Gtk.MenuBar menu = Gtk.MenuBar()
        int64 fileMenu = menu.addMenu("File")
        menu.addItem(fileMenu, "Refresh", refreshAction)
        menu.addItem(fileMenu, "Quit", closeAction)
        menuStrip.append(menu)
        appendPanelOpener(menuStrip, "Planets", panels.showPlanetsAction)
        appendPanelOpener(menuStrip, "Fleets", panels.showFleetsAction)
        appendPanelOpener(menuStrip, "Ships", panels.showShipsAction)
        appendPanelOpener(menuStrip, "Digest", panels.showDigestAction)
        appendPanelOpener(menuStrip, "Policy", panels.showPolicyAction)
        root.append(menuStrip)
        Gtk.Box top = Gtk.Box(Gtk.Box.HORIZONTAL, 8)
        status = Gtk.Label("Ready")
        status.setHExpand(true)
        top.append(status)
        pauseBtn = Gtk.CheckButton("Pause")
        if (pauseAction != null) {
            pauseBtn.onToggled(pauseAction)
        }
        top.append(pauseBtn)
        afkBtn = Gtk.CheckButton("AFK")
        if (afkAction != null) {
            afkBtn.onToggled(afkAction)
        }
        top.append(afkBtn)
        root.append(top)
        mapPage.showExploredAction = showMapExploredAction
        mapPage.planetPickedAction = mapPickAction
        mapPage.dispatchHereAction = mapDispatchAction
        mapPage.budgetHereAction = mapBudgetAction
        mapPage.paintAction = mapPage.onPaint
        mapPage.clickAction = mapPage.onClick
        mapPage.dragAction = mapPage.onDrag
        mapPage.scrollAction = mapPage.onScroll
        mapPage.popupAction = mapPage.onPopup
        mapPage.hScrollAction = mapPage.onHScroll
        mapPage.vScrollAction = mapPage.onVScroll
        mapPage.showSelectedAction = mapPage.onShowSelected
        mapPage.zoomPlanetAction = mapPage.zoomToPlanet
        root.append(mapPage.buildPage())
        planetPage.showExploredAction = showExploredAction
        planetPage.budgetAction = budgetAction
        planetPage.budgetChangedAction = planetPage.onBudgetChanged
        planetPage.planetChoice.bind(
            planetPage.planetChoice.onPrev,
            planetPage.planetChoice.onNext)
        planetPage.planetChoice.changedAction = planetPage.onPlanetChoiceChanged
        fleetPage.dispatchAction = dispatchAction
        fleetPage.recallAction = recallAction
        fleetPage.examineAction = examineFleetAction
        fleetPage.hullsChangedAction = fleetPage.onHullsChanged
        fleetPage.fleetChoice.bind(
            fleetPage.fleetChoice.onPrev,
            fleetPage.fleetChoice.onNext)
        fleetPage.fleetChoice.changedAction = fleetPage.onFleetChoiceChanged
        fleetPage.orderChoice.bind(
            fleetPage.orderChoice.onPrev,
            fleetPage.orderChoice.onNext)
        fleetPage.destChoice.bind(
            fleetPage.destChoice.onPrev,
            fleetPage.destChoice.onNext)
        yardPage.developAction = developAction
        yardPage.buildAction = buildAction
        yardPage.reclaimAction = reclaimAction
        yardPage.examineAction = examineShipAction
        yardPage.reclaimHullsChangedAction = yardPage.onReclaimHullsChanged
        yardPage.kindChoice.bind(
            yardPage.kindChoice.onPrev,
            yardPage.kindChoice.onNext)
        yardPage.planetChoice.bind(
            yardPage.planetChoice.onPrev,
            yardPage.planetChoice.onNext)
        yardPage.designChoice.bind(
            yardPage.designChoice.onPrev,
            yardPage.designChoice.onNext)
        yardPage.reclaimFleetChoice.bind(
            yardPage.reclaimFleetChoice.onPrev,
            yardPage.reclaimFleetChoice.onNext)
        yardPage.reclaimFleetChoice.changedAction = yardPage.onReclaimFleetChanged
        digestPage.sendAction = sendAction
        digestPage.toChoice.bind(
            digestPage.toChoice.onPrev,
            digestPage.toChoice.onNext)
        policyPage.applyAction = applyAction
        policyPage.roleChoice.bind(
            policyPage.roleChoice.onPrev,
            policyPage.roleChoice.onNext)
        policyPage.expansionChangedAction = policyPage.onExpansionChanged
        policyPage.escortChangedAction = policyPage.onEscortChanged
        policyPage.agreementChangedAction = policyPage.onAgreementChanged
        policyPage.techChangedAction = policyPage.onTechChanged
        panels.wire(
            planetPage, fleetPage, yardPage, digestPage, policyPage)
        planetDialog.closeAction = dialogCloseAction
        planetDialog.closeRequestAction = planetDialog.onCloseRequest
        fleetDialog.closeAction = dialogCloseAction
        fleetDialog.closeRequestAction = fleetDialog.onCloseRequest
        shipDialog.closeAction = dialogCloseAction
        shipDialog.closeRequestAction = shipDialog.onCloseRequest
        window.present()
        refreshLists()
        if (startupError.length > 0) {
            reportConnectFailure(startupError)
        }
        if (testMode and testAction != null) {
            Gtk.Application().schedule(150, testAction)
        }
    }

    /*
     * Rebuild list labels from core.view.
     *
     * Purpose: Refresh menu / post-pull.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshLists() {
        planetPage.refresh()
        fleetPage.refresh()
        yardPage.refresh()
        mapPage.refresh()
        digestPage.refresh()
        policyPage.syncFromDraft()
        if (status != null) {
            String pauseBit = ""
            if (core.view.paused) {
                pauseBit = " paused"
            }
            if (localSuspended) {
                pauseBit.append(" AFK")
            }
            status.setText(format(
                "tick={} planets={} fleets={} humans={}{}",
                core.view.tick,
                core.view.visiblePlanetCount(),
                core.view.visibleFleetCount(),
                core.view.humanCount,
                pauseBit))
        }
        syncPauseChrome()
        syncAfkChrome()
        autoPresentExplored()
    }

    /*
     * Gate and sync the Pause CheckButton from the view.
     *
     * Purpose: sensitive only with exactly one human; hide dead
     * multi-human errors as the primary UX (DIALOGS §8).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncPauseChrome() {
        if (pauseBtn == null) {
            return()
        }
        bool offered = core.view.pauseOffered()
        pauseBtn.setSensitive(offered)
        suppressPauseToggle = true
        pauseBtn.setActive(core.view.paused and offered)
        suppressPauseToggle = false
    }

    /*
     * Sync the AFK CheckButton from local suspended state.
     *
     * Purpose: keep the chrome aligned after refresh / reject without
     * re-firing onToggled. Suspended is not yet in GET /state.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncAfkChrome() {
        if (afkBtn == null) {
            return()
        }
        suppressAfkToggle = true
        afkBtn.setActive(localSuspended)
        suppressAfkToggle = false
    }

    /*
     * Auto-present / refresh explored dialog on quality changes.
     *
     * Purpose: TUNING-PLAYABLE B3 — pop when quality first known
     * or when populated/productive flags change for that rock.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void autoPresentExplored() {
        PlanetRow row = explored.nextToPresent(core.view.planets)
        if (row.id >= 0) {
            planetDialog.presentRow(window, row)
        }
    }

    /*
     * Refresh handler: pull remote when port set, else redraw.
     *
     * Purpose: File→Refresh and test hooks. Failed TCP pull shows
     * status + AlertDialog with host:port (never silent).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onRefresh() {
        if (core.config.port > 0) {
            if (not core.pullRemote()) {
                reportConnectFailure(core.lastError)
                return()
            }
        }
        refreshLists()
    }

    /*
     * Open explored dialog for the first qualityKnown visible rock.
     *
     * Purpose: manual Planets panel button (still useful offline).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFirstExplored() {
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible and row.qualityKnown) {
                planetDialog.presentRow(window, row)
                return()
            }
            index = index + 1
        }
    }

    /*
     * Open explored dialog for the map-selected planet.
     *
     * Purpose: map ContextMenu "Open explored dialog" (Phase I).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showMapExplored() {
        PlanetRow row = mapPage.selectedPlanet()
        if (row.id >= 0 and row.qualityKnown) {
            planetDialog.presentRow(window, row)
        }
    }

    /*
     * Open fleet examine dialog for the Fleets panel fleet choice.
     *
     * Purpose: Section C — Inspect was a Label dump only; this
     * presents GuiFleetDialog for the selected (or first sitting)
     * fleet and pins the choice row.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFleetExamine() {
        fleetPage.syncFleetChoices()
        int64 fleetId = fleetPage.fleetIdValue()
        FleetRow row = core.view.findFleet(fleetId)
        if (row.id < 0) {
            int64 sit = core.view.firstSittingOwnedFleetId()
            if (sit >= 0) {
                row = core.view.findFleet(sit)
            }
        }
        if (row.id < 0) {
            int64 index = 0
            while (index < core.view.fleets.length) {
                FleetRow cand = core.view.fleets[index]
                if (cand.visible and cand.id >= 0) {
                    row = cand
                    break
                }
                index = index + 1
            }
        }
        if (row.id >= 0) {
            fleetPage.fleetChoice.setValue(format("{}", row.id))
            fleetDialog.presentRow(window, row)
            fleetPage.syncLockChrome()
        }
    }

    /*
     * Open design examine dialog for the Ships panel design choice.
     *
     * Purpose: Section C — Designs (inspect) was Label-only; this
     * presents GuiShipDialog and pins the design choice row.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showShipExamine() {
        yardPage.syncDesignChoices()
        int64 designId = yardPage.designIdValue()
        DesignRow row = core.view.findDesign(designId)
        if (row.id < 0 and core.view.designs.length > 0) {
            row = core.view.designs[0]
        }
        if (row.id >= 0) {
            yardPage.designChoice.setValue(format("{}", row.id))
            shipDialog.presentRow(window, row)
        }
    }

    /*
     * Map primary-click: fill Fleets dest choice.
     *
     * Purpose: pick-to-dispatch fewest-hoops path — same PUT
     * /order chrome; click only sets destination.
     *
     * Parameters:
     *   planetId — hot-spot rock under the cursor.
     *
     * Returns: nothing.
     */
    void onMapPlanetPicked(int64 planetId) {
        fleetPage.setDestPlanet(planetId)
        if (status != null) {
            status.setText(format(
                "map dest={} (Fleets → Dispatch)", planetId))
        }
    }

    /*
     * Map ContextMenu: dispatch toward the selected rock.
     *
     * Purpose: set dest from selection, raise Fleets panel, then
     * reuse onDispatch (fleet id + order still come from Fleets
     * Entries).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onMapDispatchHere() {
        if (mapPage.selectedId < 0) {
            status.setText("dispatch needs a map planet")
            return()
        }
        fleetPage.setDestPlanet(mapPage.selectedId)
        panels.showFleets()
        onDispatch()
    }

    /*
     * Map ContextMenu: open Planets budget for the rock.
     *
     * Purpose: fill allocation Entry/Scale for an owned planet and
     * raise the Planets panel; Apply still uses PUT /budget.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onMapBudgetHere() {
        if (mapPage.selectedId < 0) {
            status.setText("budget needs a map planet")
            return()
        }
        PlanetRow row = mapPage.selectedPlanet()
        if (row.id < 0 or row.ownerId != core.view.viewerId) {
            status.setText("budget needs an owned planet")
            return()
        }
        planetPage.setPlanetId(row.id)
        panels.showPlanets()
        if (status != null) {
            status.setText(format(
                "budget planet={} (Planets → Apply)", row.id))
        }
    }

    /*
     * Apply policy from Scale / Entry widgets.
     *
     * Purpose: Policy panel Apply — no order warnings.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onApply() {
        policyPage.writeDraft()
        if (core.config.port > 0) {
            if (core.applyDraftRemote()) {
                status.setText("policy applied")
            } else {
                status.setText("policy apply failed")
            }
        } else {
            status.setText("policy draft updated (offline)")
        }
    }

    /*
     * Apply planet budget Scale via PUT /budget.
     *
     * Purpose: Planets panel allocation stand-in (DIALOGS §4.2).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onBudget() {
        int64 planetId = planetPage.planetIdValue()
        int64 pct = planetPage.allocationValue()
        if (core.config.port < 1) {
            PlanetRow row = core.view.findPlanet(planetId)
            if (row.id >= 0 and row.ownerId == core.view.viewerId) {
                row.allocationPct = pct
                status.setText("budget draft (offline)")
            } else {
                status.setText("budget needs owned planet")
            }
            refreshLists()
            return()
        }
        if (core.putBudgetRemote(planetId, pct)) {
            status.setText(format(
                "budget planet={} alloc={}%", planetId, pct))
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("budget apply failed")
        }
    }

    /*
     * Send private / broadcast compose via PUT /message.
     *
     * Purpose: Digest panel compose-to-pick (RULES §13).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onSendMessage() {
        String body = digestPage.bodyValue()
        if (body.length < 1) {
            status.setText("message body empty")
            return()
        }
        bool broadcast = digestPage.broadcastValue()
        int64 toId = digestPage.toValue()
        if (core.config.port < 1) {
            status.setText("compose needs live server")
            return()
        }
        if (core.putMessageRemote(toId, body, broadcast)) {
            if (broadcast) {
                status.setText("broadcast queued")
            } else {
                status.setText(format(
                    "message to {} queued", toId))
            }
            core.pullRemote()
            refreshLists()
        } else {
            status.setText(
                "message failed (need known competitor?)")
        }
    }

    /*
     * Pause CheckButton toggle handler.
     *
     * Purpose: PUT /pause when offered; revert on reject.
     *
     * Parameters:
     *   active — desired CheckButton state.
     *
     * Returns: nothing.
     */
    void onPauseToggled(bool active) {
        if (suppressPauseToggle) {
            return()
        }
        if (not core.view.pauseOffered()) {
            syncPauseChrome()
            status.setText("pause not offered (need 1 human)")
            return()
        }
        if (core.config.port < 1) {
            core.view.paused = active
            status.setText("pause draft (offline)")
            return()
        }
        if (core.putPauseRemote(active)) {
            core.view.paused = active
            if (active) {
                status.setText("pause=on")
            } else {
                status.setText("pause=off")
            }
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("pause rejected")
            syncPauseChrome()
        }
    }

    /*
     * AFK CheckButton toggle handler.
     *
     * Purpose: PUT /suspended so handshake_miss does not drop the
     * seat while the human marks AFK. Revert chrome on reject.
     *
     * Parameters:
     *   active — desired CheckButton state.
     *
     * Returns: nothing.
     */
    void onAfkToggled(bool active) {
        if (suppressAfkToggle) {
            return()
        }
        if (core.config.port < 1) {
            localSuspended = active
            if (active) {
                status.setText("AFK draft (offline)")
            } else {
                status.setText("AFK cleared (offline)")
            }
            return()
        }
        if (core.putSuspendedRemote(active)) {
            localSuspended = active
            if (active) {
                status.setText("AFK=on (suspended)")
            } else {
                status.setText("AFK=off")
            }
            refreshLists()
        } else {
            status.setText("AFK rejected")
            syncAfkChrome()
        }
    }

    /*
     * Dispatch button: PUT /order from fleet Entries.
     *
     * Purpose: exercise explore/take/trade paths in tuning loops.
     * Hulls Entry peels a subset from a sitting multi-hull stack
     * so remaining hulls can be sent to other destinations.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onDispatch() {
        fleetPage.syncFleetChoices()
        int64 fleetId = fleetPage.fleetIdValue()
        String order = fleetPage.orderValue()
        int64 dest = fleetPage.destValue()
        int64 hulls = fleetPage.hullsValue()
        FleetRow row = core.view.findFleet(fleetId)
        if (row.id < 0) {
            String missing = format(
                "fleet {} does not exist in this snapshot — Refresh, or pick a sitting fleet id from the list (yard builds merge into same-design sit stacks; fleets never use id 0)",
                fleetId)
            reportFailure("Dispatch failed", missing)
            return()
        }
        if (row.orderLocked()) {
            status.setText("fleet locked — use Recall")
            fleetPage.syncLockChrome()
            return()
        }
        if (hulls > row.hullCount) {
            String over = format(
                "hulls {} > fleet {} stack {}",
                hulls, fleetId, row.hullCount)
            reportFailure("Dispatch failed", over)
            return()
        }
        if (not row.sitting and hulls > 0) {
            reportFailure(
                "Dispatch failed",
                "hull peel needs a sitting fleet")
            return()
        }
        if (not row.sitting) {
            reportFailure(
                "Dispatch failed",
                format(
                    "fleet {} not sitting (locked or in flight)",
                    fleetId))
            return()
        }
        if (core.config.port < 1) {
            status.setText("dispatch needs live server")
            return()
        }
        if (core.putOrderRemote(fleetId, order, dest, hulls)) {
            String ack = format(
                "dispatched fleet {} {} dest={} hulls={}",
                fleetId, order, dest, hulls)
            status.setText(ack)
            core.pullRemote()
            refreshLists()
        } else {
            String detail = core.lastError
            if (detail.length < 1) {
                detail = format(
                    "dispatch rejected fleet={} order={} dest={} hulls={}",
                    fleetId, order, dest, hulls)
            }
            reportFailure("Dispatch failed", detail)
        }
    }

    /*
     * Recall button: PUT /recall for the fleet Entry id.
     *
     * Purpose: cancel pending or turn in-flight home.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onRecall() {
        int64 fleetId = fleetPage.fleetIdValue()
        if (core.config.port < 1) {
            status.setText("recall needs live server")
            return()
        }
        if (core.putRecallRemote(fleetId)) {
            status.setText(format("recall fleet {}", fleetId))
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("recall failed")
        }
    }

    /*
     * Start develop: PUT /design from Ships panel Entries.
     *
     * Purpose: non-instant design development (RULES §5.3). Status
     * ack is applied after refreshLists so it is not overwritten.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onDevelop() {
        if (core.config.port < 1) {
            status.setText("design needs live server")
            return()
        }
        if (core.putDesignRemote(
            yardPage.nameValue(),
            yardPage.speedValue(),
            yardPage.hopValue(),
            yardPage.sizeValue(),
            yardPage.cargoValue(),
            yardPage.kindValue())) {
            core.pullRemote()
            refreshLists()
            status.setText("design develop queued")
        } else {
            String detail = core.lastError
            if (detail.length < 1) {
                detail = "design develop rejected by server"
            }
            reportFailure("Design develop failed", detail)
        }
    }

    /*
     * Queue build: PUT /build from Ships panel Entries.
     *
     * Purpose: non-instant yard hull production (RULES §5.3).
     * Yard planet defaults to home (0); status ack after refresh.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onBuild() {
        if (core.config.port < 1) {
            status.setText("build needs live server")
            return()
        }
        int64 planetId = yardPage.planetValue()
        int64 designId = yardPage.designIdValue()
        if (core.putBuildRemote(planetId, designId)) {
            core.pullRemote()
            refreshLists()
            status.setText(format(
                "build queued planet={} design={}",
                planetId, designId))
        } else {
            String detail = core.lastError
            if (detail.length < 1) {
                detail = format(
                    "build rejected planet={} design={}",
                    planetId, designId)
            }
            reportFailure("Yard build failed", detail)
        }
    }

    /*
     * Reclaim hulls: PUT /reclaim-hulls from Ships panel Entries.
     *
     * Purpose: yard reclaim path for sitting hulls (RULES §5.2).
     * Status ack is applied after refreshLists.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onReclaimHulls() {
        if (core.config.port < 1) {
            status.setText("reclaim needs live server")
            return()
        }
        int64 fleetId = yardPage.reclaimFleetValue()
        int64 hulls = yardPage.reclaimHullsValue()
        if (core.putReclaimHullsRemote(fleetId, hulls)) {
            core.pullRemote()
            refreshLists()
            status.setText(format(
                "reclaim queued fleet={} hulls={}",
                fleetId, hulls))
        } else {
            String detail = core.lastError
            if (detail.length < 1) {
                detail = format(
                    "reclaim rejected fleet={} hulls={}",
                    fleetId, hulls)
            }
            reportFailure("Reclaim failed", detail)
        }
    }

    /*
     * Quit the application window.
     *
     * Purpose: File→Quit and --test teardown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onClose() {
        panels.closeAll()
        planetDialog.close()
        fleetDialog.close()
        shipDialog.close()
        if (window != null and not window.disposed()) {
            window.close()
        }
    }

    /*
     * Hide explore / fleet / design examine dialogs.
     *
     * Purpose: shared Close button for TransientWindow shells.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onDialogClose() {
        planetDialog.close()
        fleetDialog.close()
        shipDialog.close()
    }

    /*
     * --test path: refresh then quit.
     *
     * Purpose: headless Xvfb smoke without a human.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onTest() {
        refreshLists()
        showFirstExplored()
        Gtk.Application().schedule(200, closeAction)
    }
}
