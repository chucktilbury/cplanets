/*
 * src/client/guiPanelDialog.cw — non-modal panel TransientWindow.
 *
 * Hosts former Notebook tab content (Planets / Fleets / Ships /
 * Digest / Policy) behind top-level menubar root clicks.
 * Hide-on-close matches explored / examine dialogs so present()
 * never hits a destroyed GtkWindow. ProgressBar chrome stays
 * inside Fleets / Ships page widgets placed as this dialog's
 * content.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial panel dialog host (menubar rearrange).
 *   2026-11-09  Openers are top-level menubar menus (not View).
 *   2026-11-09  Openers are root click Buttons (no Open submenu).
 */

/*
 * GuiPanelDialog presents one main-chrome panel as a non-modal
 * TransientWindow.
 *
 * Content is built once by the page class (GuiPlanetPage, …) and
 * adopted here. Close / WM close-request only hide the shell.
 */
class GuiPanelDialog {
    Gtk.TransientWindow window
    String title
    int64 width
    int64 height
    Gtk.Widget content
    void<> closeAction
    bool<> closeRequestAction

    /*
     * Construct an empty panel dialog shell.
     *
     * Purpose: retain title and default size; delay native window
     * until present() with a parent and setContent() child.
     *
     * Parameters:
     *   panelTitle — TransientWindow title (tab name).
     *   w — default width in pixels.
     *   h — default height in pixels.
     *
     * Returns: GuiPanelDialog ready for setContent / present.
     */
    GuiPanelDialog(String panelTitle, int64 w, int64 h) {
        window = null
        title = panelTitle
        width = w
        height = h
        content = null
        closeAction = null
        closeRequestAction = null
    }

    /*
     * Attach the page widget tree before first present.
     *
     * Purpose: page.buildPage() runs once; the returned widget
     * becomes this dialog's body (above the Close button).
     *
     * Parameters:
     *   child — vertical page Box from a Gui*Page builder.
     *
     * Returns: nothing.
     */
    void setContent(Gtk.Widget child) {
        content = child
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
        }
        if (window != null) {
            return()
        }
        window = Gtk.TransientWindow(title)
        window.setDefaultSize(width, height)
        window.setTransientFor(parent)
        Gtk.Box layout = Gtk.Box(Gtk.Box.VERTICAL, 8)
        window.setChild(layout)
        if (content != null) {
            layout.append(content)
        }
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
     * Present (or raise) the panel dialog.
     *
     * Purpose: top-level menubar root clicks and map ContextMenu
     * bridges that formerly switched Notebook pages.
     *
     * Parameters:
     *   parent — main client window (transient parent).
     *
     * Returns: nothing.
     */
    void present(Gtk.Window parent) {
        ensureWindow(parent)
        window.setVisible(true)
        window.present()
    }

    /*
     * Hide the dialog without destroying the native window.
     *
     * Purpose: Close button, WM close-request, and main Quit
     * teardown. Hiding keeps Entries / Scales / ProgressBars
     * reusable across presents.
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
}
