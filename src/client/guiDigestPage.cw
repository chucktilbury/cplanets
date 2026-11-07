/*
 * src/client/guiDigestPage.cw — digest + known competitors compose.
 *
 * Newspaper list, known-competitors after contact, and private /
 * broadcast compose Entries (RULES §13 / DIALOGS §7). Broadcast
 * uses the same PUT /message verb with the broadcast flag.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial digest + compose chrome page.
 */

include "appCore.cw"

/*
 * GuiDigestPage owns the Digest notebook page widgets.
 *
 * Compose picks a recipient id from the known list (Entry stand-in
 * for DropDown) or checks Broadcast for send-to-all-known.
 */
class GuiDigestPage {
    AppCore core
    Gtk.Label digestList
    Gtk.Label knownList
    Gtk.Entry toEntry
    Gtk.Entry bodyEntry
    Gtk.CheckButton broadcastBtn
    void<> sendAction

    /*
     * Construct a digest page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiDigestPage ready for buildPage.
     */
    GuiDigestPage(AppCore appCore) {
        core = appCore
        digestList = null
        knownList = null
        toEntry = null
        bodyEntry = null
        broadcastBtn = null
        sendAction = null
    }

    /*
     * Build the Digest notebook page widget tree.
     *
     * Purpose: newspaper + known list + compose Entries.
     *
     * Parameters: none.
     *
     * Returns: page widget for Notebook.appendPage.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        digestList = Gtk.Label("(empty)")
        digestList.setHExpand(true)
        digestList.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(digestList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        page.append(Gtk.Label("Known competitors"))
        knownList = Gtk.Label(
            "(no known competitors — make contact)")
        knownList.setHExpand(true)
        Gtk.ScrolledWindow knownScroll = Gtk.ScrolledWindow()
        knownScroll.setChild(knownList)
        knownScroll.setHExpand(true)
        page.append(knownScroll)
        page.append(Gtk.Label(
            "Compose (private to known, or broadcast)"))
        toEntry = Gtk.Entry("0")
        bodyEntry = Gtk.Entry("")
        page.append(Gtk.Label("To competitor id"))
        page.append(toEntry)
        page.append(Gtk.Label("Message"))
        page.append(bodyEntry)
        broadcastBtn = Gtk.CheckButton("Broadcast to all known")
        page.append(broadcastBtn)
        Gtk.Button send = Gtk.Button("Send message")
        if (sendAction != null) {
            send.onClicked(sendAction)
        }
        page.append(send)
        return(page)
    }

    /*
     * Rebuild digest + known-competitor labels from core.view.
     *
     * Purpose: GuiMain.refreshLists hook.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (digestList != null) {
            digestList.setText(core.view.digestText())
        }
        if (knownList != null) {
            knownList.setText(core.view.knownCompetitorsText())
        }
    }

    /*
     * Recipient id from the To Entry.
     *
     * Purpose: Send handler (ignored when broadcast).
     *
     * Parameters: none.
     *
     * Returns: parsed competitor id.
     */
    int64 toValue() {
        return(toEntry.text().toInt64())
    }

    /*
     * Message body from the compose Entry.
     *
     * Purpose: Send handler.
     *
     * Parameters: none.
     *
     * Returns: body text (may be empty).
     */
    String bodyValue() {
        return(bodyEntry.text())
    }

    /*
     * True when Broadcast CheckButton is active.
     *
     * Purpose: Send handler flag for PUT /message.
     *
     * Parameters: none.
     *
     * Returns: broadcast flag.
     */
    bool broadcastValue() {
        if (broadcastBtn == null) {
            return(false)
        }
        return(broadcastBtn.active())
    }
}
