/*
 * src/unit_compress.cw — BodyCompress round-trip on bytes.
 *
 * STORE and RLE paths; rejects unknown codec. No TCP (PLAN §4.E).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial compress unit program.
 */

include "lib/compress.cw"

/*
 * ByteCheck holds buffer equality for this unit program.
 */
class ByteCheck {
    /*
     * Construct a check helper.
     *
     * Purpose: host buffersEqual without a free function.
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
     * Purpose: assert compress/decompress round-trips.
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
    BodyCompress codec = BodyCompress()
    ByteCheck check = ByteCheck()
    bool ok = true

    buffer empty = buffer[]
    buffer emptyBlob = codec.compress(empty)
    CompressResult emptyOut = codec.decompress(emptyBlob)
    if (not emptyOut.ok or (not check.equal(emptyOut.data, empty))) {
        ok = false
    }
    if (ok and emptyBlob.length != 1) {
        ok = false
    }
    if (ok and int64(emptyBlob[0]) != BodyCompress.STORE) {
        ok = false
    }

    buffer mixed = buffer[1, 2, 3, 4, 5, 6, 7, 8]
    buffer mixedBlob = codec.compress(mixed)
    CompressResult mixedOut = codec.decompress(mixedBlob)
    if (ok and (not mixedOut.ok
        or (not check.equal(mixedOut.data, mixed)))) {
        ok = false
    }
    if (ok and int64(mixedBlob[0]) != BodyCompress.STORE) {
        ok = false
    }

    buffer run = buffer[]
    int64 n = 0
    while (n < 40) {
        run.append(0xAB)
        n = n + 1
    }
    buffer runBlob = codec.compress(run)
    CompressResult runOut = codec.decompress(runBlob)
    if (ok and (not runOut.ok
        or (not check.equal(runOut.data, run)))) {
        ok = false
    }
    if (ok and int64(runBlob[0]) != BodyCompress.RLE) {
        ok = false
    }
    if (ok and runBlob.length >= 1 + run.length) {
        ok = false
    }

    buffer bad = buffer[99, 1, 2]
    CompressResult badOut = codec.decompress(bad)
    if (ok and badOut.ok) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
