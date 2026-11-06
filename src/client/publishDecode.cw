/*
 * src/client/publishDecode.cw — decode published state/digest (G).
 *
 * Mirrors server PublishCodec list layout. Clients never open the
 * DB; they only parse GET blobs (RULES §2 / PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial PublishDecode.
 *   2026-11-06  TUNING B: humanCount; fleet lock flags; chrome
 *               trailer (pause + design/build progress).
 */

include "../lib/wireBytes.cw"
include "digestLine.cw"
include "fleetRow.cw"
include "planetRow.cw"
include "stateView.cw"

/*
 * PublishDecode turns opaque GET blobs into ClientStateView rows.
 *
 * State layout must match PublishCodec.encodeStateView. Digest
 * layout matches encodeDigest.
 */
class PublishDecode {
    enum {
        LIST_MARKER = 1196445777,
        CHROME_MARKER = 1129465393
    }

    /*
     * Construct a stateless decoder.
     *
     * Purpose: share marker constant with encode.
     *
     * Parameters: none.
     *
     * Returns: PublishDecode instance.
     */
    PublishDecode() {
    }

    /*
     * Decode a GET /state blob into a ClientStateView.
     *
     * Purpose: fill planet/fleet lists from driver-set flags.
     *
     * Parameters:
     *   blob — opaque state bytes from GetStateResponse.
     *   seat — fallback viewer id when marker missing.
     *
     * Returns: filled view; planets/fleets empty on hard failure.
     */
    ClientStateView decodeState(buffer blob, int64 seat) {
        ClientStateView view = ClientStateView(seat)
        WireBytes r = WireBytes()
        r.setRead(blob)
        view.tick = r.readU32()
        int64 endedFlag = r.readU8()
        view.ended = (endedFlag == 1)
        view.winnerId = r.readU32() - 1
        int64 playerCount = r.readU32()
        int64 index = 0
        view.humanCount = 0
        while (index < playerCount) {
            r.readU32()
            r.readU32()
            r.readU8()
            r.readU8()
            int64 humanFlag = r.readU8()
            if (humanFlag == 1) {
                view.humanCount = view.humanCount + 1
            }
            index = index + 1
        }
        int64 policyCount = r.readU32()
        index = 0
        while (index < policyCount) {
            int64 len = r.readU32()
            buffer policyBlob = r.readBytes(len)
            if (index == seat and policyBlob.length >= 8) {
                view.policy.decode(policyBlob)
            }
            index = index + 1
        }
        if (not r.ok()) {
            return(view)
        }
        if (r.offset >= blob.length) {
            return(view)
        }
        int64 marker = r.readU32()
        if (marker != LIST_MARKER) {
            return(view)
        }
        view.viewerId = r.readU32() - 1
        decodePlanets(r, view)
        decodeFleets(r, view)
        decodeChromeTrailer(r, blob, view)
        return(view)
    }

    /*
     * Decode planet rows after the list marker.
     *
     * Purpose: populate view.planets with visible/quality flags.
     *
     * Parameters:
     *   r — WireBytes reader positioned at planetCount.
     *   view — mutable ClientStateView.
     *
     * Returns: nothing.
     */
    void decodePlanets(WireBytes r, ClientStateView view) {
        int64 count = r.readU32()
        int64 index = 0
        while (index < count) {
            PlanetRow row = PlanetRow()
            row.id = r.readU32()
            int64 flags = r.readU8()
            row.visible = ((flags % 2) == 1)
            row.qualityKnown = (((flags / 2) % 2) == 1)
            row.productive = (((flags / 4) % 2) == 1)
            row.populated = (((flags / 8) % 2) == 1)
            row.shipyard = (((flags / 16) % 2) == 1)
            row.useful = (((flags / 32) % 2) == 1)
            row.ownerId = r.readU32() - 1
            row.livabilityDisplay = r.readU8()
            row.resourcesDisplay = r.readU8()
            view.planets.append(row)
            index = index + 1
        }
    }

    /*
     * Decode fleet rows after the planet section.
     *
     * Purpose: populate view.fleets.
     *
     * Parameters:
     *   r — WireBytes reader positioned at fleetCount.
     *   view — mutable ClientStateView.
     *
     * Returns: nothing.
     */
    void decodeFleets(WireBytes r, ClientStateView view) {
        int64 count = r.readU32()
        int64 index = 0
        while (index < count) {
            FleetRow row = FleetRow()
            row.id = r.readU32()
            int64 flags = r.readU8()
            row.visible = ((flags % 2) == 1)
            row.sitting = (((flags / 2) % 2) == 1)
            row.departed = (((flags / 4) % 2) == 1)
            row.pendingDeparture = (((flags / 8) % 2) == 1)
            row.recallRequested = (((flags / 16) % 2) == 1)
            row.ownerId = r.readU32() - 1
            row.destPlanetId = r.readU32() - 1
            row.locationPlanetId = r.readU32() - 1
            row.eta = r.readU32()
            row.hullCount = r.readU32()
            row.order = r.readString()
            view.fleets.append(row)
            index = index + 1
        }
    }

    /*
     * Decode the optional TUNING-B chrome trailer after fleets.
     *
     * Purpose: pause flag + design/yard progress lines. No-op when
     * the blob ends before CHROME_MARKER (older snapshots).
     *
     * Parameters:
     *   r — WireBytes reader past fleet rows.
     *   blob — full state blob (length bound).
     *   view — mutable ClientStateView.
     *
     * Returns: nothing.
     */
    void decodeChromeTrailer(
        WireBytes r, buffer blob, ClientStateView view) {
        view.progressLines = []
        if (r.offset + 4 > blob.length) {
            return()
        }
        int64 marker = r.readU32()
        if (marker != CHROME_MARKER) {
            return()
        }
        int64 pausedFlag = r.readU8()
        view.paused = (pausedFlag == 1)
        view.designDevelopTicks = r.readU32()
        view.yardBuildTicks = r.readU32()
        int64 developing = r.readU32()
        int64 index = 0
        while (index < developing) {
            int64 designId = r.readU32()
            int64 left = r.readU32()
            view.progressLines.append(format(
                "design {} developing ticksLeft={}",
                designId, left))
            index = index + 1
        }
        int64 builds = r.readU32()
        index = 0
        while (index < builds) {
            int64 jobId = r.readU32()
            int64 owner = r.readU32() - 1
            int64 planet = r.readU32() - 1
            int64 design = r.readU32() - 1
            int64 left = r.readU32()
            view.progressLines.append(format(
                "build {} owner={} planet={} design={} ticksLeft={}",
                jobId, owner, planet, design, left))
            index = index + 1
        }
        int64 reclaims = r.readU32()
        index = 0
        while (index < reclaims) {
            int64 jobId = r.readU32()
            int64 owner = r.readU32() - 1
            int64 planet = r.readU32() - 1
            int64 design = r.readU32() - 1
            int64 hulls = r.readU32()
            int64 left = r.readU32()
            view.progressLines.append(format(
                "reclaim {} owner={} planet={} design={} hulls={} ticksLeft={}",
                jobId, owner, planet, design, hulls, left))
            index = index + 1
        }
    }

    /*
     * Decode a GET /digest blob into digest lines on a view.
     *
     * Purpose: newspaper pane fill.
     *
     * Parameters:
     *   blob — opaque events bytes.
     *   view — mutable ClientStateView (digest list replaced).
     *
     * Returns: true when the blob parsed cleanly.
     */
    bool decodeDigest(buffer blob, ClientStateView view) {
        view.digest = []
        WireBytes r = WireBytes()
        r.setRead(blob)
        int64 tick = r.readU32()
        int64 count = r.readU32()
        if (not r.ok()) {
            return(false)
        }
        view.tick = tick
        int64 index = 0
        while (index < count) {
            DigestLine line = DigestLine()
            line.kind = r.readString()
            line.fleetId = r.readU32() - 1
            line.planetId = r.readU32() - 1
            line.playerId = r.readU32() - 1
            line.value = r.readU32()
            view.digest.append(line)
            index = index + 1
        }
        return(r.ok())
    }
}
