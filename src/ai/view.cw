/*
 * src/ai/view.cw — same-visibility inputs for the AI brain (H).
 *
 * The brain may only use what a human client could see for this
 * seat (PLAN §4.H / gameplay-principles unexpectedness). Phase H
 * keeps a thin view: role, ambush lock, known competitors, and a
 * few pool/range numbers from GET-shaped state.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AiView visibility surface.
 */

include "../lib/player.cw"

/*
 * AiView is the visibility-limited snapshot the brain reads.
 *
 * No hidden map or competitor secrets. ambushLocked mirrors the
 * pirate+ambush role lock (RULES §5) so surprise stays legal.
 */
class AiView {
    int64 playerId
    String currentRole
    bool ambushLocked
    int64 knownCompetitorCount
    fp64 wealth
    fp64 resources
    fp64 tech
    fp64 detectionRange
    int64 publishedTick

    /*
     * Construct an empty / neutral view for a seat.
     *
     * Purpose: unit and fn tests build views without a live GET.
     *
     * Parameters:
     *   seat — empire id this view belongs to.
     *
     * Returns: AiView with neutral role and zero pools.
     */
    AiView(int64 seat) {
        playerId = seat
        currentRole = "neutral"
        ambushLocked = false
        knownCompetitorCount = 0
        wealth = 0.0
        resources = 0.0
        tech = 0.0
        detectionRange = 0.0
        publishedTick = 0
    }

    /*
     * Fill pools and role from a Player seat.
     *
     * Purpose: bridge lib Player into the AI view without giving
     * the brain other seats' private fields.
     *
     * Parameters:
     *   seat — the AI's own Player.
     *   tick — current published tick count.
     *   lockedAmbush — true when pirate fleets wait on ambush.
     *
     * Returns: nothing; mutates this view.
     */
    void fillFromPlayer(Player seat, int64 tick, bool lockedAmbush) {
        playerId = seat.id
        currentRole = seat.role
        ambushLocked = lockedAmbush
        knownCompetitorCount = seat.knownCompetitors.length
        wealth = seat.wealth
        resources = seat.resources
        tech = seat.tech
        detectionRange = seat.detectionRange
        publishedTick = tick
    }
}
