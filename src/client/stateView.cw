/*
 * src/client/stateView.cw — decoded published state for UI (G).
 *
 * Holds tick header, planet/fleet lists, and the policy editor
 * shape. Filled only from server flags / blobs — no tick, no DB.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial ClientStateView.
 *   2026-11-06  TUNING B: pause / humanCount / progress chrome.
 *   2026-11-07  Design catalog + seat wealth/resources milli.
 *   2026-11-07  Known competitors list for compose chrome.
 *   2026-11-07  firstOwnedYardId / isOwnedYard for Ships yard Entry.
 *   2026-11-07  firstSittingOwnedFleetId for Fleets Entry sync.
 *   2026-11-08  developJobs / buildJobs / reclaimJobs for bars.
 */

include "designRow.cw"
include "digestLine.cw"
include "fleetRow.cw"
include "planetRow.cw"
include "policyShape.cw"
include "progressJob.cw"

/*
 * ClientStateView is the human debugger's working snapshot.
 *
 * planets/fleets already carry visible flags; UI filters on
 * visible when building list panes.
 */
class ClientStateView {
    int64 tick
    bool ended
    int64 winnerId
    int64 viewerId
    int64 humanCount
    bool paused
    int64 designDevelopTicks
    int64 yardBuildTicks
    int64 wealthMilli
    int64 resourcesMilli
    list planets
    list fleets
    list designs
    list digest
    list progressLines
    list developJobs
    list buildJobs
    list reclaimJobs
    list knownCompetitors
    HumanPolicyShape policy

    /*
     * Construct an empty view for a seat.
     *
     * Purpose: unit fixtures and decode targets.
     *
     * Parameters:
     *   seat — empire id this view belongs to.
     *
     * Returns: ClientStateView with empty lists.
     */
    ClientStateView(int64 seat) {
        tick = 0
        ended = false
        winnerId = -1
        viewerId = seat
        humanCount = 0
        paused = false
        designDevelopTicks = 0
        yardBuildTicks = 0
        wealthMilli = 0
        resourcesMilli = 0
        planets = []
        fleets = []
        designs = []
        digest = []
        progressLines = []
        developJobs = []
        buildJobs = []
        reclaimJobs = []
        knownCompetitors = []
        policy = HumanPolicyShape()
    }

    /*
     * Join known-competitor ids for the Digest compose list.
     *
     * Purpose: RULES §13 — no contact, no name on the list.
     *
     * Parameters: none.
     *
     * Returns: multi-line competitor text, or a stub.
     */
    String knownCompetitorsText() {
        if (knownCompetitors.length < 1) {
            return("(no known competitors — make contact)\n")
        }
        String text = ""
        int64 index = 0
        while (index < knownCompetitors.length) {
            int64 other = knownCompetitors[index]
            text.append(format("competitor {}\n", other))
            index = index + 1
        }
        return(text)
    }

    /*
     * True when the server offers pause for this session.
     *
     * Purpose: gate the human Pause control (exactly one human).
     *
     * Parameters: none.
     *
     * Returns: true when humanCount == 1.
     */
    bool pauseOffered() {
        return(humanCount == 1)
    }

    /*
     * Count planets marked visible.
     *
     * Purpose: unit/fn asserts and status line.
     *
     * Parameters: none.
     *
     * Returns: number of rows with visible == true.
     */
    int64 visiblePlanetCount() {
        int64 count = 0
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible) {
                count = count + 1
            }
            index = index + 1
        }
        return(count)
    }

    /*
     * Count fleets marked visible.
     *
     * Purpose: unit/fn asserts and status line.
     *
     * Parameters: none.
     *
     * Returns: number of rows with visible == true.
     */
    int64 visibleFleetCount() {
        int64 count = 0
        int64 index = 0
        while (index < fleets.length) {
            FleetRow row = fleets[index]
            if (row.visible) {
                count = count + 1
            }
            index = index + 1
        }
        return(count)
    }

    /*
     * Find a planet row by id.
     *
     * Purpose: explored dialog lookup from list activation.
     *
     * Parameters:
     *   planetId — rock id.
     *
     * Returns: PlanetRow, or empty row with id -1 when missing.
     */
    PlanetRow findPlanet(int64 planetId) {
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.id == planetId) {
                return(row)
            }
            index = index + 1
        }
        return(PlanetRow())
    }

    /*
     * Lowest-id owned shipyard planet for this seat.
     *
     * Purpose: Ships-tab Yard planet Entry default (home 0 at
     * start). Avoids a stale id such as worldCount-1 (23).
     *
     * Parameters: none.
     *
     * Returns: planet id, or −1 when none owned.
     */
    int64 firstOwnedYardId() {
        int64 best = -1
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible
                and row.shipyard
                and row.ownerId == viewerId) {
                if (best < 0 or row.id < best) {
                    best = row.id
                }
            }
            index = index + 1
        }
        return(best)
    }

    /*
     * True when planetId is an owned shipyard for this seat.
     *
     * Purpose: Yard planet Entry validation before Queue build.
     *
     * Parameters:
     *   planetId — candidate yard rock.
     *
     * Returns: true when visible owned shipyard.
     */
    bool isOwnedYard(int64 planetId) {
        PlanetRow row = findPlanet(planetId)
        if (row.id < 0) {
            return(false)
        }
        if (not row.visible or not row.shipyard) {
            return(false)
        }
        return(row.ownerId == viewerId)
    }

    /*
     * Lowest-id owned sitting fleet for this seat.
     *
     * Purpose: Fleets-tab Fleet id Entry default. Seed home fleet
     * is id 1; Entry must not stay on 0 (no fleet ever has id 0).
     * Prefers sitting unlocked stacks so Dispatch works after a
     * yard build merges into / spawns a sit fleet.
     *
     * Parameters: none.
     *
     * Returns: fleet id, or −1 when none sitting/owned/visible.
     */
    int64 firstSittingOwnedFleetId() {
        int64 best = -1
        int64 index = 0
        while (index < fleets.length) {
            FleetRow row = fleets[index]
            if (row.visible
                and row.sitting
                and not row.orderLocked()
                and row.ownerId == viewerId
                and row.hullCount > 0) {
                if (best < 0 or row.id < best) {
                    best = row.id
                }
            }
            index = index + 1
        }
        return(best)
    }

    /*
     * True when fleetId is a visible owned fleet in this snapshot.
     *
     * Purpose: Fleets Entry validation before Dispatch.
     *
     * Parameters:
     *   fleetId — candidate fleet id.
     *
     * Returns: true when the row is present, visible, and owned.
     */
    bool isOwnedFleet(int64 fleetId) {
        FleetRow row = findFleet(fleetId)
        if (row.id < 0 or not row.visible) {
            return(false)
        }
        return(row.ownerId == viewerId)
    }

    /*
     * Find a fleet row by id.
     *
     * Purpose: dispatch/recall chrome lock lookup.
     *
     * Parameters:
     *   fleetId — fleet id.
     *
     * Returns: FleetRow, or empty row with id -1 when missing.
     */
    FleetRow findFleet(int64 fleetId) {
        int64 index = 0
        while (index < fleets.length) {
            FleetRow row = fleets[index]
            if (row.id == fleetId) {
                return(row)
            }
            index = index + 1
        }
        return(FleetRow())
    }

    /*
     * Find a design row by id.
     *
     * Purpose: yard build Entry validation / inspect.
     *
     * Parameters:
     *   designId — design id.
     *
     * Returns: DesignRow, or empty row with id -1 when missing.
     */
    DesignRow findDesign(int64 designId) {
        int64 index = 0
        while (index < designs.length) {
            DesignRow row = designs[index]
            if (row.id == designId) {
                return(row)
            }
            index = index + 1
        }
        return(DesignRow())
    }

    /*
     * Join published design rows for the Ships tab list.
     *
     * Purpose: inspect ready + developing templates (DIALOGS §6).
     *
     * Parameters: none.
     *
     * Returns: multi-line catalog text, or a stub.
     */
    String designsText() {
        if (designs.length < 1) {
            return("(no designs)\n")
        }
        String text = ""
        int64 index = 0
        while (index < designs.length) {
            DesignRow row = designs[index]
            text.append(row.listLabel())
            text.append("\n")
            index = index + 1
        }
        return(text)
    }

    /*
     * Join owned shipyard planet ids for the yard Entries hint.
     *
     * Purpose: show which rocks accept Queue build / reclaim.
     *
     * Parameters: none.
     *
     * Returns: multi-line yard hint text.
     */
    String yardPlanetsText() {
        String text = format(
            "pools wealthMilli={} resourcesMilli={}\n",
            wealthMilli, resourcesMilli)
        int64 index = 0
        int64 found = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible
                and row.shipyard
                and row.ownerId == viewerId) {
                String prod = "idle"
                if (row.productive) {
                    prod = "productive"
                }
                text.append(format(
                    "yard planet {} ({})\n", row.id, prod))
                found = found + 1
            }
            index = index + 1
        }
        if (found < 1) {
            text.append("(no owned shipyard planets)\n")
        }
        return(text)
    }

    /*
     * Join design/build progress lines for the progress label.
     *
     * Purpose: non-modal design/yard chrome (TUNING-PLAYABLE B4).
     * ProgressBars show the lead develop/build job; this text
     * keeps setup durations, reclaim rows, and multi-job detail.
     *
     * Parameters: none.
     *
     * Returns: multi-line text, or a durations-only stub.
     */
    String progressText() {
        String text = format(
            "setup designDevelopTicks={} yardBuildTicks={}\n",
            designDevelopTicks, yardBuildTicks)
        text.append(
            "yard builds merge into same-design sitting fleets — dispatch that id (hulls peel splits)\n")
        if (progressLines.length < 1) {
            text.append("(no active design/build/reclaim)\n")
            return(text)
        }
        int64 index = 0
        while (index < progressLines.length) {
            String line = progressLines[index]
            text.append(line)
            text.append("\n")
            index = index + 1
        }
        return(text)
    }

    /*
     * Lead in-progress design-develop job, if any.
     *
     * Purpose: Ships / Fleets ProgressBar primary develop slot.
     *
     * Parameters: none.
     *
     * Returns: first ProgressJob in developJobs, or id -1 sentinel.
     */
    ProgressJob leadDevelopJob() {
        if (developJobs.length < 1) {
            return(ProgressJob())
        }
        return(developJobs[0])
    }

    /*
     * Lead in-progress yard-build job, if any.
     *
     * Purpose: Ships / Fleets ProgressBar primary build slot.
     *
     * Parameters: none.
     *
     * Returns: first ProgressJob in buildJobs, or id -1 sentinel.
     */
    ProgressJob leadBuildJob() {
        if (buildJobs.length < 1) {
            return(ProgressJob())
        }
        return(buildJobs[0])
    }

    /*
     * Build a multi-line digest newspaper string.
     *
     * Purpose: digest pane fill and --pull print.
     *
     * Parameters: none.
     *
     * Returns: joined digest lines, or "(empty)\n".
     */
    String digestText() {
        if (digest.length < 1) {
            return("(empty)\n")
        }
        String text = ""
        int64 index = 0
        while (index < digest.length) {
            DigestLine line = digest[index]
            text.append(line.listLabel())
            text.append("\n")
            index = index + 1
        }
        return(text)
    }
}
