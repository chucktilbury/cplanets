/*
 * src/client/guiFleetDialog.cw — fleet examine TransientWindow.
 *
 * Mirrors GuiPlanetDialog: hide-instead-of-destroy shell so Close /
 * WM close stay reusable. Body text comes from FleetRow.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial fleet examine dialog (Section C).
 *   2026-11-09  Close button tooltip (View dialogs usable).
 */

include "fleetRow.cw"

/*
 * GuiFleetDialog presents one FleetRow for human inspect.
 *
 * Uses TransientWindow so it stays list/dialog-only. The shell is
 * created once and hidden on close (same GTK lifecycle as the
 * explored-planet dialog).
 */
class GuiFleetDialog {
    Gtk.TransientWindow window
    Gtk.Label body
    void<> closeAction
    bool<> closeRequestAction
    int64 shownFleetId

    /*
     * Construct an empty dialog shell.
     *
     * Purpose: allocate before presentRow; closeAction set by UI.
     *
     * Parameters: none.
     *
     * Returns: GuiFleetDialog with null window.
     */
    GuiFleetDialog() {
        window = null
        body = null
        closeAction = null
        closeRequestAction = null
        shownFleetId = -1
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
        window = Gtk.TransientWindow("Fleet")
        window.setDefaultSize(360, 260)
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
        close.setTooltip("Hide this fleet examine dialog.")
        if (closeAction != null) {
            close.onClicked(closeAction)
        }
        layout.append(close)
        if (closeRequestAction != null) {
            window.onCloseRequest(closeRequestAction)
        }
    }

    /*
     * Present (or refresh) the dialog for a fleet row.
     *
     * Purpose: pop the human fleet examine dialog. No-op when the
     * row id is invalid. Reuses a hidden shell.
     *
     * Parameters:
     *   parent — main debugger window (transient parent).
     *   row — fleet list row.
     *
     * Returns: true when a dialog was shown.
     */
    bool presentRow(Gtk.Window parent, FleetRow row) {
        if (row.id < 0) {
            return(false)
        }
        ensureWindow(parent)
        shownFleetId = row.id
        window.setTitle(format("Fleet {}", row.id))
        body.setText(row.examineDialogText())
        window.setVisible(true)
        window.present()
        return(true)
    }

    /*
     * Hide the dialog without destroying the native window.
     *
     * Purpose: Close button, WM close-request, and teardown.
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
     * Purpose: title-bar / Escape close must match the Close button.
     *
     * Parameters: none.
     *
     * Returns: true — always hide and inhibit destroy.
     */
    bool onCloseRequest() {
        close()
        return(true)
    }
}
