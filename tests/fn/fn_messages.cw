/*
 * tests/fn/fn_messages.cw — in-process message cluster (Phase E).
 *
 * Compress → envelope → verb round-trips for GET state, PUT
 * policy, and GET digest/events. No listen socket (PLAN §4.E /
 * §6 wire).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial messages function program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/verbGetDigest.cw"
include "lib/verbGetState.cw"
include "lib/verbPutPolicy.cw"

/*
 * MsgCheck holds helpers for this function program.
 */
class MsgCheck {
    /*
     * Construct a check helper.
     *
     * Purpose: host equal/fill without free functions.
     *
     * Parameters: none.
     *
     * Returns: MsgCheck instance.
     */
    MsgCheck() {
    }

    /*
     * Compare two buffers for exact byte equality.
     *
     * Purpose: assert end-to-end verb payload identity.
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

    /*
     * Build a repetitive opaque blob that should RLE-compress.
     *
     * Purpose: exercise the RLE path inside verb envelopes.
     *
     * Parameters:
     *   fill — byte value to repeat.
     *   count — number of bytes.
     *
     * Returns: buffer of length count filled with fill.
     */
    buffer fill(int64 fill, int64 count) {
        buffer out = buffer[]
        int64 index = 0
        while (index < count) {
            out.append(fill)
            index = index + 1
        }
        return(out)
    }
}

start {
    MsgCheck check = MsgCheck()
    bool ok = true

    VerbPutPolicy policyVerb = VerbPutPolicy()
    buffer policy = check.fill(0x7E, 64)
    PutPolicyRequest putIn = PutPolicyRequest(0, policy)
    buffer putFrame = policyVerb.encodeRequest(putIn)
    PutPolicyRequest putOut = policyVerb.decodeRequest(putFrame)
    if (putOut.playerId != 0
        or (not check.equal(putOut.policyBlob, policy))) {
        ok = false
    }
    PutPolicyResponse ackIn = PutPolicyResponse(true, 3)
    buffer ackFrame = policyVerb.encodeResponse(ackIn)
    PutPolicyResponse ackOut = policyVerb.decodeResponse(ackFrame)
    if (ok and ((not ackOut.accepted) or ackOut.tick != 3)) {
        ok = false
    }

    VerbGetState stateVerb = VerbGetState()
    GetStateRequest getIn = GetStateRequest(0, 3)
    buffer getFrame = stateVerb.encodeRequest(getIn)
    GetStateRequest getOut = stateVerb.decodeRequest(getFrame)
    if (ok and (getOut.playerId != 0 or getOut.sinceTick != 3)) {
        ok = false
    }
    buffer state = check.fill(0x01, 80)
    GetStateResponse snapIn = GetStateResponse(4, state)
    buffer snapFrame = stateVerb.encodeResponse(snapIn)
    GetStateResponse snapOut = stateVerb.decodeResponse(snapFrame)
    if (ok and snapOut.tick != 4) {
        ok = false
    }
    if (ok and (not check.equal(snapOut.stateBlob, state))) {
        ok = false
    }

    VerbGetDigest digestVerb = VerbGetDigest()
    GetDigestRequest digIn = GetDigestRequest(0, 4)
    buffer digReq = digestVerb.encodeRequest("/digest", digIn)
    GetDigestRequest digOut = digestVerb.decodeRequest(digReq)
    if (ok and (digOut.playerId != 0 or digOut.sinceTick != 4)) {
        ok = false
    }
    buffer events = check.fill(0x22, 48)
    GetDigestResponse paperIn = GetDigestResponse(4, events)
    buffer paperFrame = digestVerb.encodeResponse(
        "/events", paperIn)
    GetDigestResponse paperOut = digestVerb.decodeResponse(
        paperFrame)
    if (ok and paperOut.tick != 4) {
        ok = false
    }
    if (ok and (not check.equal(paperOut.eventsBlob, events))) {
        ok = false
    }

    # Frames must be non-trivial; repetitive bodies should shrink
    # under RLE inside the envelope.
    if (ok and putFrame.length < 8) {
        ok = false
    }
    if (ok and snapFrame.length >= 1 + 80 + 32) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
