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
 */

include "digestLine.cw"
include "fleetRow.cw"
include "planetRow.cw"
include "policyShape.cw"

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
    list planets
    list fleets
    list digest
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
        planets = []
        fleets = []
        digest = []
        policy = HumanPolicyShape()
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
