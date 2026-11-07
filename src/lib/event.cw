/*
 * src/lib/event.cw — tick event records (Phase C).
 *
 * Pure tick returns events beside the mutated state (PLAN §1).
 * Kinds are stable strings for unit/fn asserts; no network.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial TickEvent helper.
 *   2026-11-07  Optional text payload for private/broadcast lines.
 */

/*
 * TickEvent is one digest line from a tick phase.
 *
 * kind names the rule cluster ("production", "cancel", "depart",
 * "recall", "arrive", "stranded", "yard", "private", "broadcast").
 * id fields are optional context (fleet, planet, player). text is
 * empty for tick phases; compose fills it for messages (§13).
 */
class TickEvent {
    String kind
    int64 fleetId
    int64 planetId
    int64 playerId
    int64 value
    String text

    /*
     * Construct a tick event with context ids.
     *
     * Purpose: give tests a structured assert surface without a
     * newspaper yet (RULES §13 comes later).
     *
     * Parameters:
     *   eventKind — short stable label.
     *   fleet — related fleet id, or -1.
     *   planet — related planet id, or -1.
     *   player — related empire id, or -1.
     *   amount — optional numeric payload (ETA, cost, …).
     *
     * Returns: TickEvent ready to append to the tick log.
     */
    TickEvent(
        String eventKind,
        int64 fleet,
        int64 planet,
        int64 player,
        int64 amount) {
        kind = eventKind
        fleetId = fleet
        planetId = planet
        playerId = player
        value = amount
        text = ""
    }
}
