/*
 * src/client/exploredTrack.cw — explored-dialog auto-pop signatures.
 *
 * Remembers qualityKnown / productive / populated packs so the
 * human client can raise GuiPlanetDialog on first explore and on
 * productive/populated flips (TUNING-PLAYABLE B3 / RULES §16).
 *
 * Created: 2026-11-06
 * Author: Auto
 *
 * Changelog:
 *   2026-11-06  Initial ExploredTrack.
 */

include "planetRow.cw"

/*
 * ExploredTrack stores per-planet dialog evolution signatures.
 *
 * Packed as planetId * 16 + low signature bits so the list stays
 * a plain int64 list without a second type.
 */
class ExploredTrack {
    list sigs

    /*
     * Construct an empty tracker.
     *
     * Purpose: GuiMain field default before first refresh.
     *
     * Parameters: none.
     *
     * Returns: ExploredTrack with empty sigs.
     */
    ExploredTrack() {
        sigs = []
    }

    /*
     * Pack a planet's explored-dialog evolution signature.
     *
     * Purpose: detect quality-first and productive/populated flips.
     *
     * Parameters:
     *   row — planet row.
     *
     * Returns: compact int signature (fits low 4 bits).
     */
    int64 signature(PlanetRow row) {
        int64 sig = 1
        if (row.productive) {
            sig = sig + 2
        }
        if (row.populated) {
            sig = sig + 4
        }
        return(sig)
    }

    /*
     * True when this planet id already has the given signature.
     *
     * Purpose: avoid re-popping unchanged explored dialogs.
     *
     * Parameters:
     *   planetId — rock id.
     *   sig — signature() value.
     *
     * Returns: true when remembered and matching.
     */
    bool known(int64 planetId, int64 sig) {
        int64 index = 0
        while (index < sigs.length) {
            int64 packed = sigs[index]
            int64 id = packed / 16
            int64 remembered = packed % 16
            if (id == planetId) {
                return(remembered == sig)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Store or replace a planet explored signature.
     *
     * Purpose: track auto-pop state across refreshes.
     *
     * Parameters:
     *   planetId — rock id (non-negative; packed * 16).
     *   sig — signature (fits in low 4 bits).
     *
     * Returns: nothing.
     */
    void remember(int64 planetId, int64 sig) {
        int64 packed = planetId * 16 + (sig % 16)
        int64 index = 0
        while (index < sigs.length) {
            int64 cur = sigs[index]
            if (cur / 16 == planetId) {
                sigs[index] = packed
                return()
            }
            index = index + 1
        }
        sigs.append(packed)
    }

    /*
     * Find the first visible qualityKnown rock that needs a pop.
     *
     * Purpose: GuiMain.autoPresentExplored selection.
     *
     * Parameters:
     *   planets — ClientStateView.planets list.
     *
     * Returns: PlanetRow to present, or id -1 when none.
     */
    PlanetRow nextToPresent(list planets) {
        int64 index = 0
        while (index < planets.length) {
            PlanetRow row = planets[index]
            if (row.visible and row.qualityKnown) {
                int64 sig = signature(row)
                if (not known(row.id, sig)) {
                    remember(row.id, sig)
                    return(row)
                }
            }
            index = index + 1
        }
        return(PlanetRow())
    }
}
