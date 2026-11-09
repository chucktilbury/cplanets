/*
 * src/client/guiPolicyPage.cw — standing policy SpinButton panel.
 *
 * Empire-wide role DropDown + expansion / escort / agreement S /
 * tech bias SpinButtons (DIALOGS §4.1). Apply PUTs /policy with no
 * dumb-order warnings. Hosted in the Policy menubar non-modal
 * panel dialog.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial policy Scales page.
 *   2026-11-09  Hosted in View→Policy panel dialog.
 *   2026-11-09  Menubar opener is root Policy click (no Open submenu).
 *   2026-11-09  Role choice row + tooltips (View dialogs usable).
 *   2026-11-09  DropDown + SpinButton replace GuiChoiceRow/Scale stand-ins.
 */

include "appCore.cw"
include "guiChoiceRow.cw"

/*
 * GuiPolicyPage owns the Policy panel dialog widgets.
 *
 * SpinButtons are 0..100; role uses GuiChoiceRow (DropDown wrapper).
 */
class GuiPolicyPage {
    AppCore core
    GuiChoiceRow roleChoice
    Gtk.SpinButton expansionSpin
    Gtk.SpinButton escortSpin
    Gtk.SpinButton agreementSpin
    Gtk.SpinButton techSpin
    Gtk.Label expansionLabel
    Gtk.Label escortLabel
    Gtk.Label agreementLabel
    Gtk.Label techLabel
    void<> applyAction
    void<fp64> expansionChangedAction
    void<fp64> escortChangedAction
    void<fp64> agreementChangedAction
    void<fp64> techChangedAction
    bool suppressSpin

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
        expansionSpin = null
        escortSpin = null
        agreementSpin = null
        techSpin = null
        expansionLabel = null
        escortLabel = null
        agreementLabel = null
        techLabel = null
        applyAction = null
        expansionChangedAction = null
        escortChangedAction = null
        agreementChangedAction = null
        techChangedAction = null
        suppressSpin = false
    }

    /*
     * Build the Policy panel dialog widget tree.
     *
     * Purpose: role DropDown + % SpinButtons + Apply.
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
        expansionSpin = Gtk.SpinButton()
        expansionSpin.configure(
            fp64(core.draft.expansionPct), 0.0, 100.0, 1.0)
        expansionSpin.setTooltip("Expansion % (0–100).")
        if (expansionChangedAction != null) {
            expansionSpin.onValueChanged(expansionChangedAction)
        }
        page.append(expansionSpin)
        escortLabel = Gtk.Label("Escort %")
        escortLabel.setTooltip(
            "Standing escort share of policy attention (0–100).")
        page.append(escortLabel)
        escortSpin = Gtk.SpinButton()
        escortSpin.configure(
            fp64(core.draft.escortPct), 0.0, 100.0, 1.0)
        escortSpin.setTooltip("Escort % (0–100).")
        if (escortChangedAction != null) {
            escortSpin.onValueChanged(escortChangedAction)
        }
        page.append(escortSpin)
        agreementLabel = Gtk.Label("Agreement S")
        agreementLabel.setTooltip(
            "Player–player agreement size S (0–100 stub).")
        page.append(agreementLabel)
        agreementSpin = Gtk.SpinButton()
        agreementSpin.configure(
            fp64(core.draft.agreementS), 0.0, 100.0, 1.0)
        agreementSpin.setTooltip("Agreement S (0–100).")
        if (agreementChangedAction != null) {
            agreementSpin.onValueChanged(agreementChangedAction)
        }
        page.append(agreementSpin)
        techLabel = Gtk.Label("Tech bias %")
        techLabel.setTooltip(
            "Standing tech bias share of policy attention (0–100).")
        page.append(techLabel)
        techSpin = Gtk.SpinButton()
        techSpin.configure(
            fp64(core.draft.techBiasPct), 0.0, 100.0, 1.0)
        techSpin.setTooltip("Tech bias % (0–100).")
        if (techChangedAction != null) {
            techSpin.onValueChanged(techChangedAction)
        }
        page.append(techSpin)
        Gtk.Button apply = Gtk.Button("Apply policy")
        apply.setTooltip("PUT /policy with current role and SpinButtons.")
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
     * Sync SpinButton values and role choice from core.draft.
     *
     * Purpose: refresh after pull / offline fill.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void syncFromDraft() {
        if (expansionSpin == null) {
            return()
        }
        roleChoice.setValue(core.draft.roleName)
        suppressSpin = true
        expansionSpin.setValue(fp64(core.draft.expansionPct))
        escortSpin.setValue(fp64(core.draft.escortPct))
        agreementSpin.setValue(fp64(core.draft.agreementS))
        techSpin.setValue(fp64(core.draft.techBiasPct))
        suppressSpin = false
        refreshSpinLabels()
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
        core.draft.expansionPct = spinPct(expansionSpin)
        core.draft.escortPct = spinPct(escortSpin)
        core.draft.agreementS = spinPct(agreementSpin)
        core.draft.techBiasPct = spinPct(techSpin)
    }

    /*
     * Read a SpinButton as a clamped 0..100 int.
     *
     * Purpose: draft / PUT body packing.
     *
     * Parameters:
     *   spin — configured 0..100 SpinButton.
     *
     * Returns: nearest int percent in band.
     */
    int64 spinPct(Gtk.SpinButton spin) {
        int64 pct = int64(spin.value() + 0.5)
        if (pct < 0) {
            return(0)
        }
        if (pct > 100) {
            return(100)
        }
        return(pct)
    }

    /*
     * Refresh label captions with live SpinButton values.
     *
     * Purpose: show the current % next to each spin.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void refreshSpinLabels() {
        if (expansionLabel == null) {
            return()
        }
        expansionLabel.setText(format(
            "Expansion % ({})", spinPct(expansionSpin)))
        escortLabel.setText(format(
            "Escort % ({})", spinPct(escortSpin)))
        agreementLabel.setText(format(
            "Agreement S ({})", spinPct(agreementSpin)))
        techLabel.setText(format(
            "Tech bias % ({})", spinPct(techSpin)))
    }

    /*
     * Expansion SpinButton moved.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new spin value.
     *
     * Returns: nothing.
     */
    void onExpansionChanged(fp64 value) {
        if (suppressSpin) {
            return()
        }
        refreshSpinLabels()
    }

    /*
     * Escort SpinButton moved.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new spin value.
     *
     * Returns: nothing.
     */
    void onEscortChanged(fp64 value) {
        if (suppressSpin) {
            return()
        }
        refreshSpinLabels()
    }

    /*
     * Agreement SpinButton moved.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new spin value.
     *
     * Returns: nothing.
     */
    void onAgreementChanged(fp64 value) {
        if (suppressSpin) {
            return()
        }
        refreshSpinLabels()
    }

    /*
     * Tech bias SpinButton moved.
     *
     * Purpose: Gtk.SpinButton.onValueChanged.
     *
     * Parameters:
     *   value — new spin value.
     *
     * Returns: nothing.
     */
    void onTechChanged(fp64 value) {
        if (suppressSpin) {
            return()
        }
        refreshSpinLabels()
    }
}
