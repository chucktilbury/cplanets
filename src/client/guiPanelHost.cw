/*
 * src/client/guiPanelHost.cw — View-menu panel dialog host.
 *
 * Owns the five non-modal GuiPanelDialog shells (Planets / Fleets /
 * Ships / Digest / Policy) so GuiMain stays under the CODING soft
 * file-size ceiling. Page widgets still live on GuiMain; this host
 * only wraps, presents, and hides them.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial panel host (menubar rearrange).
 */

include "guiDigestPage.cw"
include "guiFleetPage.cw"
include "guiPanelDialog.cw"
include "guiPlanetPage.cw"
include "guiPolicyPage.cw"
include "guiYardPage.cw"

/*
 * GuiPanelHost wires former Notebook pages into View-menu dialogs.
 *
 * Each panel is a hide-on-close TransientWindow. ProgressBars stay
 * inside the Fleets / Ships page trees adopted as dialog content.
 */
class GuiPanelHost {
    Gtk.Window parent
    GuiPanelDialog planetsPanel
    GuiPanelDialog fleetsPanel
    GuiPanelDialog shipsPanel
    GuiPanelDialog digestPanel
    GuiPanelDialog policyPanel
    void<> showPlanetsAction
    void<> showFleetsAction
    void<> showShipsAction
    void<> showDigestAction
    void<> showPolicyAction

    /*
     * Construct empty panel dialog shells.
     *
     * Purpose: allocate titled TransientWindow wrappers; content
     * is attached later by wire(); parent set in setParent().
     * Menu void<> fields bind to show* methods here so GuiMain
     * can wire the View menu like File→Refresh.
     *
     * Parameters: none.
     *
     * Returns: GuiPanelHost ready for wire / present.
     */
    GuiPanelHost() {
        parent = null
        planetsPanel = GuiPanelDialog("Planets", 420, 520)
        fleetsPanel = GuiPanelDialog("Fleets", 420, 600)
        shipsPanel = GuiPanelDialog("Ships", 440, 680)
        digestPanel = GuiPanelDialog("Digest", 420, 520)
        policyPanel = GuiPanelDialog("Policy", 400, 420)
        showPlanetsAction = showPlanets
        showFleetsAction = showFleets
        showShipsAction = showShips
        showDigestAction = showDigest
        showPolicyAction = showPolicy
    }

    /*
     * Record the main window used as transient parent.
     *
     * Purpose: View-menu void<> actions can call showPlanets()
     * without threading the parent each time.
     *
     * Parameters:
     *   mainWindow — GuiMain's Gtk.Window after create.
     *
     * Returns: nothing.
     */
    void setParent(Gtk.Window mainWindow) {
        parent = mainWindow
    }

    /*
     * Attach page widget trees and hide-on-close handlers.
     *
     * Purpose: one-shot build of Planets / Fleets / Ships / Digest /
     * Policy content into non-modal dialogs. Callers must assign
     * page action fields before wire().
     *
     * Parameters:
     *   planetPage — Planets list + budget page.
     *   fleetPage — Fleets dispatch/recall + ProgressBars.
     *   yardPage — Ships design/yard + ProgressBars.
     *   digestPage — newspaper + compose.
     *   policyPage — standing policy Scales.
     *
     * Returns: nothing.
     */
    void wire(
        GuiPlanetPage planetPage,
        GuiFleetPage fleetPage,
        GuiYardPage yardPage,
        GuiDigestPage digestPage,
        GuiPolicyPage policyPage) {
        planetsPanel.setContent(planetPage.buildPage())
        planetsPanel.closeAction = planetsPanel.close
        planetsPanel.closeRequestAction = planetsPanel.onCloseRequest
        fleetsPanel.setContent(fleetPage.buildPage())
        fleetsPanel.closeAction = fleetsPanel.close
        fleetsPanel.closeRequestAction = fleetsPanel.onCloseRequest
        shipsPanel.setContent(yardPage.buildPage())
        shipsPanel.closeAction = shipsPanel.close
        shipsPanel.closeRequestAction = shipsPanel.onCloseRequest
        digestPanel.setContent(digestPage.buildPage())
        digestPanel.closeAction = digestPanel.close
        digestPanel.closeRequestAction = digestPanel.onCloseRequest
        policyPanel.setContent(policyPage.buildPage())
        policyPanel.closeAction = policyPanel.close
        policyPanel.closeRequestAction = policyPanel.onCloseRequest
    }

    /*
     * Raise the Planets panel dialog.
     *
     * Purpose: View→Planets and map budget ContextMenu bridge.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showPlanets() {
        if (parent == null or parent.disposed()) {
            return()
        }
        planetsPanel.present(parent)
    }

    /*
     * Raise the Fleets panel dialog.
     *
     * Purpose: View→Fleets and map dispatch ContextMenu bridge.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showFleets() {
        if (parent == null or parent.disposed()) {
            return()
        }
        fleetsPanel.present(parent)
    }

    /*
     * Raise the Ships panel dialog.
     *
     * Purpose: View→Ships menu item.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showShips() {
        if (parent == null or parent.disposed()) {
            return()
        }
        shipsPanel.present(parent)
    }

    /*
     * Raise the Digest panel dialog.
     *
     * Purpose: View→Digest menu item.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showDigest() {
        if (parent == null or parent.disposed()) {
            return()
        }
        digestPanel.present(parent)
    }

    /*
     * Raise the Policy panel dialog.
     *
     * Purpose: View→Policy menu item.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showPolicy() {
        if (parent == null or parent.disposed()) {
            return()
        }
        policyPanel.present(parent)
    }

    /*
     * Hide every panel dialog without destroying shells.
     *
     * Purpose: File→Quit / --test teardown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void closeAll() {
        planetsPanel.close()
        fleetsPanel.close()
        shipsPanel.close()
        digestPanel.close()
        policyPanel.close()
    }
}
