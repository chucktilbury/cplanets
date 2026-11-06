/*
 * src/client/guiPlanetDialog.cw — explored planet TransientWindow (G).
 *
 * Livability/quality on a 1–10 scale; notes that values may change
 * when populated/productive (RULES §13 / §16). No map canvas.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial explored planet dialog.
 */

include "planetRow.cw"

/*
 * GuiPlanetDialog presents one explored PlanetRow.
 *
 * Uses TransientWindow so it stays list/dialog-only (no
 * DrawingArea — PLAN §4.I deferred).
 */
class GuiPlanetDialog {
    Gtk.TransientWindow window
    Gtk.Label body
    void<> closeAction

    /*
     * Construct an empty dialog shell.
     *
     * Purpose: allocate before presentRow; closeAction set by UI.
     *
     * Parameters: none.
     *
     * Returns: GuiPlanetDialog with null window.
     */
    GuiPlanetDialog() {
        window = null
        body = null
        closeAction = null
    }

    /*
     * Present (or refresh) the dialog for an explored row.
     *
     * Purpose: pop the human explored-planet dialog. No-op when
     * quality is unknown — unexplored rocks get no quality dialog.
     *
     * Parameters:
     *   parent — main debugger window (transient parent).
     *   row — planet list row.
     *
     * Returns: true when a dialog was shown.
     */
    bool presentRow(Gtk.Window parent, PlanetRow row) {
        if (not row.qualityKnown) {
            return(false)
        }
        if (window == null or window.disposed()) {
            window = Gtk.TransientWindow("Explored planet")
            window.setDefaultSize(360, 220)
            window.setTransientFor(parent)
            Gtk.Box layout = Gtk.Box(Gtk.Box.VERTICAL, 8)
            window.setChild(layout)
            body = Gtk.Label("")
            body.setHExpand(true)
            body.setVExpand(true)
            Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
            scroll.setChild(body)
            scroll.setHExpand(true)
            scroll.setVExpand(true)
            layout.append(scroll)
            Gtk.Button close = Gtk.Button("Close")
            if (closeAction != null) {
                close.onClicked(closeAction)
            }
            layout.append(close)
        }
        window.setTitle(format("Planet {}", row.id))
        body.setText(row.exploredDialogText())
        window.present()
        return(true)
    }

    /*
     * Close the dialog if live.
     *
     * Purpose: Close button and teardown.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void close() {
        if (window != null and not window.disposed()) {
            window.close()
        }
    }
}
