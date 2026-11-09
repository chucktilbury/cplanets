/*
 * src/client/guiPolicyPage.cw — standing policy Scales panel.
 *
 * Empire-wide role Entry + expansion / escort / agreement S /
 * tech bias Scales (DIALOGS §4.1). Apply PUTs /policy with no
 * dumb-order warnings. Hosted in the View→Policy non-modal
 * panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial policy Scales page.
 *   2026-11-09  Hosted in View→Policy panel dialog.
 */

include "appCore.cw"

/*
 * GuiPolicyPage owns the Policy panel dialog widgets.
 *
 * Scales are 0..100; role stays an Entry (enum polish later).
 */
class GuiPolicyPage {
    AppCore core
    Gtk.Entry roleEntry
    Gtk.Scale expansionScale
    Gtk.Scale escortScale
    Gtk.Scale agreementScale
    Gtk.Scale techScale
    Gtk.Label expansionLabel
    Gtk.Label escortLabel
    Gtk.Label agreementLabel
    Gtk.Label techLabel
    void<> applyAction
    void<fp64> expansionChangedAction
    void<fp64> escortChangedAction
    void<fp64> agreementChangedAction
    void<fp64> techChangedAction
    bool suppressScale

    /*
     * Construct a policy page bound to an AppCore.
     *
     * Purpose: delay widget build until buildPage().
     *
     * Parameters:
     *   appCore — shared headless coordinator.
     *
     * Returns: GuiPolicyPage ready for buildPage.
     */
    GuiPolicyPage(AppCore appCore) {
        core = appCore
        roleEntry = null
        expansionScale = null
        escortScale = null
        agreementScale = null
        techScale = null
        expansionLabel = null
        escortLabel = null
        agreementLabel = null
        techLabel = null
        applyAction = null
        expansionChangedAction = null
        escortChangedAction = null
        agreementChangedAction = null
        techChangedAction = null
        suppressScale = false
    }

    /*
     * Build the Policy panel dialog widget tree.
     *
     * Purpose: role Entry + % Scales + Apply.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        roleEntry = Gtk.Entry(core.draft.roleName)
        page.append(Gtk.Label("Role"))
        page.append(roleEntry)
        expansionLabel = Gtk.Label("Expansion %")
        page.append(expansionLabel)
        expansionScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        expansionScale.configure(
            fp64(core.draft.expansionPct), 0.0, 100.0, 1.0)
        if (expansionChangedAction != null) {
            expansionScale.onValueChanged(expansionChangedAction)
        }
        page.append(expansionScale)
        escortLabel = Gtk.Label("Escort %")
        page.append(escortLabel)
        escortScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        escortScale.configure(
            fp64(core.draft.escortPct), 0.0, 100.0, 1.0)
        if (escortChangedAction != null) {
            escortScale.onValueChanged(escortChangedAction)
        }
        page.append(escortScale)
        agreementLabel = Gtk.Label("Agreement S")
        page.append(agreementLabel)
        agreementScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        agreementScale.configure(
            fp64(core.draft.agreementS), 0.0, 100.0, 1.0)
        if (agreementChangedAction != null) {
            agreementScale.onValueChanged(agreementChangedAction)
        }
        page.append(agreementScale)
        techLabel = Gtk.Label("Tech bias %")
        page.append(techLabel)
        techScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        techScale.configure(
            fp64(core.draft.techBiasPct), 0.0, 100.0, 1.0)
        if (techChangedAction != null) {
            techScale.onValueChanged(techChangedAction)
        }
        page.append(techScale)
        Gtk.Button apply = Gtk.Button("Apply policy")
        if (applyAction != null) {
            apply.onClicked(applyAction)
        }
        page.append(apply)
        syncFromDraft()
        return(page)
    }

    /*
     * Sync Scale thumbs and role Entry from core.draft.
     *
     * Purpose: refresh after pull / offline fill.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFromDraft() {
        if (roleEntry == null) {
            return()
        }
        roleEntry.setText(core.draft.roleName)
        suppressScale = true
        expansionScale.setValue(fp64(core.draft.expansionPct))
        escortScale.setValue(fp64(core.draft.escortPct))
        agreementScale.setValue(fp64(core.draft.agreementS))
        techScale.setValue(fp64(core.draft.techBiasPct))
        suppressScale = false
        refreshScaleLabels()
    }

    /*
     * Copy widget values into core.draft.
     *
     * Purpose: Apply button before PUT /policy.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void writeDraft() {
        core.draft.roleName = roleEntry.text()
        core.draft.expansionPct = scalePct(expansionScale)
        core.draft.escortPct = scalePct(escortScale)
        core.draft.agreementS = scalePct(agreementScale)
        core.draft.techBiasPct = scalePct(techScale)
    }

    /*
     * Read a Scale as a clamped 0..100 int.
     *
     * Purpose: draft / PUT body packing.
     *
     * Parameters:
     *   scale — configured 0..100 Scale.
     *
     * Returns: nearest int percent in band.
     */
    int64 scalePct(Gtk.Scale scale) {
        int64 pct = int64(scale.value() + 0.5)
        if (pct < 0) {
            return(0)
        }
        if (pct > 100) {
            return(100)
        }
        return(pct)
    }

    /*
     * Refresh label captions with live Scale values.
     *
     * Purpose: show the current % next to each slider.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshScaleLabels() {
        if (expansionLabel == null) {
            return()
        }
        expansionLabel.setText(format(
            "Expansion % ({})", scalePct(expansionScale)))
        escortLabel.setText(format(
            "Escort % ({})", scalePct(escortScale)))
        agreementLabel.setText(format(
            "Agreement S ({})", scalePct(agreementScale)))
        techLabel.setText(format(
            "Tech bias % ({})", scalePct(techScale)))
    }

    /*
     * Expansion Scale moved.
     *
     * Purpose: Gtk.Scale.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onExpansionChanged(fp64 value) {
        if (suppressScale) {
            return()
        }
        refreshScaleLabels()
    }

    /*
     * Escort Scale moved.
     *
     * Purpose: Gtk.Scale.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onEscortChanged(fp64 value) {
        if (suppressScale) {
            return()
        }
        refreshScaleLabels()
    }

    /*
     * Agreement Scale moved.
     *
     * Purpose: Gtk.Scale.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onAgreementChanged(fp64 value) {
        if (suppressScale) {
            return()
        }
        refreshScaleLabels()
    }

    /*
     * Tech bias Scale moved.
     *
     * Purpose: Gtk.Scale.onValueChanged.
     *
     * Parameters:
     *   value — new thumb value.
     *
     * Returns: nothing.
     */
    void onTechChanged(fp64 value) {
        if (suppressScale) {
            return()
        }
        refreshScaleLabels()
    }
}
