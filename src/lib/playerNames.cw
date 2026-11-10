/*
 * src/lib/playerNames.cw — proper-name pool for AI seats (CPL-106).
 *
 * Humans set display_name in their own config. AI seats (and
 * server-spawned AI configs) draw from this fixed proper-name
 * list so chrome/digest show people-shaped labels instead of
 * bare seat ids.
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial proper-name pool + seeded picker.
 */

include "rng.cw"

/*
 * PlayerNames holds the shared proper-name vocabulary.
 *
 * Stateless helpers over a fixed list. Pickers take an external
 * SeededRng so server spawn and AI clients stay reproducible when
 * the same seed is used.
 */
class PlayerNames {
    /*
     * Construct the name-pool helper.
     *
     * Purpose: host static pool accessors without free functions.
     *
     * Parameters: none.
     *
     * Returns: PlayerNames instance.
     */
    PlayerNames() {
    }

    /*
     * Return the fixed proper-name vocabulary.
     *
     * Purpose: give spawn/AI/tests one shared list (Alex, Bethany,
     * …). Spelling Bethany matches the product preference note.
     *
     * Parameters: none.
     *
     * Returns: list of String proper names (non-empty).
     */
    list pool() {
        list names = []
        names.append("Alex")
        names.append("Bethany")
        names.append("Cameron")
        names.append("Dana")
        names.append("Elena")
        names.append("Farid")
        names.append("Grace")
        names.append("Hiro")
        names.append("Irene")
        names.append("Jordan")
        names.append("Kai")
        names.append("Lena")
        names.append("Marcus")
        names.append("Nora")
        names.append("Omar")
        names.append("Priya")
        names.append("Quinn")
        names.append("Rosa")
        names.append("Sam")
        names.append("Tessa")
        names.append("Uri")
        names.append("Vera")
        names.append("Willem")
        names.append("Xin")
        names.append("Yara")
        names.append("Zoe")
        return(names)
    }

    /*
     * Pick one proper name from the pool.
     *
     * Purpose: assign an AI seat label when config display_name is
     * empty. Uses rng.nextBounded over the pool length.
     *
     * Parameters:
     *   rng — SeededRng to advance (must not be null).
     *
     * Returns: one name from pool(); "Alex" if the pool is empty.
     */
    String pick(SeededRng rng) {
        list names = pool()
        if (names.length < 1) {
            return("Alex")
        }
        int64 index = int64(rng.nextBounded(uint64(names.length)))
        return(names[index])
    }

    /*
     * Pick a proper name not present in usedNames.
     *
     * Purpose: server AI spawn gives each child a distinct label
     * when the pool still has free entries; wraps to any pool
     * name when every entry is already used.
     *
     * Parameters:
     *   rng — SeededRng to advance.
     *   usedNames — list of String names already assigned.
     *
     * Returns: a pool name preferably unused.
     */
    String pickUnused(SeededRng rng, list usedNames) {
        list names = pool()
        if (names.length < 1) {
            return("Alex")
        }
        int64 attempts = 0
        while (attempts < names.length * 2) {
            String candidate = pick(rng)
            if (not nameInList(candidate, usedNames)) {
                return(candidate)
            }
            attempts = attempts + 1
        }
        return(pick(rng))
    }

    /*
     * True when needle equals an entry in names.
     *
     * Purpose: duplicate check for pickUnused.
     *
     * Parameters:
     *   needle — candidate name.
     *   names — list of String.
     *
     * Returns: true when found.
     */
    bool nameInList(String needle, list names) {
        int64 index = 0
        while (index < names.length) {
            String other = names[index]
            if (other.equals(needle)) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }
}
