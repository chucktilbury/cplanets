/*
 * src/lib/playerMessage.cw — private / broadcast compose records.
 *
 * Contact adds known competitors (RULES §13). Compose picks from
 * that list for a private send, or broadcasts to all known. Bodies
 * are short strings; tick spend rules are not involved.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial PlayerMessage for list-chrome compose.
 */

/*
 * PlayerMessage is one composed line waiting in the driver inbox.
 *
 * fromId is the sender. toId is the private recipient, or -1 when
 * broadcast is true (delivered to every known competitor of from).
 */
class PlayerMessage {
    int64 fromId
    int64 toId
    String text
    bool broadcast

    /*
     * Construct a message record.
     *
     * Purpose: driver inbox append target after PUT /message.
     *
     * Parameters:
     *   sender — sending seat id.
     *   to — private recipient, or -1 for broadcast.
     *   body — message text (may be empty only when rejected
     *          upstream).
     *   isBroadcast — true when send-to-all-known.
     *
     * Returns: PlayerMessage ready to append.
     */
    PlayerMessage(
        int64 sender, int64 to, String body, bool isBroadcast) {
        fromId = sender
        toId = to
        text = body
        broadcast = isBroadcast
    }

    /*
     * True when viewerId may see this message in the digest.
     *
     * Purpose: seat-scoped newspaper (private must not leak).
     *
     * Parameters:
     *   viewerId — requesting seat.
     *   knownOfSender — sender.knownCompetitors list (ids).
     *
     * Returns: true when the line belongs on that seat's digest.
     */
    bool visibleTo(int64 viewerId, list knownOfSender) {
        if (viewerId == fromId) {
            return(true)
        }
        if (broadcast) {
            int64 index = 0
            while (index < knownOfSender.length) {
                int64 other = knownOfSender[index]
                if (other == viewerId) {
                    return(true)
                }
                index = index + 1
            }
            return(false)
        }
        return(viewerId == toId)
    }
}
