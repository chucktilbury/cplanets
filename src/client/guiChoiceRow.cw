/*
 * src/client/guiChoiceRow.cw — DropDown wrapper for View dialogs.
 *
 * Product helper around Gtk.DropDown that preserves the prior
 * setChoices / setValue / value / intValue / changedAction API used
 * by Policy / Planets / Fleets / Ships / Digest panels.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial GuiChoiceRow for View dialog usability.
 *   2026-11-09  Rewrap as Gtk.DropDown (replace prev/next stand-in).
 *   2026-11-10  Preserve prior selection across setChoices refresh.
 */

/*
 * GuiChoiceRow is one DropDown picker with optional change notify.
 *
 * Choices are plain strings (role names, order verbs, decimal
 * ids). Callers refresh the list from the published snapshot and
 * read value() when building PUT bodies. setChoices / setValue may
 * run before buildWidget(); pending state is applied when the
 * DropDown is created.
 */
class GuiChoiceRow {
    Gtk.DropDown drop
    list pendingChoices
    String pendingValue
    bool hasPendingValue
    void<> changedAction
    void<int64> selectedAction
    String emptyText

    /*
     * Construct an empty choice row.
     *
     * Purpose: delay widget build until buildWidget().
     *
     * Parameters: none.
     *
     * Returns: GuiChoiceRow with no DropDown yet.
     */
    GuiChoiceRow() {
        drop = null
        pendingChoices = []
        pendingValue = ""
        hasPendingValue = false
        changedAction = null
        selectedAction = null
        emptyText = "(none)"
    }

    /*
     * Bind selected handler with an explicit receiver.
     *
     * Purpose: Cwhip method refs need a receiver. Call from GuiMain
     * before buildWidget: `row.bindSelected(row.onSelected)`.
     *
     * Parameters:
     *   selected — usually this.onSelected.
     *
     * Returns: nothing.
     */
    void bindSelected(void<int64> selected) {
        selectedAction = selected
    }

    /*
     * Build the DropDown widget.
     *
     * Purpose: drop into a panel dialog Box for enum-like or id-list
     * fields. Call bindSelected() first.
     *
     * Parameters:
     *   tooltip — hover text for the DropDown.
     *
     * Returns: DropDown ready for page.append (as Gtk.Widget).
     */
    Gtk.Widget buildWidget(String tooltip) {
        drop = Gtk.DropDown()
        drop.setHExpand(true)
        if (tooltip.length > 0) {
            drop.setTooltip(tooltip)
        }
        if (selectedAction != null) {
            drop.onSelected(selectedAction)
        }
        applyPending()
        return(drop)
    }

    /*
     * Replace the choice list and keep the prior value when present.
     *
     * Purpose: refresh from a new snapshot (fleet ids, yards,
     * known competitors) without forcing the operator back to
     * index 0 when the prior pick still exists.
     *
     * Parameters:
     *   newChoices — list of String values (may be empty).
     *
     * Returns: nothing.
     */
    void setChoices(list newChoices) {
        pendingChoices = newChoices
        if (drop == null) {
            return()
        }
        applyChoices(newChoices)
    }

    /*
     * Select a value if it is in the list (else leave selection alone).
     *
     * Purpose: map pick fills dest; sync from draft role name.
     *
     * Parameters:
     *   wanted — exact choice string to select.
     *
     * Returns: true when the value was found and selected.
     */
    bool setValue(String wanted) {
        pendingValue = wanted
        hasPendingValue = true
        if (drop == null) {
            return(false)
        }
        return(selectText(wanted))
    }

    /*
     * Current selected choice text.
     *
     * Purpose: PUT body field / Entry replacement readback.
     *
     * Parameters: none.
     *
     * Returns: selected string, or "" when empty / placeholder.
     */
    String value() {
        if (drop == null) {
            if (hasPendingValue) {
                return(pendingValue)
            }
            return("")
        }
        if (drop.size() < 1) {
            return("")
        }
        String text = drop.selectedText()
        if (text.equals(emptyText)) {
            return("")
        }
        return(text)
    }

    /*
     * Current selected choice as int64.
     *
     * Purpose: id pickers (fleet / planet / design / competitor).
     *
     * Parameters: none.
     *
     * Returns: toInt64 of value(), or 0 when empty.
     */
    int64 intValue() {
        String text = value()
        if (text.length < 1) {
            return(0)
        }
        return(text.toInt64())
    }

    /*
     * DropDown selection changed.
     *
     * Purpose: default onSelected → optional changedAction.
     *
     * Parameters:
     *   index — new selected index (ignored; value() is source of truth).
     *
     * Returns: nothing.
     */
    void onSelected(int64 index) {
        notifyChanged()
    }

    /*
     * Apply any setChoices / setValue that ran before buildWidget.
     *
     * Purpose: buildWidget finish.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void applyPending() {
        applyChoices(pendingChoices)
        if (hasPendingValue) {
            selectText(pendingValue)
        }
    }

    /*
     * Push a choice list into the live DropDown.
     *
     * Purpose: setChoices / applyPending. Empty lists show a disabled
     * placeholder so the control stays visible. When the prior
     * selected label (or pendingValue) still exists in the new list,
     * reselect it so refresh_ms polls do not reset the operator's
     * pick back to index 0.
     *
     * Parameters:
     *   newChoices — list of String labels.
     *
     * Returns: nothing.
     */
    void applyChoices(list newChoices) {
        if (drop == null) {
            return()
        }
        String prior = ""
        if (drop.size() > 0) {
            prior = value()
        }
        if (prior.length < 1 and hasPendingValue) {
            prior = pendingValue
        }
        if (newChoices.length < 1) {
            list placeholder = []
            placeholder.append(emptyText)
            drop.setChoices(placeholder)
            drop.setSelected(0)
            drop.setSensitive(false)
            return()
        }
        drop.setSensitive(true)
        drop.setChoices(newChoices)
        if (prior.length > 0) {
            if (selectText(prior)) {
                return()
            }
        }
        if (hasPendingValue and pendingValue.length > 0) {
            selectText(pendingValue)
        }
    }

    /*
     * Select by exact label on the live DropDown.
     *
     * Purpose: setValue / applyPending.
     *
     * Parameters:
     *   wanted — exact choice string.
     *
     * Returns: true when selected.
     */
    bool selectText(String wanted) {
        if (drop == null) {
            return(false)
        }
        int64 found = findIndex(wanted)
        if (found < 0) {
            return(false)
        }
        drop.setSelected(found)
        return(true)
    }

    /*
     * Find the index of a choice string.
     *
     * Purpose: selectText lookup.
     *
     * Parameters:
     *   wanted — exact string to match.
     *
     * Returns: index, or −1 when missing.
     */
    int64 findIndex(String wanted) {
        if (drop == null) {
            return(-1)
        }
        int64 i = 0
        while (i < drop.size()) {
            String item = drop.item(i)
            if (item.equals(wanted)) {
                return(i)
            }
            i = i + 1
        }
        return(-1)
    }

    /*
     * Fire the optional changedAction callback.
     *
     * Purpose: let parents sync dependent chrome (hull SpinButton).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void notifyChanged() {
        if (changedAction != null) {
            changedAction()
        }
    }
}
