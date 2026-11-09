/*
 * src/client/guiDigestPage.cw — digest + known competitors compose.
 *
 * Newspaper list, known-competitors after contact, and private /
 * broadcast compose (RULES §13 / DIALOGS §7). Recipient uses
 * GuiChoiceRow (Combo stand-in). Broadcast uses the same PUT
 * /message verb with the broadcast flag. Hosted in the
 * View→Digest non-modal panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial digest + compose chrome page.
 *   2026-11-09  Hosted in View→Digest panel dialog.
 *   2026-11-09  Recipient choice row + tooltips (View usable).
 */

include "appCore.cw"
include "guiChoiceRow.cw"

/*
 * GuiDigestPage owns the Digest panel dialog widgets.
 *
 * Compose picks a recipient id from the known list (choice row
 * stand-in for DropDown) or checks Broadcast for send-to-all-known.
 */
class GuiDigestPage {
    AppCore core
    Gtk.Label digestList
    Gtk.Label knownList
    GuiChoiceRow toChoice
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
        toChoice = GuiChoiceRow()
        bodyEntry = null
        broadcastBtn = null
        sendAction = null
    }

    /*
     * Build the Digest panel dialog widget tree.
     *
     * Purpose: newspaper + known list + compose chrome.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        digestList = Gtk.Label("(empty)")
        digestList.setHExpand(true)
        digestList.setVExpand(true)
        digestList.setTooltip(
            "Seat-scoped newspaper / digest events after each tick.")
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setChild(digestList)
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        page.append(scroll)
        page.append(Gtk.Label("Known competitors"))
        knownList = Gtk.Label(
            "(no known competitors — make contact)")
        knownList.setHExpand(true)
        knownList.setTooltip(
            "Names appear only after contact (RULES §13).")
        Gtk.ScrolledWindow knownScroll = Gtk.ScrolledWindow()
        knownScroll.setChild(knownList)
        knownScroll.setHExpand(true)
        page.append(knownScroll)
        page.append(Gtk.Label(
            "Compose (private to known, or broadcast)"))
        page.append(Gtk.Label("To competitor id"))
        page.append(toChoice.buildWidget(
            "Cycle known competitors; ignored when Broadcast is on."))
        bodyEntry = Gtk.Entry("")
        bodyEntry.setTooltip("Private or broadcast message body.")
        page.append(Gtk.Label("Message"))
        page.append(bodyEntry)
        broadcastBtn = Gtk.CheckButton("Broadcast to all known")
        broadcastBtn.setTooltip(
            "Send to every known competitor (same PUT /message).")
        page.append(broadcastBtn)
        Gtk.Button send = Gtk.Button("Send message")
        send.setTooltip("PUT /message (private or broadcast).")
        if (sendAction != null) {
            send.onClicked(sendAction)
        }
        page.append(send)
        return(page)
    }

    /*
     * Rebuild digest + known-competitor chrome from core.view.
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
        syncToChoices()
    }

    /*
     * Rebuild recipient choices from knownCompetitors.
     *
     * Purpose: Combo stand-in for the To Entry.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncToChoices() {
        list ids = []
        int64 index = 0
        while (index < core.view.knownCompetitors.length) {
            int64 other = core.view.knownCompetitors[index]
            ids.append(format("{}", other))
            index = index + 1
        }
        toChoice.setChoices(ids)
    }

    /*
     * Recipient id from the To choice row.
     *
     * Purpose: Send handler (ignored when broadcast).
     *
     * Parameters: none.
     *
     * Returns: selected competitor id (0 when none known).
     */
    int64 toValue() {
        return(toChoice.intValue())
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
