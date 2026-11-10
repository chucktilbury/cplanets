/*
 * src/client/guiPanelHost.cw — Menubar panel dialog host.
 *
 * Owns non-modal GuiPanelDialog shells: Planets / Digest / Policy
 * root openers plus Ships and Fleets submenu dialogs (CPL-110).
 * Page widgets still live on GuiMain; this host wraps, presents,
 * and hides them.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial panel host (menubar rearrange).
 *   2026-11-09  Openers are top-level menubar menus (not View).
 *   2026-11-09  Openers are root click Buttons (no Open submenu).
 *   2026-11-10  CPL-110: Ships/Fleets submenu dialogs.
 */

include "guiDigestPage.cw"
include "guiFleetAssignPage.cw"
include "guiFleetCreatePage.cw"
include "guiFleetDeployPage.cw"
include "guiFleetInventoryPage.cw"
include "guiPanelDialog.cw"
include "guiPlanetPage.cw"
include "guiPolicyPage.cw"
include "guiShipBuildPage.cw"
include "guiShipDevelopPage.cw"
include "guiShipInventoryPage.cw"
include "guiShipReclaimPage.cw"

/*
 * GuiPanelHost wires menubar chrome into non-modal dialogs.
 *
 * Each panel is a hide-on-close TransientWindow. Ships and Fleets
 * are submenu dialogs with Apply + Close; Planets / Digest / Policy
 * keep Close-only footers (Apply lives in page content).
 */
class GuiPanelHost {
    Gtk.Window parent
    GuiPanelDialog planetsPanel
    GuiPanelDialog digestPanel
    GuiPanelDialog policyPanel
    GuiPanelDialog shipDevelopPanel
    GuiPanelDialog shipBuildPanel
    GuiPanelDialog shipReclaimPanel
    GuiPanelDialog shipInventoryPanel
    GuiPanelDialog fleetCreatePanel
    GuiPanelDialog fleetAssignPanel
    GuiPanelDialog fleetDeployPanel
    GuiPanelDialog fleetInventoryPanel
    void<> showPlanetsAction
    void<> showDigestAction
    void<> showPolicyAction
    void<> showShipDevelopAction
    void<> showShipBuildAction
    void<> showShipReclaimAction
    void<> showShipInventoryAction
    void<> showFleetCreateAction
    void<> showFleetAssignAction
    void<> showFleetDeployAction
    void<> showFleetInventoryAction

    /*
     * Construct empty panel dialog shells.
     *
     * Purpose: allocate titled TransientWindow wrappers; content
     * is attached later by wire(); parent set in setParent().
     * show*Action fields stay null until GuiMain binds them.
     *
     * Parameters: none.
     *
     * Returns: GuiPanelHost ready for wire / present.
     */
    GuiPanelHost() {
        parent = null
        planetsPanel = GuiPanelDialog("Planets", 420, 520)
        digestPanel = GuiPanelDialog("Digest", 420, 520)
        policyPanel = GuiPanelDialog("Policy", 400, 420)
        shipDevelopPanel = GuiPanelDialog("Ships — Develop", 420, 520)
        shipBuildPanel = GuiPanelDialog("Ships — Build", 400, 420)
        shipReclaimPanel = GuiPanelDialog("Ships — Reclaim", 420, 560)
        shipInventoryPanel = GuiPanelDialog(
            "Ships — Inventory", 440, 520)
        fleetCreatePanel = GuiPanelDialog("Fleets — Create", 400, 320)
        fleetAssignPanel = GuiPanelDialog("Fleets — Assign", 400, 420)
        fleetDeployPanel = GuiPanelDialog("Fleets — Deploy", 420, 560)
        fleetInventoryPanel = GuiPanelDialog(
            "Fleets — Inventory", 420, 520)
        showPlanetsAction = null
        showDigestAction = null
        showPolicyAction = null
        showShipDevelopAction = null
        showShipBuildAction = null
        showShipReclaimAction = null
        showShipInventoryAction = null
        showFleetCreateAction = null
        showFleetAssignAction = null
        showFleetDeployAction = null
        showFleetInventoryAction = null
    }

    /*
     * Record the main window used as transient parent.
     *
     * Purpose: menubar void<> actions can call show* without
     * threading the parent each time.
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
     * Attach page widget trees, Apply actions, and hide-on-close.
     *
     * Purpose: one-shot build of all menubar dialogs. Callers must
     * assign page action fields and dialog applyAction fields
     * before wire() where needed.
     *
     * Parameters:
     *   planetPage — Planets list + budget page.
     *   digestPage — newspaper + compose.
     *   policyPage — standing policy Scales.
     *   shipDevelop — Ships→Develop page.
     *   shipBuild — Ships→Build page.
     *   shipReclaim — Ships→Reclaim page.
     *   shipInventory — Ships→Inventory page.
     *   fleetCreate — Fleets→Create page.
     *   fleetAssign — Fleets→Assign page.
     *   fleetDeploy — Fleets→Deploy page.
     *   fleetInventory — Fleets→Inventory page.
     *
     * Returns: nothing.
     */
    void wire(
        GuiPlanetPage planetPage,
        GuiDigestPage digestPage,
        GuiPolicyPage policyPage,
        GuiShipDevelopPage shipDevelop,
        GuiShipBuildPage shipBuild,
        GuiShipReclaimPage shipReclaim,
        GuiShipInventoryPage shipInventory,
        GuiFleetCreatePage fleetCreate,
        GuiFleetAssignPage fleetAssign,
        GuiFleetDeployPage fleetDeploy,
        GuiFleetInventoryPage fleetInventory) {
        wireShell(planetsPanel, planetPage.buildPage())
        wireShell(digestPanel, digestPage.buildPage())
        wireShell(policyPanel, policyPage.buildPage())
        wireShell(shipDevelopPanel, shipDevelop.buildPage())
        wireShell(shipBuildPanel, shipBuild.buildPage())
        wireShell(shipReclaimPanel, shipReclaim.buildPage())
        wireShell(shipInventoryPanel, shipInventory.buildPage())
        wireShell(fleetCreatePanel, fleetCreate.buildPage())
        wireShell(fleetAssignPanel, fleetAssign.buildPage())
        wireShell(fleetDeployPanel, fleetDeploy.buildPage())
        wireShell(fleetInventoryPanel, fleetInventory.buildPage())
    }

    /*
     * Attach content and Close hide-on-close for one shell.
     *
     * Purpose: shared wire() helper; Apply must already be set on
     * the dialog when wanted (before ensureWindow).
     *
     * Parameters:
     *   panel — dialog shell.
     *   content — page.buildPage() widget tree.
     *
     * Returns: nothing.
     */
    void wireShell(GuiPanelDialog panel, Gtk.Widget content) {
        panel.setContent(content)
        panel.closeAction = panel.close
        panel.closeRequestAction = panel.onCloseRequest
    }

    /*
     * Raise the Planets panel dialog.
     *
     * Purpose: Planets root click and map budget ContextMenu bridge.
     *
     * Parameters: none (uses setParent window).
     *
     * Returns: nothing.
     */
    void showPlanets() {
        present(planetsPanel)
    }

    /*
     * Raise the Digest panel dialog.
     *
     * Purpose: Digest root click opener.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showDigest() {
        present(digestPanel)
    }

    /*
     * Raise the Policy panel dialog.
     *
     * Purpose: Policy root click opener.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showPolicy() {
        present(policyPanel)
    }

    /*
     * Raise Ships→Develop.
     *
     * Purpose: Ships menu Develop item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showShipDevelop() {
        present(shipDevelopPanel)
    }

    /*
     * Raise Ships→Build.
     *
     * Purpose: Ships menu Build item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showShipBuild() {
        present(shipBuildPanel)
    }

    /*
     * Raise Ships→Reclaim.
     *
     * Purpose: Ships menu Reclaim item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showShipReclaim() {
        present(shipReclaimPanel)
    }

    /*
     * Raise Ships→Inventory.
     *
     * Purpose: Ships menu Inventory item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showShipInventory() {
        present(shipInventoryPanel)
    }

    /*
     * Raise Fleets→Create.
     *
     * Purpose: Fleets menu Create item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFleetCreate() {
        present(fleetCreatePanel)
    }

    /*
     * Raise Fleets→Assign.
     *
     * Purpose: Fleets menu Assign item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFleetAssign() {
        present(fleetAssignPanel)
    }

    /*
     * Raise Fleets→Deploy.
     *
     * Purpose: Fleets menu Deploy item and map dispatch bridge.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFleetDeploy() {
        present(fleetDeployPanel)
    }

    /*
     * Raise Fleets→Inventory.
     *
     * Purpose: Fleets menu Inventory item.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void showFleetInventory() {
        present(fleetInventoryPanel)
    }

    /*
     * Present one panel when the parent window is live.
     *
     * Purpose: shared show* guard.
     *
     * Parameters:
     *   panel — dialog to raise.
     *
     * Returns: nothing.
     */
    void present(GuiPanelDialog panel) {
        if (parent == null or parent.disposed()) {
            return()
        }
        panel.present(parent)
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
        digestPanel.close()
        policyPanel.close()
        shipDevelopPanel.close()
        shipBuildPanel.close()
        shipReclaimPanel.close()
        shipInventoryPanel.close()
        fleetCreatePanel.close()
        fleetAssignPanel.close()
        fleetDeployPanel.close()
        fleetInventoryPanel.close()
    }
}
