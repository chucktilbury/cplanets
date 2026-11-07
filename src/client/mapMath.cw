/*
 * src/client/mapMath.cw — pure map transform / status / pick (I).
 *
 * No GTK. Unit-tested helpers for GuiMapPage pan/zoom, hop
 * progress, status colors, and hot-spot pick (PLAN §4.I).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial map math helpers.
 */

import math as MapMathLib

include "fleetRow.cw"
include "planetRow.cw"

/*
 * MapMath converts world coords ↔ widget pixels and derives
 * status RGB plus hop progress from published rows.
 */
class MapMath {
    MapMathLib.Math math
    fp64 pixelsPerUnit

    /*
     * Construct map math with a default world→pixel scale.
     *
     * Purpose: galaxy_radius ≈ 20 maps to a few hundred pixels
     * at zoom 1 without publishing scenario knobs.
     *
     * Parameters: none.
     *
     * Returns: MapMath with pixelsPerUnit 12.
     */
    MapMath() {
        math = MapMathLib.Math()
        pixelsPerUnit = 12.0
    }

    /*
     * Scale factor from world units to screen pixels.
     *
     * Purpose: shared by worldToScreen / screenToWorld.
     *
     * Parameters:
     *   zoom — view zoom (≥ small epsilon).
     *
     * Returns: pixels per world unit at this zoom.
     */
    fp64 scale(fp64 zoom) {
        fp64 z = zoom
        if (z < 0.05) {
            z = 0.05
        }
        return(pixelsPerUnit * z)
    }

    /*
     * Map a world X into widget-local pixels.
     *
     * Purpose: draw planets and hop lines.
     *
     * Parameters:
     *   worldX — planet / path X in galaxy space.
     *   viewW — DrawingArea allocation width.
     *   panX — view pan offset in pixels.
     *   zoom — view zoom.
     *
     * Returns: screen X.
     */
    fp64 worldToScreenX(
        fp64 worldX, fp64 viewW, fp64 panX, fp64 zoom) {
        return(viewW / 2.0 + panX + worldX * scale(zoom))
    }

    /*
     * Map a world Y into widget-local pixels.
     *
     * Purpose: draw planets and hop lines.
     *
     * Parameters:
     *   worldY — planet / path Y in galaxy space.
     *   viewH — DrawingArea allocation height.
     *   panY — view pan offset in pixels.
     *   zoom — view zoom.
     *
     * Returns: screen Y.
     */
    fp64 worldToScreenY(
        fp64 worldY, fp64 viewH, fp64 panY, fp64 zoom) {
        return(viewH / 2.0 + panY + worldY * scale(zoom))
    }

    /*
     * Invert screen X back to world space.
     *
     * Purpose: pick / zoom-focus math.
     *
     * Parameters:
     *   screenX — widget-local X.
     *   viewW — allocation width.
     *   panX — pan X.
     *   zoom — view zoom.
     *
     * Returns: world X.
     */
    fp64 screenToWorldX(
        fp64 screenX, fp64 viewW, fp64 panX, fp64 zoom) {
        return((screenX - viewW / 2.0 - panX) / scale(zoom))
    }

    /*
     * Invert screen Y back to world space.
     *
     * Purpose: pick / zoom-focus math.
     *
     * Parameters:
     *   screenY — widget-local Y.
     *   viewH — allocation height.
     *   panY — pan Y.
     *   zoom — view zoom.
     *
     * Returns: world Y.
     */
    fp64 screenToWorldY(
        fp64 screenY, fp64 viewH, fp64 panY, fp64 zoom) {
        return((screenY - viewH / 2.0 - panY) / scale(zoom))
    }

    /*
     * Status red channel 0..1 for a visible planet.
     *
     * Purpose: green settled-own → red taken-by-other (README).
     *
     * Parameters:
     *   row — published planet.
     *   viewerId — seat id.
     *
     * Returns: red component.
     */
    fp64 statusR(PlanetRow row, int64 viewerId) {
        if (row.ownerId == viewerId) {
            if (row.productive) {
                return(0.20)
            }
            return(0.55)
        }
        if (row.ownerId >= 0) {
            return(0.90)
        }
        if (row.qualityKnown) {
            return(0.35)
        }
        return(0.45)
    }

    /*
     * Status green channel 0..1 for a visible planet.
     *
     * Purpose: accompany statusR / statusB.
     *
     * Parameters:
     *   row — published planet.
     *   viewerId — seat id.
     *
     * Returns: green component.
     */
    fp64 statusG(PlanetRow row, int64 viewerId) {
        if (row.ownerId == viewerId) {
            if (row.productive) {
                return(0.80)
            }
            return(0.70)
        }
        if (row.ownerId >= 0) {
            return(0.22)
        }
        if (row.qualityKnown) {
            return(0.55)
        }
        return(0.48)
    }

    /*
     * Status blue channel 0..1 for a visible planet.
     *
     * Purpose: accompany statusR / statusG.
     *
     * Parameters:
     *   row — published planet.
     *   viewerId — seat id.
     *
     * Returns: blue component.
     */
    fp64 statusB(PlanetRow row, int64 viewerId) {
        if (row.ownerId == viewerId) {
            return(0.25)
        }
        if (row.ownerId >= 0) {
            return(0.18)
        }
        if (row.qualityKnown) {
            return(0.75)
        }
        return(0.55)
    }

    /*
     * Hot-spot radius in screen pixels at the current zoom.
     *
     * Purpose: draw + hit-test size.
     *
     * Parameters:
     *   zoom — view zoom.
     *
     * Returns: circle radius in pixels.
     */
    fp64 hotSpotRadius(fp64 zoom) {
        fp64 r = 7.0 * zoom
        if (r < 4.0) {
            r = 4.0
        }
        if (r > 28.0) {
            r = 28.0
        }
        return(r)
    }

    /*
     * Find the nearest visible planet under a screen point.
     *
     * Purpose: primary-click pick and context-menu target.
     *
     * Parameters:
     *   planets — view.planets list.
     *   screenX — click X.
     *   screenY — click Y.
     *   viewW — allocation width.
     *   viewH — allocation height.
     *   panX — pan X.
     *   panY — pan Y.
     *   zoom — view zoom.
     *
     * Returns: planet id, or -1 when none within hot-spot range.
     */
    int64 pickPlanet(
        list planets,
        fp64 screenX,
        fp64 screenY,
        fp64 viewW,
        fp64 viewH,
        fp64 panX,
        fp64 panY,
        fp64 zoom) {
        fp64 best = hotSpotRadius(zoom) + 2.0
        int64 bestId = -1
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible) {
                fp64 sx = worldToScreenX(row.x, viewW, panX, zoom)
                fp64 sy = worldToScreenY(row.y, viewH, panY, zoom)
                fp64 dx = sx - screenX
                fp64 dy = sy - screenY
                fp64 dist = math.sqrt(dx * dx + dy * dy)
                if (dist <= best) {
                    best = dist
                    bestId = row.id
                }
            }
            index = index + 1
        }
        return(bestId)
    }

    /*
     * Interpolate a point along a hop for the in-transit marker.
     *
     * Purpose: place progress graphic on dotted ETA path.
     *
     * Parameters:
     *   x0 / y0 — origin world coords.
     *   x1 / y1 — destination world coords.
     *   t — 0..1 progress from FleetRow.mapHopProgress.
     *   outIsX — true → return X, false → return Y.
     *
     * Returns: world coordinate at fraction t.
     */
    fp64 lerpAxis(
        fp64 a, fp64 b, fp64 t) {
        return(a + (b - a) * t)
    }

    /*
     * World half-extent used for scrollbar upper bounds.
     *
     * Purpose: cover visible planets with padding.
     *
     * Parameters:
     *   planets — view.planets list.
     *
     * Returns: max(|x|,|y|) among visible rocks, at least 8.
     */
    fp64 worldHalfExtent(list planets) {
        fp64 extent = 8.0
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible) {
                fp64 ax = row.x
                if (ax < 0.0) {
                    ax = -ax
                }
                fp64 ay = row.y
                if (ay < 0.0) {
                    ay = -ay
                }
                if (ax > extent) {
                    extent = ax
                }
                if (ay > extent) {
                    extent = ay
                }
            }
            index = index + 1
        }
        return(extent + 2.0)
    }

    /*
     * Sanity helper: hop progress for unit tests.
     *
     * Purpose: expose FleetRow.mapHopProgress without GTK.
     *
     * Parameters:
     *   fleet — published fleet row.
     *
     * Returns: 0..1 progress.
     */
    fp64 fleetProgress(FleetRow fleet) {
        return(fleet.mapHopProgress())
    }
}
