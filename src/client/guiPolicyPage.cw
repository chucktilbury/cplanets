/*
 * src/client/guiPolicyPage.cw — standing policy Scales panel.
 *
 * Empire-wide role GuiChoiceRow + expansion / escort / agreement S /
 * tech bias Scales (DIALOGS §4.1). Apply PUTs /policy with no
 * dumb-order warnings. Hosted in the Policy menubar non-modal
 * panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial policy Scales page.
 *   2026-11-09  Hosted in View→Policy panel dialog.
 *   2026-11-09  Menubar opener is Policy→Open (not View).
 *   2026-11-09  Role choice row + tooltips (View dialogs usable).
 */

include "appCore.cw"
include "guiChoiceRow.cw"

/*
 * GuiPolicyPage owns the Policy panel dialog widgets.
 *
 * Scales are 0..100; role uses GuiChoiceRow (Combo stand-in —
 * DropDown still missing from Cwhip GTK).
 */
class GuiPolicyPage {
    AppCore core
    GuiChoiceRow roleChoice
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
        roleChoice = GuiChoiceRow()
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
     * Purpose: role choice + % Scales + Apply.
     *
     * Parameters: none.
     *
     * Returns: page widget for GuiPanelDialog.setContent.
     */
    Gtk.Widget buildPage() {
        Gtk.Box page = Gtk.Box(Gtk.Box.VERTICAL, 6)
        page.setHExpand(true)
        page.setVExpand(true)
        roleChoice.setChoices(roleChoices())
        roleChoice.setValue(core.draft.roleName)
        page.append(Gtk.Label("Role"))
        page.append(roleChoice.buildWidget(
            "Empire role: neutral, conqueror, pirate, trader, hermit."))
        expansionLabel = Gtk.Label("Expansion %")
        expansionLabel.setTooltip(
            "Standing expansion share of policy attention (0–100).")
        page.append(expansionLabel)
        expansionScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        expansionScale.configure(
            fp64(core.draft.expansionPct), 0.0, 100.0, 1.0)
        expansionScale.setTooltip(
            "Expansion % — slider stand-in for a spin (0–100).")
        if (expansionChangedAction != null) {
            expansionScale.onValueChanged(expansionChangedAction)
        }
        page.append(expansionScale)
        escortLabel = Gtk.Label("Escort %")
        escortLabel.setTooltip(
            "Standing escort share of policy attention (0–100).")
        page.append(escortLabel)
        escortScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        escortScale.configure(
            fp64(core.draft.escortPct), 0.0, 100.0, 1.0)
        escortScale.setTooltip(
            "Escort % — slider stand-in for a spin (0–100).")
        if (escortChangedAction != null) {
            escortScale.onValueChanged(escortChangedAction)
        }
        page.append(escortScale)
        agreementLabel = Gtk.Label("Agreement S")
        agreementLabel.setTooltip(
            "Player–player agreement size S (0–100 stub).")
        page.append(agreementLabel)
        agreementScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        agreementScale.configure(
            fp64(core.draft.agreementS), 0.0, 100.0, 1.0)
        agreementScale.setTooltip(
            "Agreement S — slider stand-in for a spin (0–100).")
        if (agreementChangedAction != null) {
            agreementScale.onValueChanged(agreementChangedAction)
        }
        page.append(agreementScale)
        techLabel = Gtk.Label("Tech bias %")
        techLabel.setTooltip(
            "Standing tech bias share of policy attention (0–100).")
        page.append(techLabel)
        techScale = Gtk.Scale(Gtk.Scale.HORIZONTAL)
        techScale.configure(
            fp64(core.draft.techBiasPct), 0.0, 100.0, 1.0)
        techScale.setTooltip(
            "Tech bias % — slider stand-in for a spin (0–100).")
        if (techChangedAction != null) {
            techScale.onValueChanged(techChangedAction)
        }
        page.append(techScale)
        Gtk.Button apply = Gtk.Button("Apply policy")
        apply.setTooltip("PUT /policy with current role and Scales.")
        if (applyAction != null) {
            apply.onClicked(applyAction)
        }
        page.append(apply)
        syncFromDraft()
        return(page)
    }

    /*
     * Fixed empire role name list.
     *
     * Purpose: roleChoice seed (RULES §4 / policyShape codes).
     *
     * Parameters: none.
     *
     * Returns: list of role name strings.
     */
    list roleChoices() {
        list out = []
        out.append("neutral")
        out.append("conqueror")
        out.append("pirate")
        out.append("trader")
        out.append("hermit")
        return(out)
    }

    /*
     * Sync Scale thumbs and role choice from core.draft.
     *
     * Purpose: refresh after pull / offline fill.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFromDraft() {
        if (expansionScale == null) {
            return()
        }
        roleChoice.setValue(core.draft.roleName)
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
        String role = roleChoice.value()
        if (role.length < 1) {
            role = "neutral"
        }
        core.draft.roleName = role
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
