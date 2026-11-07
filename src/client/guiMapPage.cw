/*
 * src/client/guiMapPage.cw — Phase I map canvas panel.
 *
 * DrawingArea + pan/zoom + Scrollbars + ContextMenu (status +
 * zoom-to-known). Draws visible planets with status colors and
 * in-flight dotted ETA paths when outboundEta is published.
 * List notebook stays alongside via GuiMain Paned (PLAN §4.I).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial map panel wiring.
 */

include "appCore.cw"
include "fleetRow.cw"
include "mapMath.cw"
include "mapZoomAction.cw"
include "planetRow.cw"

/*
 * GuiMapPage owns the map DrawingArea and view chrome.
 *
 * Transform is client-side (drawing.cw path 2): Scrollbars track
 * pan/zoom extents; mouse drag pans; wheel zooms; primary click
 * picks; right-click rebuilds ContextMenu.
 */
class GuiMapPage {
    AppCore core
    MapMath math
    Gtk.DrawingArea area
    Gtk.Scrollbar hBar
    Gtk.Scrollbar vBar
    Gtk.ContextMenu menu
    Gtk.Label pickLabel
    list zoomSlots
    int64 selectedId
    int64 menuPlanetId
    fp64 panX
    fp64 panY
    fp64 dragOriginX
    fp64 dragOriginY
    fp64 zoom
    fp64 viewW
    fp64 viewH
    bool syncingBars
    void<> showExploredAction
    void<int64, int64> paintAction
    void<int64, fp64, fp64> clickAction
    void<int64, fp64, fp64, fp64, fp64> dragAction
    void<fp64, fp64, fp64, fp64> scrollAction
    void<fp64, fp64> popupAction
    void<fp64> hScrollAction
    void<fp64> vScrollAction
    void<> showSelectedAction
    void<int64> zoomPlanetAction

    /*
     * Construct a map page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiMapPage ready for buildPage.
     */
    GuiMapPage(AppCore appCore) {
        core = appCore
        math = MapMath()
        area = null
        hBar = null
        vBar = null
        menu = null
        pickLabel = null
        zoomSlots = []
        selectedId = -1
        menuPlanetId = -1
        panX = 0.0
        panY = 0.0
        dragOriginX = 0.0
        dragOriginY = 0.0
        zoom = 1.0
        viewW = 1.0
        viewH = 1.0
        syncingBars = false
        showExploredAction = null
        paintAction = null
        clickAction = null
        dragAction = null
        scrollAction = null
        popupAction = null
        hScrollAction = null
        vScrollAction = null
        showSelectedAction = null
        zoomPlanetAction = null
    }

    /*
     * Build the map panel widget tree.
     *
     * Purpose: Grid with DrawingArea + Scrollbars + pick label.
     * Callers must assign paint/click/drag/scroll/popup/bar
     * actions with an explicit receiver before buildPage
     * (same pattern as GuiMain File menu wiring).
     *
     * Parameters: none.
     *
     * Returns: page widget for Paned / Notebook.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 4)
        pickLabel = Gtk.Label("Map: click to pick; drag pan; wheel zoom")
        pickLabel.setHExpand(true)
        page.append(pickLabel)
        Gtk.Grid layout = Gtk.Grid(0)
        layout.setHExpand(true)
        layout.setVExpand(true)
        area = Gtk.DrawingArea()
        area.setHExpand(true)
        area.setVExpand(true)
        area.setContentSize(480, 360)
        area.onDraw(paintAction)
        area.onClick(clickAction)
        area.onDrag(dragAction)
        area.onScroll(scrollAction)
        hBar = Gtk.Scrollbar(Gtk.Scrollbar.HORIZONTAL)
        vBar = Gtk.Scrollbar(Gtk.Scrollbar.VERTICAL)
        hBar.onValueChanged(hScrollAction)
        vBar.onValueChanged(vScrollAction)
        layout.attach(area, 0, 0, 1, 1)
        layout.attach(vBar, 1, 0, 1, 1)
        layout.attach(hBar, 0, 1, 1, 1)
        menu = Gtk.ContextMenu(area)
        menu.onPopup(popupAction)
        page.append(layout)
        return(page)
    }

    /*
     * Refresh the canvas after a state pull / offline fill.
     *
     * Purpose: GuiMain.refreshLists hook.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (area != null) {
            area.queueDraw()
        }
        updatePickLabel()
    }

    /*
     * Update the pick status line under the canvas.
     *
     * Purpose: show selected planet without a second panel.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void updatePickLabel() {
        if (pickLabel == null) {
            return()
        }
        if (selectedId < 0) {
            pickLabel.setText(
                "Map: click to pick; drag pan; wheel zoom")
            return()
        }
        PlanetRow row = core.view.findPlanet(selectedId)
        if (row.id < 0) {
            pickLabel.setText(format("Selected planet {}", selectedId))
            return()
        }
        pickLabel.setText(row.mapStatusLabel(core.view.viewerId))
    }

    /*
     * Paint callback: clear, hop paths, planet hot spots.
     *
     * Purpose: DrawingArea.onDraw.
     *
     * Parameters:
     *   width — allocation width.
     *   height — allocation height.
     *
     * Returns: nothing.
     */
    void onPaint(int64 width, int64 height) {
        viewW = fp64(width)
        viewH = fp64(height)
        area.setColor(0.08, 0.09, 0.14, 1.0)
        area.fillRect(0.0, 0.0, viewW, viewH)
        drawFleetPaths()
        drawPlanets()
        syncBars()
    }

    /*
     * Stroke in-flight dotted ETA paths for visible fleets.
     *
     * Purpose: README hop line with progress marker. Dash is
     * simulated with short strokeLine segments (no dash API yet).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void drawFleetPaths() {
        int64 index = 0
        while (index < core.view.fleets.length) {
            FleetRow fleet = core.view.fleets[index]
            if (fleet.visible and fleet.mapPathActive()) {
                PlanetRow origin = core.view.findPlanet(
                    fleet.locationPlanetId)
                PlanetRow dest = core.view.findPlanet(
                    fleet.destPlanetId)
                if (origin.id >= 0 and dest.id >= 0) {
                    strokeDottedHop(origin, dest, fleet.mapHopProgress())
                }
            }
            index = index + 1
        }
    }

    /*
     * Draw one dotted hop and a progress marker.
     *
     * Purpose: path chrome for a single in-flight fleet.
     *
     * Parameters:
     *   origin — location rock.
     *   dest — destination rock.
     *   progress — 0..1 along the hop.
     *
     * Returns: nothing.
     */
    void strokeDottedHop(
        PlanetRow origin, PlanetRow dest, fp64 progress) {
        fp64 x0 = math.worldToScreenX(origin.x, viewW, panX, zoom)
        fp64 y0 = math.worldToScreenY(origin.y, viewH, panY, zoom)
        fp64 x1 = math.worldToScreenX(dest.x, viewW, panX, zoom)
        fp64 y1 = math.worldToScreenY(dest.y, viewH, panY, zoom)
        area.setColor(0.75, 0.78, 0.90, 0.85)
        area.setLineWidth(1.5)
        fp64 dx = x1 - x0
        fp64 dy = y1 - y0
        fp64 len = math.math.sqrt(dx * dx + dy * dy)
        if (len < 1.0) {
            return()
        }
        fp64 step = 10.0
        fp64 pos = 0.0
        bool draw = true
        while (pos < len) {
            fp64 a = pos / len
            fp64 b = (pos + 5.0) / len
            if (b > 1.0) {
                b = 1.0
            }
            if (draw) {
                area.strokeLine(
                    x0 + dx * a, y0 + dy * a,
                    x0 + dx * b, y0 + dy * b)
            }
            draw = not draw
            pos = pos + step
        }
        fp64 t = progress
        if (t < 0.0) {
            t = 0.0
        }
        if (t > 1.0) {
            t = 1.0
        }
        fp64 mx = x0 + dx * t
        fp64 my = y0 + dy * t
        area.setColor(0.95, 0.85, 0.30, 1.0)
        area.fillCircle(mx, my, 4.0)
    }

    /*
     * Fill visible planet hot spots with status colors.
     *
     * Purpose: main map content.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void drawPlanets() {
        int64 viewer = core.view.viewerId
        int64 index = 0
        while (index < core.view.planets.length) {
            PlanetRow row = core.view.planets[index]
            if (row.visible) {
                fp64 sx = math.worldToScreenX(
                    row.x, viewW, panX, zoom)
                fp64 sy = math.worldToScreenY(
                    row.y, viewH, panY, zoom)
                fp64 radius = math.hotSpotRadius(zoom)
                area.setColor(
                    math.statusR(row, viewer),
                    math.statusG(row, viewer),
                    math.statusB(row, viewer),
                    1.0)
                area.fillCircle(sx, sy, radius)
                if (row.id == selectedId) {
                    area.setColor(1.0, 1.0, 1.0, 0.95)
                    area.setLineWidth(2.0)
                    area.strokeCircle(sx, sy, radius + 3.0)
                }
            }
            index = index + 1
        }
    }

    /*
     * Sync scrollbar adjustments to pan/zoom extents.
     *
     * Purpose: drawing.cw path-2 chrome.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncBars() {
        if (hBar == null or vBar == null) {
            return()
        }
        fp64 half = math.worldHalfExtent(core.view.planets)
        fp64 world = half * 2.0 * math.scale(zoom)
        fp64 pageW = viewW
        fp64 pageH = viewH
        if (pageW < 1.0) {
            pageW = 1.0
        }
        if (pageH < 1.0) {
            pageH = 1.0
        }
        fp64 upperW = world
        fp64 upperH = world
        if (upperW < pageW) {
            upperW = pageW
        }
        if (upperH < pageH) {
            upperH = pageH
        }
        syncingBars = true
        hBar.configure(-panX, 0.0, upperW, 16.0, pageW, pageW)
        vBar.configure(-panY, 0.0, upperH, 16.0, pageH, pageH)
        syncingBars = false
    }

    /*
     * Primary-click pick of a planet hot spot.
     *
     * Purpose: DrawingArea.onClick.
     *
     * Parameters:
     *   button — GDK button number.
     *   x / y — widget-local coords.
     *
     * Returns: nothing.
     */
    void onClick(int64 button, fp64 x, fp64 y) {
        if (button != Gtk.DrawingArea.BUTTON_PRIMARY) {
            return()
        }
        selectedId = math.pickPlanet(
            core.view.planets, x, y, viewW, viewH, panX, panY, zoom)
        updatePickLabel()
        area.queueDraw()
    }

    /*
     * Primary-button drag pan.
     *
     * Purpose: DrawingArea.onDrag.
     *
     * Parameters:
     *   phase — DRAG_BEGIN / UPDATE / END.
     *   startX / startY — press point.
     *   offsetX / offsetY — drag delta.
     *
     * Returns: nothing.
     */
    void onDrag(
        int64 phase,
        fp64 startX,
        fp64 startY,
        fp64 offsetX,
        fp64 offsetY) {
        if (phase == Gtk.DrawingArea.DRAG_BEGIN) {
            dragOriginX = panX
            dragOriginY = panY
        }
        panX = dragOriginX + offsetX
        panY = dragOriginY + offsetY
        area.queueDraw()
    }

    /*
     * Wheel zoom about the pointer.
     *
     * Purpose: DrawingArea.onScroll.
     *
     * Parameters:
     *   x / y — focus point.
     *   dx / dy — scroll deltas (dy drives zoom).
     *
     * Returns: nothing.
     */
    void onScroll(fp64 x, fp64 y, fp64 dx, fp64 dy) {
        fp64 before = zoom
        if (dy < 0.0) {
            zoom = zoom * 1.1
        }
        if (dy > 0.0) {
            zoom = zoom / 1.1
        }
        if (zoom < 0.25) {
            zoom = 0.25
        }
        if (zoom > 4.0) {
            zoom = 4.0
        }
        if (zoom != before) {
            fp64 wx = math.screenToWorldX(x, viewW, panX, before)
            fp64 wy = math.screenToWorldY(y, viewH, panY, before)
            panX = x - viewW / 2.0 - wx * math.scale(zoom)
            panY = y - viewH / 2.0 - wy * math.scale(zoom)
        }
        area.queueDraw()
    }

    /*
     * Horizontal scrollbar moved the view.
     *
     * Purpose: Scrollbar.onValueChanged.
     *
     * Parameters:
     *   value — adjustment value.
     *
     * Returns: nothing.
     */
    void onHScroll(fp64 value) {
        if (syncingBars) {
            return()
        }
        panX = -value
        area.queueDraw()
    }

    /*
     * Vertical scrollbar moved the view.
     *
     * Purpose: Scrollbar.onValueChanged.
     *
     * Parameters:
     *   value — adjustment value.
     *
     * Returns: nothing.
     */
    void onVScroll(fp64 value) {
        if (syncingBars) {
            return()
        }
        panY = -value
        area.queueDraw()
    }

    /*
     * Rebuild ContextMenu for the right-clicked planet / view.
     *
     * Purpose: status items + zoom-to-known list (DIALOGS §3).
     *
     * Parameters:
     *   x / y — owner-local popup coords.
     *
     * Returns: nothing.
     */
    void onPopup(fp64 x, fp64 y) {
        menuPlanetId = math.pickPlanet(
            core.view.planets, x, y, viewW, viewH, panX, panY, zoom)
        if (menuPlanetId >= 0) {
            selectedId = menuPlanetId
            updatePickLabel()
        }
        menu.clear()
        zoomSlots = []
        if (menuPlanetId >= 0) {
            PlanetRow row = core.view.findPlanet(menuPlanetId)
            menu.addItem(
                row.mapStatusLabel(core.view.viewerId),
                showSelectedAction)
            menu.addSeparator()
            if (row.qualityKnown) {
                menu.addItem(
                    "Open explored dialog", showSelectedAction)
            }
        } else {
            menu.addItem("(no planet under cursor)", showSelectedAction)
        }
        menu.addSeparator()
        int64 places = menu.addSubmenu("Zoom to known")
        int64 index = 0
        int64 added = 0
        while (index < core.view.planets.length) {
            PlanetRow rock = core.view.planets[index]
            if (rock.visible) {
                MapZoomAction slot = MapZoomAction()
                slot.planetId = rock.id
                slot.zoomAction = zoomPlanetAction
                slot.fireAction = slot.fire
                zoomSlots.append(slot)
                menu.addItem(
                    places,
                    format("Planet {}", rock.id),
                    slot.fireAction)
                added = added + 1
            }
            index = index + 1
        }
        if (added < 1) {
            menu.addItem(places, "(none visible)", showSelectedAction)
        }
        area.queueDraw()
    }

    /*
     * Context menu: open explored dialog for the selected rock.
     *
     * Purpose: status / explored entry without inventing dispatch.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onShowSelected() {
        if (showExploredAction != null and selectedId >= 0) {
            PlanetRow row = core.view.findPlanet(selectedId)
            if (row.qualityKnown) {
                showExploredAction()
            }
        }
    }

    /*
     * Center the view on a known planet id.
     *
     * Purpose: ContextMenu zoom-to-known targets.
     *
     * Parameters:
     *   planetId — rock to focus.
     *
     * Returns: nothing.
     */
    void zoomToPlanet(int64 planetId) {
        PlanetRow row = core.view.findPlanet(planetId)
        if (row.id < 0) {
            return()
        }
        selectedId = planetId
        if (zoom < 1.0) {
            zoom = 1.0
        }
        panX = -row.x * math.scale(zoom)
        panY = -row.y * math.scale(zoom)
        updatePickLabel()
        if (area != null) {
            area.queueDraw()
        }
    }

    /*
     * Present the explored dialog for the currently selected id.
     *
     * Purpose: GuiMain bridges showExploredAction to a specific
     * planet by reading selectedId here first — callers that need
     * the row use selectedPlanet().
     *
     * Parameters: none.
     *
     * Returns: selected PlanetRow (may be empty).
     */
    PlanetRow selectedPlanet() {
        return(core.view.findPlanet(selectedId))
    }
}
