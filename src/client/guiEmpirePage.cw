/*
 * src/client/guiEmpirePage.cw — Empire dialog page.
 *
 * Empire-pool inventory overview: wealth / resources / tech,
 * owned planets, fleets, and unassigned stock (RULES §2 / §16).
 * Non-modal Apply+Close; Apply refreshes the snapshot (CPL-111).
 *
 * Created: 2026-11-11
 * Author: Auto
 *
 * Changelog:
 *   2026-11-11  Initial Empire inventory dialog page.
 */

include "appCore.cw"
include "fleetRow.cw"
include "planetRow.cw"

/*
 * GuiEmpirePage owns the Empire dialog widgets.
 *
 * Shows seat pool totals and location-scoped presence summaries
 * without inventing a second wealth bank (RULES §2 inventory).
 */
class GuiEmpirePage {
    AppCore core
    Gtk.Label poolsLabel
    Gtk.Label planetsLabel
    Gtk.Label fleetsLabel
    Gtk.Label stockLabel

    /*
     * Construct an Empire page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiEmpirePage ready for buildPage.
     */
    GuiEmpirePage(AppCore appCore) {
        core = appCore
        poolsLabel = null
        planetsLabel = null
        fleetsLabel = null
        stockLabel = null
    }

    /*
     * Build the Empire dialog widget tree.
     *
     * Purpose: empire pool + planets + fleets + stock lists.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        page.append(Gtk.Label("Empire inventory (pool + presence)"))
        poolsLabel = Gtk.Label("(pools)")
        poolsLabel.setHExpand(true)
        poolsLabel.setTooltip(
            "Seat wealth / resources / tech (empire pool).")
        page.append(poolsLabel)
        page.append(Gtk.Label("Owned planets"))
        planetsLabel = Gtk.Label("(planets)")
        planetsLabel.setHExpand(true)
        planetsLabel.setVExpand(true)
        Gtk.ScrolledWindow planetScroll = Gtk.ScrolledWindow()
        planetScroll.setChild(planetsLabel)
        planetScroll.setHExpand(true)
        planetScroll.setVExpand(true)
        page.append(planetScroll)
        page.append(Gtk.Label("Fleets"))
        fleetsLabel = Gtk.Label("(fleets)")
        fleetsLabel.setHExpand(true)
        fleetsLabel.setVExpand(true)
        Gtk.ScrolledWindow fleetScroll = Gtk.ScrolledWindow()
        fleetScroll.setChild(fleetsLabel)
        fleetScroll.setHExpand(true)
        fleetScroll.setVExpand(true)
        page.append(fleetScroll)
        page.append(Gtk.Label("Unassigned stock"))
        stockLabel = Gtk.Label("(stock)")
        stockLabel.setHExpand(true)
        page.append(stockLabel)
        return(page)
    }

    /*
     * Refresh empire pool and presence lists from core.view.
     *
     * Purpose: after pull or Empire Apply.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (poolsLabel != null) {
            poolsLabel.setText(format(
                "Seat: {}\nWealth milli: {}\nResources milli: {}\nTech: (see Policy)\nDesigns: {}\n",
                core.view.playerDisplayName(core.view.viewerId),
                core.view.wealthMilli,
                core.view.resourcesMilli,
                core.view.designs.length))
        }
        if (planetsLabel != null) {
            String text = ""
            int64 index = 0
            while (index < core.view.planets.length) {
                PlanetRow row = core.view.planets[index]
                if (row.visible
                    and row.ownerId == core.view.viewerId) {
                    text.append(row.listLabel())
                    text.append("\n")
                }
                index = index + 1
            }
            if (text.length < 1) {
                text = "(no owned planets)\n"
            }
            planetsLabel.setText(text)
        }
        if (fleetsLabel != null) {
            String text = ""
            int64 index = 0
            while (index < core.view.fleets.length) {
                FleetRow row = core.view.fleets[index]
                if (row.visible
                    and row.ownerId == core.view.viewerId
                    and row.id >= 1) {
                    text.append(row.listLabel())
                    text.append("\n")
                }
                index = index + 1
            }
            if (text.length < 1) {
                text = "(no fleets — create then assign stock)\n"
            }
            fleetsLabel.setText(text)
        }
        if (stockLabel != null) {
            stockLabel.setText(core.view.stocksListText())
        }
    }
}
