/*
 * src/server/publish.cw — opaque state / digest blob codecs (F/G).
 *
 * Builds the published blobs returned by GET /state and
 * GET /digest after each cadence fire. Compact WireBytes layout;
 * not a full State object graph on the wire yet. Phase G appends
 * planet/fleet list rows with driver-set visibility flags (not a
 * second fog engine on the client).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial publish blob encoders.
 *   2026-11-05  Phase G: planet/fleet list rows + seat visibility.
 *   2026-11-06  TUNING B: pendingDeparture flag; chrome trailer
 *               (pause + design/yard progress).
 */

include "../lib/event.cw"
include "../lib/state.cw"
include "../lib/wireBytes.cw"
include "policyTable.cw"

/*
 * PublishCodec packs published state and digest blobs.
 *
 * State blob: tick u32, ended u8, winner i32, playerCount u32,
 * then per player: id u32, wealth millicents, quit/drop/human,
 * policyCount u32 and each policy length+bytes, then Phase G
 * list section: marker u32 0x47504C31, viewerId+1 u32,
 * planetCount + rows, fleetCount + rows.
 *
 * Digest blob: tick u32, eventCount u32, then each event kind
 * string + fleet/planet/player/value u32s (value as i32 cast).
 *
 * After fleet rows (TUNING B): CHROME_MARKER u32, paused u8,
 * designDevelopTicks u32, yardBuildTicks u32, developing design
 * count + (id, ticksLeft), build count + BuildJob rows, reclaim
 * count + ReclaimJob rows. Older decoders stop at fleets when
 * they do not read further.
 */
class PublishCodec {
    enum {
        LIST_MARKER = 1196445777,
        CHROME_MARKER = 1129465393
    }

    /*
     * Construct a codec shell.
     *
     * Purpose: no retained state; methods are pure encoders.
     *
     * Parameters: none.
     *
     * Returns: PublishCodec instance.
     */
    PublishCodec() {
    }

    /*
     * Encode a published state blob from State + policies.
     *
     * Purpose: GET /state body after tick (PLAN §4.F item 2).
     * Uses viewerId -1 so every rock/fleet is marked visible
     * (snapshot / admin). Seat-scoped views use encodeStateView.
     *
     * Parameters:
     *   game — current State after tick.
     *   policies — last-policy table snapshot source.
     *   paused — current pause flag for chrome trailer.
     *
     * Returns: opaque buffer; empty on pack failure.
     */
    buffer encodeState(
        State game, PolicyTable policies, bool paused) {
        return(encodeStateView(game, policies, -1, paused))
    }

    /*
     * Encode a seat-scoped published state blob.
     *
     * Purpose: human/AI GET /state — capability visibility is a
     * view of flags set here from existing planet/fleet fields
     * and detection range (PLAN §4.G). Clients never recompute fog.
     *
     * Parameters:
     *   game — current State after tick.
     *   policies — last-policy table snapshot source.
     *   viewerId — seat requesting the view; -1 = all visible.
     *   paused — current pause flag for chrome trailer.
     *
     * Returns: opaque buffer; empty on pack failure.
     */
    buffer encodeStateView(
        State game,
        PolicyTable policies,
        int64 viewerId,
        bool paused) {
        WireBytes w = WireBytes()
        w.writeU32(game.tickCount)
        if (game.ended) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(game.winnerId + 1)
        w.writeU32(game.players.length)
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            w.writeU32(seat.id)
            int64 milli = int64(seat.wealth * 1000.0)
            if (milli < 0) {
                milli = 0
            }
            w.writeU32(milli)
            if (seat.quit) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            if (seat.dropped) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            if (seat.human) {
                w.writeU8(1)
            } else {
                w.writeU8(0)
            }
            index = index + 1
        }
        w.writeU32(policies.slots.length)
        index = 0
        while (index < policies.slots.length) {
            buffer blob = policies.get(index)
            w.writeU32(blob.length)
            w.writeBytes(blob)
            index = index + 1
        }
        w.writeU32(LIST_MARKER)
        w.writeU32(viewerId + 1)
        writePlanetRows(w, game, viewerId)
        writeFleetRows(w, game, viewerId)
        writeChromeTrailer(w, game, paused)
        if (not w.ok()) {
            return(buffer[])
        }
        return(w.bytes)
    }

    /*
     * Append planet list rows for a seat view.
     *
     * Purpose: list debugger planet pane (PLAN §4.G). Each row
     * carries driver-set visible / qualityKnown / productive /
     * populated flags and 1–10 livability when quality is known.
     *
     * Parameters:
     *   w — WireBytes writer already past the list marker.
     *   game — current State.
     *   viewerId — seat, or -1 for all-visible.
     *
     * Returns: nothing; mutates w.
     */
    void writePlanetRows(WireBytes w, State game, int64 viewerId) {
        list planets = game.galaxy.planets
        w.writeU32(planets.length)
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            bool visible = planetVisible(game, rock, viewerId)
            bool populated = rock.population > 0.0
            int64 flags = 0
            if (visible) {
                flags = flags + 1
            }
            if (rock.qualityKnown) {
                flags = flags + 2
            }
            if (rock.productive) {
                flags = flags + 4
            }
            if (populated) {
                flags = flags + 8
            }
            if (rock.shipyard) {
                flags = flags + 16
            }
            if (rock.useful) {
                flags = flags + 32
            }
            w.writeU32(rock.id)
            w.writeU8(flags)
            w.writeU32(rock.ownerId + 1)
            int64 liv = 0
            int64 res = 0
            if (rock.qualityKnown) {
                liv = game.scenario.displayLivability(rock.livability)
                res = game.scenario.displayLivability(rock.resources)
            }
            w.writeU8(liv)
            w.writeU8(res)
            index = index + 1
        }
    }

    /*
     * Append fleet list rows for a seat view.
     *
     * Purpose: list debugger fleet pane. Visible when owned by
     * the viewer or sitting/operating at a visible planet.
     *
     * Parameters:
     *   w — WireBytes writer.
     *   game — current State.
     *   viewerId — seat, or -1 for all-visible.
     *
     * Returns: nothing; mutates w.
     */
    void writeFleetRows(WireBytes w, State game, int64 viewerId) {
        w.writeU32(game.fleets.length)
        int64 index = 0
        while (index < game.fleets.length) {
            Fleet ship = game.fleets[index]
            bool visible = fleetVisible(game, ship, viewerId)
            int64 flags = 0
            if (visible) {
                flags = flags + 1
            }
            if (ship.sitting) {
                flags = flags + 2
            }
            if (ship.departed) {
                flags = flags + 4
            }
            if (ship.pendingDeparture) {
                flags = flags + 8
            }
            if (ship.recallRequested) {
                flags = flags + 16
            }
            w.writeU32(ship.id)
            w.writeU8(flags)
            w.writeU32(ship.ownerId + 1)
            w.writeU32(ship.destPlanetId + 1)
            w.writeU32(ship.locationPlanetId + 1)
            w.writeU32(ship.eta)
            w.writeU32(ship.hullCount)
            w.writeString(ship.order)
            index = index + 1
        }
    }

    /*
     * Append TUNING-B chrome trailer after fleet rows.
     *
     * Purpose: pause flag + design/yard progress labels for the
     * list debugger without a map (TUNING-PLAYABLE B4).
     *
     * Parameters:
     *   w — WireBytes writer past fleet rows.
     *   game — current State (scenario durations + jobs).
     *   paused — driver pause flag.
     *
     * Returns: nothing; mutates w.
     */
    void writeChromeTrailer(
        WireBytes w, State game, bool paused) {
        w.writeU32(CHROME_MARKER)
        if (paused) {
            w.writeU8(1)
        } else {
            w.writeU8(0)
        }
        w.writeU32(game.scenario.designDevelopTicks)
        w.writeU32(game.scenario.yardBuildTicks)
        int64 developing = 0
        int64 index = 0
        while (index < game.designs.length) {
            Design d = game.designs[index]
            if (d.developTicksLeft > 0) {
                developing = developing + 1
            }
            index = index + 1
        }
        w.writeU32(developing)
        index = 0
        while (index < game.designs.length) {
            Design d = game.designs[index]
            if (d.developTicksLeft > 0) {
                w.writeU32(d.id)
                w.writeU32(d.developTicksLeft)
            }
            index = index + 1
        }
        w.writeU32(game.builds.length)
        index = 0
        while (index < game.builds.length) {
            BuildJob build = game.builds[index]
            w.writeU32(build.id)
            w.writeU32(build.ownerId + 1)
            w.writeU32(build.planetId + 1)
            w.writeU32(build.designId + 1)
            w.writeU32(build.ticksLeft)
            index = index + 1
        }
        w.writeU32(game.reclaims.length)
        index = 0
        while (index < game.reclaims.length) {
            ReclaimJob job = game.reclaims[index]
            w.writeU32(job.id)
            w.writeU32(job.ownerId + 1)
            w.writeU32(job.planetId + 1)
            w.writeU32(job.designId + 1)
            w.writeU32(job.hullCount)
            w.writeU32(job.ticksLeft)
            index = index + 1
        }
    }

    /*
     * True when a planet should appear in a seat's list.
     *
     * Purpose: set the visible flag from existing ownership,
     * qualityKnown, and detection-range membership — not a
     * client fog engine (PLAN §4.G).
     *
     * Parameters:
     *   game — current State.
     *   rock — planet row.
     *   viewerId — seat, or -1 for always visible.
     *
     * Returns: true when the list should show this rock.
     */
    bool planetVisible(State game, Planet rock, int64 viewerId) {
        if (viewerId < 0) {
            return(true)
        }
        if (rock.ownerId == viewerId) {
            return(true)
        }
        if (rock.qualityKnown) {
            return(true)
        }
        Player viewer = findPlayer(game, viewerId)
        if (viewer.id < 0) {
            return(false)
        }
        fp64 reach = viewer.detectionRange
        list planets = game.galaxy.planets
        int64 index = 0
        while (index < planets.length) {
            Planet owned = planets[index]
            if (owned.ownerId == viewerId) {
                if (rock.inRangeOf(owned.x, owned.y, reach)) {
                    return(true)
                }
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * True when a fleet should appear in a seat's list.
     *
     * Purpose: own fleets always; others only at visible rocks.
     *
     * Parameters:
     *   game — current State.
     *   ship — fleet row.
     *   viewerId — seat, or -1 for always visible.
     *
     * Returns: true when the list should show this fleet.
     */
    bool fleetVisible(State game, Fleet ship, int64 viewerId) {
        if (viewerId < 0) {
            return(true)
        }
        if (ship.ownerId == viewerId) {
            return(true)
        }
        int64 loc = ship.locationPlanetId
        if (loc >= 0 and loc < game.galaxy.planets.length) {
            Planet rock = game.galaxy.planets[loc]
            if (planetVisible(game, rock, viewerId)) {
                return(true)
            }
        }
        int64 dest = ship.destPlanetId
        if (dest >= 0 and dest < game.galaxy.planets.length) {
            Planet target = game.galaxy.planets[dest]
            if (planetVisible(game, target, viewerId)) {
                return(true)
            }
        }
        return(false)
    }

    /*
     * Find a player seat by id, or a sentinel with id -1.
     *
     * Purpose: visibility helpers need detectionRange.
     *
     * Parameters:
     *   game — current State.
     *   playerId — empire id.
     *
     * Returns: Player seat, or Player(-1) when missing.
     */
    Player findPlayer(State game, int64 playerId) {
        int64 index = 0
        while (index < game.players.length) {
            Player seat = game.players[index]
            if (seat.id == playerId) {
                return(seat)
            }
            index = index + 1
        }
        return(Player(-1))
    }

    /*
     * Encode a published digest blob from tick events.
     *
     * Purpose: GET /digest and GET /events body after tick.
     *
     * Parameters:
     *   tick — published tick count.
     *   events — TickEvent list from State.tick().
     *
     * Returns: opaque buffer; empty on pack failure.
     */
    buffer encodeDigest(int64 tick, list events) {
        WireBytes w = WireBytes()
        w.writeU32(tick)
        w.writeU32(events.length)
        int64 index = 0
        while (index < events.length) {
            TickEvent ev = events[index]
            w.writeString(ev.kind)
            w.writeU32(ev.fleetId + 1)
            w.writeU32(ev.planetId + 1)
            w.writeU32(ev.playerId + 1)
            w.writeU32(ev.value)
            index = index + 1
        }
        if (not w.ok()) {
            return(buffer[])
        }
        return(w.bytes)
    }
}
