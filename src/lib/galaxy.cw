/*
 * src/lib/galaxy.cw — start-of-game galaxy builder (Phase B / D5).
 *
 * Builds the full map at start: reserved primary home slot at the
 * origin, scout-range rocks, unknown quality elsewhere, world count
 * and useful/poor mix from the scenario (RULES §2 / §3 / §14).
 * Player home ownership is deferred until seat connect (claim
 * helpers). No tick rules.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial galaxy placement from scenario + RNG.
 *   2026-11-05  Phase D5: partition tags + sandbox home yards.
 *   2026-11-07  Spawn/mix/fallback/contact knobs from Scenario.
 *   2026-11-08  claimPrimaryHome; start layout may leave planet 0
 *               unowned until seat connect.
 */

import math as Math

include "planet.cw"
include "player.cw"
include "rng.cw"
include "scenario.cw"

/*
 * Galaxy holds the planet list and start-layout helpers.
 *
 * Construction is pure given Scenario + SeededRng: same seed and
 * knobs yield the same rock positions and mix.
 */
class Galaxy {
    list planets

    /*
     * Construct an empty galaxy shell.
     *
     * Purpose: allow State to own a Galaxy before buildFrom fills
     * it, matching other Phase B value objects.
     *
     * Parameters: none.
     *
     * Returns: Galaxy with an empty planet list.
     */
    Galaxy() {
        planets = []
    }

    /*
     * Populate planets from scenario knobs and a seeded RNG.
     *
     * Purpose: create worldCount rocks; planet 0 is the reserved
     * primary home slot (productive yard geometry). Pass
     * ownerPlayerId −1 to leave it unowned until seat connect;
     * otherwise assign that empire immediately (legacy / tests).
     * A few neighbors fall inside scoutRange with quality still
     * unknown (RULES §3 homeworld / scout start).
     *
     * Parameters:
     *   scenario — world count, mix, scout range, radius.
     *   rng — seeded generator for placement and mix rolls.
     *   ownerPlayerId — empire that owns the homeworld (−1 = none).
     *
     * Returns: nothing; replaces planets in place.
     */
    void buildFrom(
        Scenario scenario,
        SeededRng rng,
        int64 ownerPlayerId) {
        planets = []
        int64 count = scenario.worldCount
        if (count < 1) {
            count = 1
        }
        # Guarantee a few rocks inside starting scout range (RULES §3),
        # then place the rest elsewhere in the galaxy disk.
        int64 scoutNeighbors = 3
        if (scoutNeighbors > count - 1) {
            scoutNeighbors = count - 1
        }
        int64 index = 0
        while (index < count) {
            Planet rock = Planet(index)
            if (index == 0) {
                placeHome(rock, scenario, ownerPlayerId)
            } else (index <= scoutNeighbors) {
                placeInScoutRing(rock, scenario, rng)
            } else {
                placeRemote(rock, scenario, rng)
            }
            planets.append(rock)
            index = index + 1
        }
    }

    /*
     * Place a rock inside the home scout-range ring.
     *
     * Purpose: ensure “only a few planets sit within scout range”
     * at start without relying on random chance (RULES §3 / §13).
     *
     * Parameters:
     *   rock — planet to place.
     *   scenario — scoutRange and mix knobs.
     *   rng — angle / mix entropy.
     *
     * Returns: nothing; mutates rock (quality still unknown).
     */
    void placeInScoutRing(
        Planet rock,
        Scenario scenario,
        SeededRng rng) {
        fp64 scoutReach = scenario.scoutRange
        fp64 minR = scoutReach * scenario.homeSpawnMinRadiusFraction
        if (minR < scenario.homeSpawnMinRadiusFloor) {
            minR = scenario.homeSpawnMinRadiusFloor
        }
        fp64 maxR = scoutReach * scenario.homeSpawnMaxRadiusFraction
        if (maxR <= minR) {
            maxR = scoutReach
            minR = scoutReach * 0.5
        }
        Math.Math math = Math.Math()
        fp64 radius = minR + rng.nextFp01() * (maxR - minR)
        fp64 angle = rng.nextFp01() * math.tau()
        rock.x = radius * math.cos(angle)
        rock.y = radius * math.sin(angle)
        applyMixAndFog(rock, scenario, rng)
    }

    /*
     * Configure planet 0 as the productive home yard.
     *
     * Purpose: lock RULES §3 homeworld: productive, first shipyard,
     * quality known to the owner.
     *
     * Parameters:
     *   rock — planet slot 0.
     *   scenario — starting livability band / useful mix.
     *   ownerPlayerId — owning empire id.
     *
     * Returns: nothing; mutates rock.
     */
    void placeHome(
        Planet rock,
        Scenario scenario,
        int64 ownerPlayerId) {
        rock.x = 0.0
        rock.y = 0.0
        rock.useful = true
        rock.livability = scenario.livabilityInternalMax
        rock.resources = scenario.livabilityInternalMax
        rock.productive = true
        rock.shipyard = true
        rock.qualityKnown = true
        rock.ownerId = ownerPlayerId
        rock.population = 1.0
        if (ownerPlayerId >= 0) {
            rock.partitionId = ownerPlayerId
        } else {
            rock.partitionId = 0
        }
    }

    /*
     * Place a non-home rock inside the galaxy radius.
     *
     * Purpose: scatter rocks with useful/poor mix; leave quality
     * unknown until explore or take.
     *
     * Parameters:
     *   rock — planet to place.
     *   scenario — radius, mix, livability band.
     *   rng — placement and mix entropy.
     *
     * Returns: nothing; mutates rock.
     */
    void placeRemote(
        Planet rock,
        Scenario scenario,
        SeededRng rng) {
        fp64 radius = scenario.galaxyRadius
        fp64 scout = scenario.scoutRange
        fp64 x = 0.0
        fp64 y = 0.0
        int64 attempts = 0
        bool placed = false
        while (not placed and attempts < 64) {
            x = (rng.nextFp01() * 2.0 - 1.0) * radius
            y = (rng.nextFp01() * 2.0 - 1.0) * radius
            fp64 d2 = x * x + y * y
            if (d2 <= radius * radius and d2 > scout * scout) {
                placed = true
            }
            attempts = attempts + 1
        }
        rock.x = x
        rock.y = y
        applyMixAndFog(rock, scenario, rng)
    }

    /*
     * Assign useful/poor mix and leave quality unknown.
     *
     * Purpose: share mix logic between scout-ring and remote rocks.
     *
     * Parameters:
     *   rock — planet to fill.
     *   scenario — usefulMix and livability band.
     *   rng — mix roll.
     *
     * Returns: nothing; mutates rock.
     */
    void applyMixAndFog(
        Planet rock,
        Scenario scenario,
        SeededRng rng) {
        bool useful = rng.nextFp01() < scenario.usefulMix
        rock.useful = useful
        fp64 span = (
            scenario.livabilityInternalMax
            - scenario.livabilityInternalMin)
        if (useful) {
            rock.livability = (
                scenario.livabilityInternalMin
                + scenario.usefulLivabilityFraction * span)
            rock.resources = rock.livability
        } else {
            rock.livability = (
                scenario.livabilityInternalMin
                + scenario.poorLivabilityFraction * span)
            rock.resources = (
                rock.livability * scenario.poorResourcesFraction)
        }
        rock.productive = false
        rock.shipyard = false
        rock.qualityKnown = false
        rock.ownerId = -1
        rock.population = 0.0
        # Unowned start rocks sit in partition 0 until a seat
        # connect claims a home (claimPrimaryHome / claimSandboxHome).
        rock.partitionId = 0
    }

    /*
     * Assign planet 0 as the primary seat's home yard.
     *
     * Purpose: seat 0 connect path — the origin slot is reserved at
     * buildFrom; ownership (and partition stamp) land only when the
     * client is seated (RULES §3).
     *
     * Parameters:
     *   scenario — home livability / contact reach knobs.
     *   ownerPlayerId — empire receiving the primary home (>= 0).
     *
     * Returns: 0 when claimed or already owned by ownerPlayerId;
     * −1 when planet 0 is missing or owned by someone else.
     */
    int64 claimPrimaryHome(Scenario scenario, int64 ownerPlayerId) {
        if (planets.length < 1 or ownerPlayerId < 0) {
            return(-1)
        }
        Planet rock = planets[0]
        if (rock.ownerId >= 0 and rock.ownerId != ownerPlayerId) {
            return(-1)
        }
        placeHome(rock, scenario, ownerPlayerId)
        planets[0] = rock
        stampNearbyPartition(
            scenario, rock.x, rock.y, ownerPlayerId)
        return(0)
    }

    /*
     * Claim an unowned remote rock as a sandbox home yard.
     *
     * Purpose: each late / multi-seat empire starts in its own
     * partition of the same map until contact (RULES §2). Called
     * from seat connect, not scenario start.
     *
     * Parameters:
     *   scenario — home fallback livability/resources + contact reach.
     *   ownerPlayerId — empire receiving the home (>= 1 typical).
     *   partitionId — sandbox partition tag (usually owner id).
     *
     * Returns: planet id claimed, or −1 when no free remote rock.
     */
    int64 claimSandboxHome(
        Scenario scenario,
        int64 ownerPlayerId,
        int64 partitionId) {
        int64 index = planets.length - 1
        while (index >= 1) {
            Planet rock = planets[index]
            if (rock.ownerId < 0 and not rock.productive) {
                rock.useful = true
                rock.livability = rock.livability
                if (rock.livability < 1.0) {
                    rock.livability = scenario.homeFallbackLivability
                    rock.resources = scenario.homeFallbackResources
                }
                rock.productive = true
                rock.shipyard = true
                rock.qualityKnown = true
                rock.ownerId = ownerPlayerId
                rock.population = 1.0
                rock.partitionId = partitionId
                planets[index] = rock
                stampNearbyPartition(
                    scenario, rock.x, rock.y, partitionId)
                return(rock.id)
            }
            index = index - 1
        }
        return(-1)
    }

    /*
     * Tag nearby unowned rocks with a sandbox partition.
     *
     * Purpose: give each sandbox a local neighborhood so explore /
     * conquest contact has a clear foreign partition to couple.
     *
     * Parameters:
     *   scenario — contactReach knob.
     *   hx — home x.
     *   hy — home y.
     *   partitionId — sandbox id to stamp.
     *
     * Returns: nothing.
     */
    void stampNearbyPartition(
        Scenario scenario,
        fp64 hx,
        fp64 hy,
        int64 partitionId) {
        fp64 reach = scenario.contactReach
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            if (rock.ownerId < 0
                and rock.partitionId == 0
                and rock.inRangeOf(hx, hy, reach)) {
                rock.partitionId = partitionId
                planets[index] = rock
            }
            index = index + 1
        }
    }

    /*
     * Count rocks within scout range of home (excluding home).
     *
     * Purpose: unit tests assert “only a few planets sit within
     * scout range” at start (RULES §3 / §13).
     *
     * Parameters:
     *   scenario — scoutRange knob.
     *
     * Returns: number of non-home planets with distance <= scoutRange.
     */
    int64 countInScoutRange(Scenario scenario) {
        if (planets.length == 0) {
            return(0)
        }
        Planet home = planets[0]
        int64 found = 0
        int64 index = 1
        while (index < planets.length) {
            Planet rock = planets[index]
            if (rock.inRangeOf(home.x, home.y, scenario.scoutRange)) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }

    /*
     * Count rocks whose quality is still unknown.
     *
     * Purpose: assert start fog — only home is known by default.
     *
     * Parameters: none.
     *
     * Returns: number of planets with qualityKnown == false.
     */
    int64 countUnknownQuality() {
        int64 found = 0
        int64 index = 0
        while (index < planets.length) {
            Planet rock = planets[index]
            if (not rock.qualityKnown) {
                found = found + 1
            }
            index = index + 1
        }
        return(found)
    }
}
