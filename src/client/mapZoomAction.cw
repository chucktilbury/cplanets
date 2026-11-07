/*
 * src/client/mapZoomAction.cw — per-planet zoom menu slot (I).
 *
 * ContextMenu items need distinct void<> callbacks; each slot
 * stores one planet id and invokes a void<int64> zoom action.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial zoom action slot.
 */

/*
 * MapZoomAction is one ContextMenu "zoom to known" row callback.
 *
 * GuiMapPage retains the list so receivers stay alive across the
 * popup.
 */
class MapZoomAction {
    void<int64> zoomAction
    int64 planetId
    void<> fireAction

    /*
     * Construct an empty slot.
     *
     * Purpose: fill fields then wire() before addItem.
     *
     * Parameters: none.
     *
     * Returns: MapZoomAction with null actions.
     */
    MapZoomAction() {
        zoomAction = null
        planetId = -1
        fireAction = null
    }

    /*
     * Menu activate: invoke zoomAction(planetId).
     *
     * Purpose: ContextMenu addItem callback. Callers set
     * fireAction = slot.fire with an explicit receiver.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void fire() {
        if (zoomAction != null and planetId >= 0) {
            zoomAction(planetId)
        }
    }
}
