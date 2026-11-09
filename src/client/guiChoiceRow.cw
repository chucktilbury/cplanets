/*
 * src/client/guiChoiceRow.cw — combo stand-in (prev / next cycle).
 *
 * Cwhip GTK has no DropDown / ComboBox yet (GTK-FEATURE-GAPS).
 * This product helper cycles a fixed or refreshed string list so
 * View dialogs stop relying on free-text for enums and id picks.
 *
 * Created: 2026-11-09
 * Author: Auto
 *
 * Changelog:
 *   2026-11-09  Initial GuiChoiceRow for View dialog usability.
 */

/*
 * GuiChoiceRow is one labeled prev/value/next picker row.
 *
 * Choices are plain strings (role names, order verbs, decimal
 * ids). Callers refresh the list from the published snapshot and
 * read value() when building PUT bodies.
 */
class GuiChoiceRow {
    list choices
    int64 index
    Gtk.Label valueLabel
    Gtk.Button prevBtn
    Gtk.Button nextBtn
    Gtk.Box row
    void<> changedAction
    void<> prevAction
    void<> nextAction
    String emptyText

    /*
     * Construct an empty choice row.
     *
     * Purpose: delay widget build until buildWidget().
     *
     * Parameters: none.
     *
     * Returns: GuiChoiceRow with no choices and index 0.
     */
    GuiChoiceRow() {
        choices = []
        index = 0
        valueLabel = null
        prevBtn = null
        nextBtn = null
        row = null
        changedAction = null
        prevAction = null
        nextAction = null
        emptyText = "(none)"
    }

    /*
     * Bind prev/next handlers with explicit receivers.
     *
     * Purpose: Cwhip method refs need a receiver (bare names in
     * constructors fail). Call from GuiMain before buildWidget:
     * `row.bind(row.onPrev, row.onNext)`.
     *
     * Parameters:
     *   prev — usually this.onPrev.
     *   next — usually this.onNext.
     *
     * Returns: nothing.
     */
    void bind(void<> prev, void<> next) {
        prevAction = prev
        nextAction = next
    }

    /*
     * Build the prev / value / next widget row.
     *
     * Purpose: drop into a panel dialog Box in place of an Entry
     * for enum-like or id-list fields. Call bind() first.
     *
     * Parameters:
     *   tooltip — hover text for the whole row (and buttons).
     *
     * Returns: horizontal Box ready for page.append.
     */
    Gtk.Widget buildWidget(String tooltip) {
        row = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        row.setHExpand(true)
        if (tooltip.length > 0) {
            row.setTooltip(tooltip)
        }
        prevBtn = Gtk.Button("<")
        nextBtn = Gtk.Button(">")
        valueLabel = Gtk.Label(emptyText)
        valueLabel.setHExpand(true)
        if (tooltip.length > 0) {
            prevBtn.setTooltip(tooltip)
            nextBtn.setTooltip(tooltip)
            valueLabel.setTooltip(tooltip)
        }
        if (prevAction != null) {
            prevBtn.onClicked(prevAction)
        }
        if (nextAction != null) {
            nextBtn.onClicked(nextAction)
        }
        row.append(prevBtn)
        row.append(valueLabel)
        row.append(nextBtn)
        redraw()
        return(row)
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
        String prior = value()
        choices = newChoices
        index = 0
        if (prior.length > 0) {
            int64 found = findIndex(prior)
            if (found >= 0) {
                index = found
            }
        }
        clampIndex()
        redraw()
    }

    /*
     * Select a value if it is in the list (else leave index alone).
     *
     * Purpose: map pick fills dest; sync from draft role name.
     *
     * Parameters:
     *   wanted — exact choice string to select.
     *
     * Returns: true when the value was found and selected.
     */
    bool setValue(String wanted) {
        int64 found = findIndex(wanted)
        if (found < 0) {
            return(false)
        }
        index = found
        redraw()
        return(true)
    }

    /*
     * Current selected choice text.
     *
     * Purpose: PUT body field / Entry replacement readback.
     *
     * Parameters: none.
     *
     * Returns: selected string, or "" when the list is empty.
     */
    String value() {
        if (choices.length < 1) {
            return("")
        }
        clampIndex()
        return(choices[index])
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
     * Step to the previous choice (wrap).
     *
     * Purpose: "<" button handler.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onPrev() {
        if (choices.length < 1) {
            return()
        }
        index = index - 1
        if (index < 0) {
            index = choices.length - 1
        }
        redraw()
        notifyChanged()
    }

    /*
     * Step to the next choice (wrap).
     *
     * Purpose: ">" button handler.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void onNext() {
        if (choices.length < 1) {
            return()
        }
        index = index + 1
        if (index >= choices.length) {
            index = 0
        }
        redraw()
        notifyChanged()
    }

    /*
     * Find the index of a choice string.
     *
     * Purpose: setChoices / setValue lookup.
     *
     * Parameters:
     *   wanted — exact string to match.
     *
     * Returns: index, or −1 when missing.
     */
    int64 findIndex(String wanted) {
        int64 i = 0
        while (i < choices.length) {
            String item = choices[i]
            if (item.equals(wanted)) {
                return(i)
            }
            i = i + 1
        }
        return(-1)
    }

    /*
     * Keep index inside [0, length) or 0 when empty.
     *
     * Purpose: defensive clamp after list swaps.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void clampIndex() {
        if (choices.length < 1) {
            index = 0
            return()
        }
        if (index < 0) {
            index = 0
        }
        if (index >= choices.length) {
            index = choices.length - 1
        }
    }

    /*
     * Refresh the value Label and button sensitivity.
     *
     * Purpose: after index / list changes.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void redraw() {
        if (valueLabel == null) {
            return()
        }
        if (choices.length < 1) {
            valueLabel.setText(emptyText)
        } else {
            valueLabel.setText(value())
        }
        bool enabled = choices.length > 1
        if (prevBtn != null) {
            prevBtn.setSensitive(enabled)
        }
        if (nextBtn != null) {
            nextBtn.setSensitive(enabled)
        }
    }

    /*
     * Fire the optional changedAction callback.
     *
     * Purpose: let parents sync dependent chrome (hull Scale).
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
