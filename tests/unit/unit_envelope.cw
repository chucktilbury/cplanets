/*
 * tests/unit/unit_envelope.cw — EnvelopeCodec round-trip on bytes.
 *
 * Version reject, GET/PUT frames, compressed body. No TCP.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial envelope unit program.
 *   2026-11-06  Moved from src/ to tests/; include via cwhip -p src.
 */

include "lib/envelope.cw"

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
     * Purpose: assert frame body round-trips.
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
    EnvelopeCodec codec = EnvelopeCodec()
    ByteCheck check = ByteCheck()
    bool ok = true

    buffer body = buffer[]
    int64 i = 0
    while (i < 30) {
        body.append(0x11)
        i = i + 1
    }
    Envelope sent = Envelope().make(
        Envelope.VERB_GET, "/state", body)
    buffer frame = codec.encode(sent)
    if (frame.length < 1) {
        ok = false
    }
    Envelope got = codec.decode(frame)
    if (ok and not got.ok) {
        ok = false
    }
    if (ok and got.version != Envelope.VERSION) {
        ok = false
    }
    if (ok and got.verb != Envelope.VERB_GET) {
        ok = false
    }
    if (ok and (not got.path.equals("/state"))) {
        ok = false
    }
    if (ok and (not check.equal(got.body, body))) {
        ok = false
    }

    buffer putBody = buffer[9, 8, 7]
    Envelope putSent = Envelope().make(
        Envelope.VERB_PUT, "/policy", putBody)
    buffer putFrame = codec.encode(putSent)
    Envelope putGot = codec.decode(putFrame)
    if (ok and not putGot.ok) {
        ok = false
    }
    if (ok and putGot.verb != Envelope.VERB_PUT) {
        ok = false
    }
    if (ok and (not putGot.path.equals("/policy"))) {
        ok = false
    }
    if (ok and (not check.equal(putGot.body, putBody))) {
        ok = false
    }

    if (ok and frame.length >= 1) {
        buffer badVer = buffer[]
        int64 j = 0
        while (j < frame.length) {
            badVer.append(frame[j])
            j = j + 1
        }
        badVer[0] = uint8(99)
        Envelope rejected = codec.decode(badVer)
        if (rejected.ok) {
            ok = false
        }
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
