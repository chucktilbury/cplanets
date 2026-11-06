/*
 * src/client/guiMain.cw — GTK list debugger main window (G).
 *
 * Notebook panes: Planets, Fleets, Digest, Policy. No DrawingArea /
 * map canvas (PLAN §4.I). Talks through AppCore only.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial GuiMain window.
 */

include "appCore.cw"
include "fleetRow.cw"
include "guiPlanetDialog.cw"
include "planetRow.cw"

/*
 * GuiMain owns the human list debugger window.
 *
 * Planet activate opens the explored dialog when qualityKnown.
 * Policy Apply PUTs standing policy with no dumb-order warnings.
 */
class GuiMain {
    AppCore core
    Gtk.Window window
    Gtk.Label status
    Gtk.Label planetList
    Gtk.Label fleetList
    Gtk.Label digestList
    Gtk.Entry roleEntry
    Gtk.Entry expansionEntry
    Gtk.Entry escortEntry
    Gtk.Entry agreementEntry
    Gtk.Entry techEntry
    GuiPlanetDialog planetDialog
    void<> activateAction
    void<> refreshAction
    void<> applyAction
    void<> closeAction
    void<> dialogCloseAction
    void<> showExploredAction
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
        planetList = null
        fleetList = null
        digestList = null
        roleEntry = null
        expansionEntry = null
        escortEntry = null
        agreementEntry = null
        techEntry = null
        planetDialog = GuiPlanetDialog()
        activateAction = null
        refreshAction = null
        applyAction = null
        closeAction = null
        dialogCloseAction = null
        showExploredAction = null
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
        window.setDefaultSize(720, 480)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 0)
        window.setChild(root)
        Gtk.MenuBar menu = Gtk.MenuBar()
        int64 fileMenu = menu.addMenu("File")
        menu.addItem(fileMenu, "Refresh", refreshAction)
        menu.addItem(fileMenu, "Quit", closeAction)
        root.append(menu)
        status = Gtk.Label("Ready")
        root.append(status)
        Gtk.Notebook notebook = Gtk.Notebook()
        notebook.setHExpand(true)
        notebook.setVExpand(true)
        notebook.appendPage(buildPlanetPage(), "Planets")
        notebook.appendPage(buildFleetPage(), "Fleets")
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
     * Build the Fleets notebook page.
     *
     * Purpose: scrolled fleet labels.
     *
     * Parameters: none.
     *
     * Returns: page widget.
     */
    Gtk.Widget buildFleetPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        fleetList = Gtk.Label("(no fleets)")
        fleetList.setHExpand(true)
        fleetList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(fleetList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
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
        String fleets = ""
        index = 0
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
        if (digestList != null) {
            digestList.setText(core.view.digestText())
        }
        if (status != null) {
            status.setText(format(
                "tick={} planets={} fleets={}",
                core.view.tick,
                core.view.visiblePlanetCount(),
                core.view.visibleFleetCount()))
        }
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
        showFirstExplored()
    }

    /*
     * Open explored dialog for the first qualityKnown visible rock.
     *
     * Purpose: exercise RULES §16 dialog without Tree activate.
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
