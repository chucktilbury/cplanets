/*
 * src/client/guiShipDialog.cw — design / ship examine TransientWindow.
 *
 * Mirrors GuiPlanetDialog / GuiFleetDialog: hide-instead-of-destroy
 * shell. Body text comes from DesignRow (catalog inspect).
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial design examine dialog (Section C).
 *   2026-11-09  Close button tooltip (View dialogs usable).
 */

include "designRow.cw"

/*
 * GuiShipDialog presents one DesignRow for human inspect.
 *
 * Ships-tab "examine" was previously a scrolled Label dump only.
 * This TransientWindow is the focused inspect surface.
 */
class GuiShipDialog {
    Gtk.TransientWindow window
    Gtk.Label body
    void<> closeAction
    bool<> closeRequestAction
    int64 shownDesignId

    /*
     * Construct an empty dialog shell.
     *
     * Purpose: allocate before presentRow; closeAction set by UI.
     *
     * Parameters: none.
     *
     * Returns: GuiShipDialog with null window.
     */
    GuiShipDialog() {
        window = null
        body = null
        closeAction = null
        closeRequestAction = null
        shownDesignId = -1
    }

    /*
     * Ensure the TransientWindow shell exists for parent.
     *
     * Purpose: create once; recreate only when disposed. Wire
     * Close + close-request to hide instead of destroy.
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
        window = Gtk.TransientWindow("Design")
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
        close.setTooltip("Hide this design examine dialog.")
        if (closeAction != null) {
            close.onClicked(closeAction)
        }
        layout.append(close)
        if (closeRequestAction != null) {
            window.onCloseRequest(closeRequestAction)
        }
    }

    /*
     * Present (or refresh) the dialog for a design row.
     *
     * Purpose: pop the human ship/design examine dialog. No-op
     * when the row id is invalid.
     *
     * Parameters:
     *   parent — main debugger window (transient parent).
     *   row — design catalog row.
     *
     * Returns: true when a dialog was shown.
     */
    bool presentRow(Gtk.Window parent, DesignRow row) {
        if (row.id < 0) {
            return(false)
        }
        ensureWindow(parent)
        shownDesignId = row.id
        String title = format("Design {}", row.id)
        if (row.name.length > 0) {
            title = format("Design {} ({})", row.id, row.name)
        }
        window.setTitle(title)
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
