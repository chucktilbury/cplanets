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
 *   2026-11-07  Hide-instead-of-destroy lifecycle (cdbg pattern):
 *               Close / WM close-request only hide; avoid present
 *               after destroy and inert Close after Start develop.
 */

include "planetRow.cw"

/*
 * GuiPlanetDialog presents one explored PlanetRow.
 *
 * Uses TransientWindow so it stays list/dialog-only (no
 * DrawingArea — PLAN §4.I deferred). The shell is created once
 * and hidden on close — destroying then presenting again tripped
 * GTK "shown after it has been destroyed" and left Close inert.
 */
class GuiPlanetDialog {
    Gtk.TransientWindow window
    Gtk.Label body
    void<> closeAction
    bool<> closeRequestAction
    int64 shownPlanetId

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
        closeRequestAction = null
        shownPlanetId = -1
    }

    /*
     * Ensure the TransientWindow shell exists for parent.
     *
     * Purpose: create once; recreate only when the native widget
     * was disposed underneath us. Wire Close + close-request so
     * both paths hide instead of destroy.
     *
     * Parameters:
     *   parent — main client window (transient parent).
     *
     * Returns: nothing.
     */
    void ensureWindow(Gtk.Window parent) {
        if (window != null and window.disposed()) {
            window = null
            body = null
        }
        if (window != null) {
            return()
        }
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
        if (closeRequestAction != null) {
            window.onCloseRequest(closeRequestAction)
        }
    }

    /*
     * Present (or refresh) the dialog for an explored row.
     *
     * Purpose: pop the human explored-planet dialog. No-op when
     * quality is unknown — unexplored rocks get no quality dialog.
     * Reuses a hidden shell; never presents a destroyed window.
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
        if (row.id < 0) {
            return(false)
        }
        ensureWindow(parent)
        shownPlanetId = row.id
        window.setTitle(format("Planet {}", row.id))
        body.setText(row.exploredDialogText())
        window.setVisible(true)
        window.present()
        return(true)
    }

    /*
     * Hide the dialog without destroying the native window.
     *
     * Purpose: Close button, WM close-request, and teardown. Hiding
     * keeps the shell reusable so a later presentRow cannot call
     * present() on a destroyed GtkWindow.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void close() {
        if (window != null and not window.disposed()) {
            window.setVisible(false)
        }
    }

    /*
     * close-request handler: hide and stop default destroy.
     *
     * Purpose: title-bar / Escape close must match the Close button
     * (hide-only). Returning true tells GTK not to destroy.
     *
     * Parameters: none.
     *
     * Returns: true — always hide and inhibit destroy.
     */
    bool onCloseRequest() {
        close()
        return(true)
    }

    /*
     * Planet id currently shown (or last shown) in the dialog.
     *
     * Purpose: tests / status hints; −1 when never presented.
     *
     * Parameters: none.
     *
     * Returns: last presentRow planet id, or −1.
     */
    int64 currentPlanetId() {
        return(shownPlanetId)
    }
}
