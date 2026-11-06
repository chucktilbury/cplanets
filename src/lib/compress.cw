/*
 * src/lib/compress.cw — body compress / decompress (Phase E).
 *
 * Wire bodies are compressed binary on the local network (RULES
 * §2). v1 codec is run-length encoding with a store fallback when
 * RLE does not shrink. No sockets (PLAN §4.E).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial RLE + store body codec.
 */

include "wireBytes.cw"

/*
 * CompressResult is the decompress outcome.
 *
 * ok is false for truncated blobs, unknown codecs, or corrupt RLE.
 * data holds the raw body when ok is true (may be empty).
 */
class CompressResult {
    bool ok
    buffer data

    /*
     * Construct a decompress result.
     *
     * Purpose: return both success and bytes without out-params
     * (Cwhip passes bool by value).
     *
     * Parameters:
     *   success — true when the blob decoded cleanly.
     *   raw — recovered body, or empty on failure.
     *
     * Returns: CompressResult ready for caller checks.
     */
    CompressResult(bool success, buffer raw) {
        ok = success
        data = raw
    }
}

/*
 * BodyCompress encodes and decodes envelope body payloads.
 *
 * Blob layout: codec u8, then payload.
 *   codec 0 STORE — payload is the raw body bytes.
 *   codec 1 RLE   — payload is (count u8, value u8)* covering the
 *                   full raw length (count in 1..255).
 * compress() picks RLE when the encoded size is strictly smaller
 * than store; otherwise it stores. decompress() rejects unknown
 * codecs.
 */
class BodyCompress {
    enum {
        STORE = 0,
        RLE = 1
    }

    /*
     * Construct a compress helper (stateless).
     *
     * Purpose: give call sites a typed receiver for compress /
     * decompress without static methods.
     *
     * Parameters: none.
     *
     * Returns: BodyCompress ready for encode/decode.
     */
    BodyCompress() {
    }

    /*
     * Compress raw body bytes for the envelope.
     *
     * Purpose: shrink repetitive binary state/policy/digest blobs
     * before framing. Empty input yields a one-byte STORE blob.
     *
     * Parameters:
     *   raw — uncompressed body; may be empty.
     *
     * Returns: codec-prefixed buffer (never empty: at least codec).
     */
    buffer compress(buffer raw) {
        buffer rle = encodeRle(raw)
        int64 storeSize = 1 + raw.length
        if (1 + rle.length < storeSize) {
            WireBytes w = WireBytes()
            w.writeU8(RLE)
            w.writeBytes(rle)
            return(w.bytes)
        }
        WireBytes store = WireBytes()
        store.writeU8(STORE)
        store.writeBytes(raw)
        return(store.bytes)
    }

    /*
     * Decompress a codec-prefixed body blob.
     *
     * Purpose: recover the raw body after envelope decode.
     *
     * Parameters:
     *   blob — compress() output (codec + payload).
     *
     * Returns: CompressResult; ok false on codec/truncation errors.
     */
    CompressResult decompress(buffer blob) {
        buffer empty = buffer[]
        if (blob.length < 1) {
            return(CompressResult(false, empty))
        }
        int64 codec = int64(blob[0])
        buffer payload = buffer[]
        int64 index = 1
        while (index < blob.length) {
            payload.append(blob[index])
            index = index + 1
        }
        if (codec == STORE) {
            return(CompressResult(true, payload))
        }
        if (codec == RLE) {
            return(decodeRle(payload))
        }
        return(CompressResult(false, empty))
    }

    /*
     * Encode raw bytes as RLE count/value pairs.
     *
     * Purpose: produce the RLE payload (no codec byte) for
     * compress() size comparison.
     *
     * Parameters:
     *   raw — uncompressed bytes.
     *
     * Returns: (count, value)* buffer; empty when raw is empty.
     */
    buffer encodeRle(buffer raw) {
        buffer out = buffer[]
        int64 index = 0
        while (index < raw.length) {
            int64 value = int64(raw[index])
            int64 count = 1
            int64 look = index + 1
            while (look < raw.length
                and int64(raw[look]) == value
                and count < 255) {
                count = count + 1
                look = look + 1
            }
            out.append(count)
            out.append(value)
            index = index + count
        }
        return(out)
    }

    /*
     * Decode an RLE payload into raw bytes.
     *
     * Purpose: expand count/value pairs from compress() RLE form.
     *
     * Parameters:
     *   payload — (count, value)* bytes; length must be even.
     *
     * Returns: CompressResult with expanded data, or ok false.
     */
    CompressResult decodeRle(buffer payload) {
        buffer out = buffer[]
        if ((payload.length % 2) != 0) {
            return(CompressResult(false, out))
        }
        int64 index = 0
        while (index < payload.length) {
            int64 count = int64(payload[index])
            int64 value = int64(payload[index + 1])
            if (count < 1) {
                return(CompressResult(false, buffer[]))
            }
            int64 n = 0
            while (n < count) {
                out.append(value)
                n = n + 1
            }
            index = index + 2
        }
        return(CompressResult(true, out))
    }
}
