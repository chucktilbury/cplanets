/*
 * src/client/guiMain.cw — GTK list debugger main window (G / B).
 *
 * Notebook panes: Planets, Fleets, Ships, Digest, Policy. Pause
 * gated to one human; fleet dispatch/recall via GuiFleetPage;
 * design/yard via GuiYardPage; explored dialog auto-presents on
 * quality / productive changes. No DrawingArea / map canvas
 * (PLAN §4.I).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GuiMain window.
 *   2026-11-06  TUNING B: pause, fleet chrome, explored auto-pop.
 *   2026-11-07  Ships tab: design develop / yard build / reclaim.
 */

include "appCore.cw"
include "exploredTrack.cw"
include "guiFleetPage.cw"
include "guiPlanetDialog.cw"
include "guiYardPage.cw"
include "planetRow.cw"

/*
 * GuiMain owns the human list debugger window.
 *
 * Policy Apply PUTs standing policy with no dumb-order warnings.
 * Pause CheckButton is sensitive only when pauseOffered().
 */
class GuiMain {
    AppCore core
    Gtk.Window window
    Gtk.Label status
    Gtk.CheckButton pauseBtn
    Gtk.Label planetList
    Gtk.Label digestList
    Gtk.Entry roleEntry
    Gtk.Entry expansionEntry
    Gtk.Entry escortEntry
    Gtk.Entry agreementEntry
    Gtk.Entry techEntry
    GuiPlanetDialog planetDialog
    GuiFleetPage fleetPage
    GuiYardPage yardPage
    ExploredTrack explored
    bool suppressPauseToggle
    void<> activateAction
    void<> refreshAction
    void<> applyAction
    void<> closeAction
    void<> dialogCloseAction
    void<> showExploredAction
    void<> dispatchAction
    void<> recallAction
    void<> developAction
    void<> buildAction
    void<> reclaimAction
    void<bool> pauseAction
    void<> testAction
    bool testMode

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
        planetList = null
        digestList = null
        roleEntry = null
        expansionEntry = null
        escortEntry = null
        agreementEntry = null
        techEntry = null
        planetDialog = GuiPlanetDialog()
        fleetPage = GuiFleetPage(appCore)
        yardPage = GuiYardPage(appCore)
        explored = ExploredTrack()
        suppressPauseToggle = false
        activateAction = null
        refreshAction = null
        applyAction = null
        closeAction = null
        dialogCloseAction = null
        showExploredAction = null
        dispatchAction = null
        recallAction = null
        developAction = null
        buildAction = null
        reclaimAction = null
        pauseAction = null
        testAction = null
        testMode = false
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
        window.setDefaultSize(720, 560)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 0)
        window.setChild(root)
        Gtk.MenuBar menu = Gtk.MenuBar()
        int64 fileMenu = menu.addMenu("File")
        menu.addItem(fileMenu, "Refresh", refreshAction)
        menu.addItem(fileMenu, "Quit", closeAction)
        root.append(menu)
        Gtk.Box top = Gtk.Box(Gtk.Box.HORIZONTAL, 8)
        status = Gtk.Label("Ready")
        status.setHExpand(true)
        top.append(status)
        pauseBtn = Gtk.CheckButton("Pause")
        if (pauseAction != null) {
            pauseBtn.onToggled(pauseAction)
        }
        top.append(pauseBtn)
        root.append(top)
        Gtk.Notebook notebook = Gtk.Notebook()
        notebook.setHExpand(true)
        notebook.setVExpand(true)
        notebook.appendPage(buildPlanetPage(), "Planets")
        fleetPage.dispatchAction = dispatchAction
        fleetPage.recallAction = recallAction
        notebook.appendPage(fleetPage.buildPage(), "Fleets")
        yardPage.developAction = developAction
        yardPage.buildAction = buildAction
        yardPage.reclaimAction = reclaimAction
        notebook.appendPage(yardPage.buildPage(), "Ships")
        notebook.appendPage(buildDigestPage(), "Digest")
        notebook.appendPage(buildPolicyPage(), "Policy")
        root.append(notebook)
        planetDialog.closeAction = dialogCloseAction
        window.present()
        refreshLists()
        if (testMode and testAction != null) {
            Gtk.Application().schedule(150, testAction)
        }
    }

    /*
     * Build the Planets notebook page.
     *
     * Purpose: scrolled label list (no DrawingArea).
     *
     * Parameters: none.
     *
     * Returns: page widget.
     */
    Gtk.Widget buildPlanetPage() {
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
        return(page)
    }

    /*
     * Build the Digest notebook page.
     *
     * Purpose: newspaper / GET digest text.
     *
     * Parameters: none.
     *
     * Returns: page widget.
     */
    Gtk.Widget buildDigestPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        digestList = Gtk.Label("(empty)")
        digestList.setHExpand(true)
        digestList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(digestList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        return(page)
    }

    /*
     * Build the Policy editor notebook page.
     *
     * Purpose: standing policy knobs; Apply PUTs without warnings.
     *
     * Parameters: none.
     *
     * Returns: page widget.
     */
    Gtk.Widget buildPolicyPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        roleEntry = Gtk.Entry(core.draft.roleName)
        expansionEntry = Gtk.Entry(
            format("{}", core.draft.expansionPct))
        escortEntry = Gtk.Entry(format("{}", core.draft.escortPct))
        agreementEntry = Gtk.Entry(
            format("{}", core.draft.agreementS))
        techEntry = Gtk.Entry(format("{}", core.draft.techBiasPct))
        page.append(Gtk.Label("Role"))
        page.append(roleEntry)
        page.append(Gtk.Label("Expansion %"))
        page.append(expansionEntry)
        page.append(Gtk.Label("Escort %"))
        page.append(escortEntry)
        page.append(Gtk.Label("Agreement S"))
        page.append(agreementEntry)
        page.append(Gtk.Label("Tech bias %"))
        page.append(techEntry)
        Gtk.Button apply = Gtk.Button("Apply policy")
        apply.onClicked(applyAction)
        page.append(apply)
        return(page)
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
        fleetPage.refresh()
        yardPage.refresh()
        if (digestList != null) {
            digestList.setText(core.view.digestText())
        }
        if (status != null) {
            String pauseBit = ""
            if (core.view.paused) {
                pauseBit = " paused"
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
        if (roleEntry != null) {
            roleEntry.setText(core.draft.roleName)
            expansionEntry.setText(
                format("{}", core.draft.expansionPct))
            escortEntry.setText(
                format("{}", core.draft.escortPct))
            agreementEntry.setText(
                format("{}", core.draft.agreementS))
            techEntry.setText(
                format("{}", core.draft.techBiasPct))
        }
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
     * Purpose: File→Refresh and test hooks.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onRefresh() {
        if (core.config.port > 0) {
            core.pullRemote()
        }
        refreshLists()
    }

    /*
     * Open explored dialog for the first qualityKnown visible rock.
     *
     * Purpose: manual Planets-tab button (still useful offline).
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
     * Apply policy from entry widgets.
     *
     * Purpose: Policy tab Apply — no order warnings.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onApply() {
        core.draft.roleName = roleEntry.text()
        core.draft.expansionPct = expansionEntry.text().toInt64()
        core.draft.escortPct = escortEntry.text().toInt64()
        core.draft.agreementS = agreementEntry.text().toInt64()
        core.draft.techBiasPct = techEntry.text().toInt64()
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
     * Dispatch button: PUT /order from fleet Entries.
     *
     * Purpose: exercise explore/take/trade paths in tuning loops.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onDispatch() {
        int64 fleetId = fleetPage.fleetIdValue()
        String order = fleetPage.orderValue()
        int64 dest = fleetPage.destValue()
        FleetRow row = core.view.findFleet(fleetId)
        if (row.id >= 0 and row.orderLocked()) {
            status.setText("fleet locked — use Recall")
            fleetPage.syncLockChrome()
            return()
        }
        if (core.config.port < 1) {
            status.setText("dispatch needs live server")
            return()
        }
        if (core.putOrderRemote(fleetId, order, dest)) {
            status.setText(format(
                "dispatched fleet {} {}", fleetId, order))
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("dispatch failed")
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
     * Start develop: PUT /design from Ships Entries.
     *
     * Purpose: non-instant design development (RULES §5.3).
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
            status.setText("design develop queued")
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("design develop failed")
        }
    }

    /*
     * Queue build: PUT /build from Ships Entries.
     *
     * Purpose: non-instant yard hull production (RULES §5.3).
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
            status.setText(format(
                "build queued planet={} design={}",
                planetId, designId))
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("build failed")
        }
    }

    /*
     * Reclaim hulls: PUT /reclaim-hulls from Ships Entries.
     *
     * Purpose: yard reclaim path for sitting hulls (RULES §5.2).
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
            status.setText(format(
                "reclaim queued fleet={} hulls={}",
                fleetId, hulls))
            core.pullRemote()
            refreshLists()
        } else {
            status.setText("reclaim failed")
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
        planetDialog.close()
        if (window != null and not window.disposed()) {
            window.close()
        }
    }

    /*
     * Close only the planet dialog.
     *
     * Purpose: dialog Close button.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onDialogClose() {
        planetDialog.close()
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
