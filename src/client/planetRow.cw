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
 *   2026-11-07  allocationPct for planet budget chrome.
 *   2026-11-10  Published display name + choiceLabel helper.
 *   2026-11-10  ownerName for seat display labels (CPL-106).
 *   2026-11-11  CPL-112: air/water/minerals + accessibility display.
 */

/*
 * PlanetRow is one visibility-limited planet summary.
 *
 * livabilityDisplay / resourcesDisplay are farming / industry
 * composites (0 when quality unknown). CPL-112 also carries the
 * four resource quantities and accessibility ratings on the same
 * 1–10 band when known (RULES §13 / §16).
 */
class PlanetRow {
    int64 id
    String name
    bool visible
    bool qualityKnown
    bool productive
    bool populated
    bool shipyard
    bool useful
    int64 ownerId
    # Resolved seat display name for owner= chrome (may be empty
    # when unowned).
    String ownerName
    int64 livabilityDisplay
    int64 resourcesDisplay
    int64 airDisplay
    int64 waterDisplay
    int64 commonMineralsDisplay
    int64 rareMineralsDisplay
    int64 airAccessDisplay
    int64 waterAccessDisplay
    int64 commonMineralsAccessDisplay
    int64 rareMineralsAccessDisplay
    int64 allocationPct
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
        name = ""
        visible = false
        qualityKnown = false
        productive = false
        populated = false
        shipyard = false
        useful = false
        ownerId = -1
        ownerName = ""
        livabilityDisplay = 0
        resourcesDisplay = 0
        airDisplay = 0
        waterDisplay = 0
        commonMineralsDisplay = 0
        rareMineralsDisplay = 0
        airAccessDisplay = 0
        waterAccessDisplay = 0
        commonMineralsAccessDisplay = 0
        rareMineralsAccessDisplay = 0
        allocationPct = 100
        x = 0.0
        y = 0.0
    }

    /*
     * Owner label for list / map chrome.
     *
     * Purpose: prefer display name; fall back to decimal id.
     *
     * Parameters: none.
     *
     * Returns: owner text, or empty when unowned.
     */
    String ownerLabel() {
        if (ownerId < 0) {
            return("")
        }
        if (ownerName.length > 0) {
            return(ownerName)
        }
        return(format("{}", ownerId))
    }

    /*
     * Stable DropDown label for this planet.
     *
     * Purpose: select by name across refresh_ms polls. Prefers the
     * published name (planet 0 / seat home → "Home"); falls back
     * to "Planet {id}" when the wire name is empty.
     *
     * Parameters: none.
     *
     * Returns: non-empty choice string.
     */
    String choiceLabel() {
        if (name.length > 0) {
            return(name)
        }
        if (id == 0) {
            return("Home")
        }
        if (id < 0) {
            return("")
        }
        return(format("Planet {}", id))
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
                own = format("owner={}", ownerLabel())
            }
        }
        String label = choiceLabel()
        if (not qualityKnown) {
            return(format(
                "{} — {}; quality unknown", label, own))
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
            "{} — {}; liv={}/10 res={}/10{}",
            label, own, livabilityDisplay, resourcesDisplay, flags))
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
        String text = format("{}\n", choiceLabel())
        text.append(format(
            "Farming (air+water): {}\nIndustry (minerals): {}\n",
            livabilityDisplay, resourcesDisplay))
        text.append(format(
            "Air: {} (access {})\nWater: {} (access {})\n",
            airDisplay, airAccessDisplay,
            waterDisplay, waterAccessDisplay))
        text.append(format(
            "Common minerals: {} (access {})\n",
            commonMineralsDisplay, commonMineralsAccessDisplay))
        text.append(format(
            "Rare minerals: {} (access {})\n",
            rareMineralsDisplay, rareMineralsAccessDisplay))
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
        String label = choiceLabel()
        if (not visible) {
            return(format("{} (hidden)", label))
        }
        String yard = ""
        if (shipyard) {
            yard = " yard"
        }
        if (not qualityKnown) {
            return(format(
                "{} owner={} quality=unknown{} alloc={}%",
                label, ownerLabel(), yard, allocationPct))
        }
        return(format(
            "{} owner={} liv={}/10 res={}/10{} alloc={}%",
            label, ownerLabel(), livabilityDisplay, resourcesDisplay,
            yard, allocationPct))
    }
}
