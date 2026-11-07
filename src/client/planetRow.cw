/*
 * src/client/planetRow.cw — one planet list / dialog row (G).
 *
 * Visibility and qualityKnown are server flags; this type only
 * formats them for lists and the explored-planet dialog
 * (livability/quality 1–10; may change when populated/productive).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial PlanetRow view model.
 *   2026-11-07  List label notes shipyard rocks.
 *   2026-11-07  Phase I: published x/y for map canvas.
 */

/*
 * PlanetRow is one visibility-limited planet summary.
 *
 * livabilityDisplay / resourcesDisplay are 0 when quality is
 * unknown; otherwise in the setup 1–10 band (RULES §13 / §16).
 */
class PlanetRow {
    int64 id
    bool visible
    bool qualityKnown
    bool productive
    bool populated
    bool shipyard
    bool useful
    int64 ownerId
    int64 livabilityDisplay
    int64 resourcesDisplay
    fp64 x
    fp64 y

    /*
     * Construct an empty invisible planet row.
     *
     * Purpose: decode target and unit fixtures.
     *
     * Parameters: none.
     *
     * Returns: PlanetRow with id -1 and all flags false.
     */
    PlanetRow() {
        id = -1
        visible = false
        qualityKnown = false
        productive = false
        populated = false
        shipyard = false
        useful = false
        ownerId = -1
        livabilityDisplay = 0
        resourcesDisplay = 0
        x = 0.0
        y = 0.0
    }

    /*
     * One-line status summary for the map context menu.
     *
     * Purpose: right-click status items (DIALOGS §3.1) without a
     * second fog engine — only published flags.
     *
     * Parameters:
     *   viewerId — seat id for ownership wording.
     *
     * Returns: short status string.
     */
    String mapStatusLabel(int64 viewerId) {
        String own = "unowned"
        if (ownerId == viewerId) {
            own = "owned by you"
        } else {
            if (ownerId >= 0) {
                own = format("owner={}", ownerId)
            }
        }
        if (not qualityKnown) {
            return(format(
                "Planet {} — {}; quality unknown", id, own))
        }
        String flags = ""
        if (populated) {
            flags.append(" populated")
        }
        if (productive) {
            flags.append(" productive")
        }
        if (shipyard) {
            flags.append(" yard")
        }
        return(format(
            "Planet {} — {}; liv={}/10 res={}/10{}",
            id, own, livabilityDisplay, resourcesDisplay, flags))
    }

    /*
     * True when the explored-planet dialog may change later.
     *
     * Purpose: RULES §16 — dialog may change when the rock is
     * populated or productive; surface that in the dialog text.
     *
     * Parameters: none.
     *
     * Returns: true when populated or productive.
     */
    bool dialogMayChange() {
        if (populated) {
            return(true)
        }
        if (productive) {
            return(true)
        }
        return(false)
    }

    /*
     * Build the explored-planet dialog body text.
     *
     * Purpose: human dialog on explored rocks (RULES §16). Shows
     * 1–10 livability/quality; notes when values may change.
     *
     * Parameters: none.
     *
     * Returns: multi-line dialog body, or empty when not known.
     */
    String exploredDialogText() {
        if (not qualityKnown) {
            return("")
        }
        String text = format(
            "Planet {}\nLivability: {}\nQuality/resources: {}\n",
            id, livabilityDisplay, resourcesDisplay)
        if (productive) {
            text.append("Status: productive\n")
        } else {
            text.append("Status: not productive\n")
        }
        if (populated) {
            text.append("Population: present\n")
        } else {
            text.append("Population: none\n")
        }
        if (dialogMayChange()) {
            text.append("Note: values may change as this rock ")
            text.append("is populated or productive.\n")
        }
        return(text)
    }

    /*
     * One-line label for the planet list pane.
     *
     * Purpose: Tree / Label row text without a map canvas.
     *
     * Parameters: none.
     *
     * Returns: short summary string.
     */
    String listLabel() {
        if (not visible) {
            return(format("Planet {} (hidden)", id))
        }
        String yard = ""
        if (shipyard) {
            yard = " yard"
        }
        if (not qualityKnown) {
            return(format(
                "Planet {} owner={} quality=unknown{}",
                id, ownerId, yard))
        }
        return(format(
            "Planet {} owner={} liv={}/10 res={}/10{}",
            id, ownerId, livabilityDisplay, resourcesDisplay,
            yard))
    }
}
