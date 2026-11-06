/*
 * tests/unit/unit_verbs.cw — GET state / PUT policy / GET digest bytes.
 *
 * Round-trip each verb request and response. No TCP; no POST turn
 * barrier verb (PLAN §4.E).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial verb unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/verbGetDigest.cw"
include "lib/verbGetState.cw"
include "lib/verbPutPolicy.cw"

/*
 * ByteCheck holds buffer equality for this unit program.
 */
class ByteCheck {
    /*
     * Construct a check helper.
     *
     * Purpose: host equal without a free function.
     *
     * Parameters: none.
     *
     * Returns: ByteCheck instance.
     */
    ByteCheck() {
    }

    /*
     * Compare two buffers for exact byte equality.
     *
     * Purpose: assert opaque verb body round-trips.
     *
     * Parameters:
     *   left — first buffer.
     *   right — second buffer.
     *
     * Returns: true when lengths and every byte match.
     */
    bool equal(buffer left, buffer right) {
        if (left.length != right.length) {
            return(false)
        }
        int64 index = 0
        while (index < left.length) {
            if (left[index] != right[index]) {
                return(false)
            }
            index = index + 1
        }
        return(true)
    }
}

start {
    ByteCheck check = ByteCheck()
    bool ok = true

    VerbGetState stateVerb = VerbGetState()
    GetStateRequest stateReq = GetStateRequest(3, 12)
    buffer stateReqFrame = stateVerb.encodeRequest(stateReq)
    GetStateRequest stateReqOut = stateVerb.decodeRequest(
        stateReqFrame)
    if (stateReqOut.playerId != 3 or stateReqOut.sinceTick != 12) {
        ok = false
    }
    buffer stateBlob = buffer[1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    GetStateResponse stateRes = GetStateResponse(42, stateBlob)
    buffer stateResFrame = stateVerb.encodeResponse(stateRes)
    GetStateResponse stateResOut = stateVerb.decodeResponse(
        stateResFrame)
    if (ok and stateResOut.tick != 42) {
        ok = false
    }
    if (ok and (not check.equal(stateResOut.stateBlob, stateBlob))) {
        ok = false
    }

    VerbPutPolicy policyVerb = VerbPutPolicy()
    buffer policyBlob = buffer[0xAA, 0xBB, 0xCC]
    PutPolicyRequest policyReq = PutPolicyRequest(1, policyBlob)
    buffer policyReqFrame = policyVerb.encodeRequest(policyReq)
    PutPolicyRequest policyReqOut = policyVerb.decodeRequest(
        policyReqFrame)
    if (ok and policyReqOut.playerId != 1) {
        ok = false
    }
    if (ok and (not check.equal(
        policyReqOut.policyBlob, policyBlob))) {
        ok = false
    }
    PutPolicyResponse policyRes = PutPolicyResponse(true, 7)
    buffer policyResFrame = policyVerb.encodeResponse(policyRes)
    PutPolicyResponse policyResOut = policyVerb.decodeResponse(
        policyResFrame)
    if (ok and (not policyResOut.accepted)) {
        ok = false
    }
    if (ok and policyResOut.tick != 7) {
        ok = false
    }

    VerbGetDigest digestVerb = VerbGetDigest()
    GetDigestRequest digReq = GetDigestRequest(2, 5)
    buffer digReqFrame = digestVerb.encodeRequest(
        "/events", digReq)
    GetDigestRequest digReqOut = digestVerb.decodeRequest(
        digReqFrame)
    if (ok and (digReqOut.playerId != 2
        or digReqOut.sinceTick != 5)) {
        ok = false
    }
    buffer events = buffer[]
    int64 n = 0
    while (n < 20) {
        events.append(0x55)
        n = n + 1
    }
    GetDigestResponse digRes = GetDigestResponse(9, events)
    buffer digResFrame = digestVerb.encodeResponse(
        "/digest", digRes)
    GetDigestResponse digResOut = digestVerb.decodeResponse(
        digResFrame)
    if (ok and digResOut.tick != 9) {
        ok = false
    }
    if (ok and (not check.equal(digResOut.eventsBlob, events))) {
        ok = false
    }

    # Cross-verb reject: policy frame must not decode as state.
    if (ok) {
        GetStateRequest cross = stateVerb.decodeRequest(
            policyReqFrame)
        if (cross.playerId != -1) {
            ok = false
        }
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
