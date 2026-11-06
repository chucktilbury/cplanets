/*
 * src/lib/agreement.cw — player–player trade agreements (Phase D2).
 *
 * An agreement is a pair of empires plus standing size S. Both
 * seats must accept before it is open. Changing S is a new
 * agreement (RULES §8.1). Closed agreements stop exchange.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial Agreement for Phase D2.
 */

/*
 * Agreement is one player–player trade pact on size S.
 *
 * open is true only while both sides have accepted and nobody
 * has closed the pact. playerA / playerB are empire ids (order
 * is canonicalized so A < B at propose time).
 */
class Agreement {
    int64 id
    int64 playerA
    int64 playerB
    fp64 sizeS
    bool acceptedA
    bool acceptedB
    bool open

    /*
     * Construct a closed, unaccepted agreement shell.
     *
     * Purpose: allocate a slot before propose fills the pair and
     * S, or before tests stub a finished pact.
     *
     * Parameters:
     *   agreementId — stable id in the state agreement list.
     *
     * Returns: Agreement with open false and zero S.
     */
    Agreement(int64 agreementId) {
        id = agreementId
        playerA = -1
        playerB = -1
        sizeS = 0.0
        acceptedA = false
        acceptedB = false
        open = false
    }

    /*
     * True when this pact involves the given empire.
     *
     * Purpose: look up the standing S for a sender without
     * scanning call sites for A vs B.
     *
     * Parameters:
     *   playerId — empire id to test.
     *
     * Returns: true when playerId is playerA or playerB.
     */
    bool involves(int64 playerId) {
        if (playerId == playerA) {
            return(true)
        }
        return(playerId == playerB)
    }

    /*
     * Return the other empire id in this pair.
     *
     * Purpose: trade helpers resolve the partner seat from one
     * side of the pact.
     *
     * Parameters:
     *   playerId — one member of the pair.
     *
     * Returns: the other player id, or -1 when playerId is not
     * in the pair.
     */
    int64 partnerOf(int64 playerId) {
        if (playerId == playerA) {
            return(playerB)
        }
        if (playerId == playerB) {
            return(playerA)
        }
        return(-1)
    }

    /*
     * Record acceptance for one side; open when both accepted.
     *
     * Purpose: RULES §8.1 — both players must accept before trade
     * of size S can leave as an agreement trade.
     *
     * Parameters:
     *   playerId — accepting empire.
     *
     * Returns: true when this player is in the pair and acceptance
     * was recorded (open may become true).
     */
    bool accept(int64 playerId) {
        if (playerId == playerA) {
            acceptedA = true
        } else (playerId == playerB) {
            acceptedB = true
        } else {
            return(false)
        }
        if (acceptedA and acceptedB) {
            open = true
        }
        return(true)
    }

    /*
     * Close the agreement; exchange stops on later arrivals.
     *
     * Purpose: RULES §8.4 — closed pact: in-flight traders finish
     * moving; exchange stops.
     *
     * Parameters: none.
     *
     * Returns: nothing; sets open false.
     */
    void close() {
        open = false
    }

    /*
     * True when the pact is live for exchange and cycling.
     *
     * Purpose: gate tradeArrive profit and re-dispatch.
     *
     * Parameters: none.
     *
     * Returns: true when open (both accepted, not closed).
     */
    bool isLive() {
        return(open)
    }
}
