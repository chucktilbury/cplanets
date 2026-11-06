/*
 * src/lib/wireBytes.cw — little-endian buffer helpers (Phase E).
 *
 * Shared encode/decode primitives for the TCP frame and verb
 * bodies. No sockets (PLAN §4.E / RULES §2 wire).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial LE writer/reader and UTF-8 path helpers.
 */

/*
 * WireBytes packs and unpacks little-endian integers and ASCII /
 * UTF-8 path strings on managed buffers.
 *
 * Writer appends; reader advances an offset and records the first
 * truncation. Callers treat error != OK as a hard decode failure.
 */
class WireBytes {
    buffer bytes
    int64 offset
    int64 error

    enum {
        OK = 0,
        TRUNCATED = 1,
        BAD_VALUE = 2
    }

    /*
     * Construct an empty writer / reader shell.
     *
     * Purpose: allow field fill from forWrite / forRead without a
     * partial constructor.
     *
     * Parameters: none.
     *
     * Returns: WireBytes with empty buffer, offset 0, error OK.
     */
    WireBytes() {
        bytes = buffer[]
        offset = 0
        error = OK
    }

    /*
     * Bind this instance as a reader over data at offset 0.
     *
     * Purpose: decode LE fields from a received frame or body
     * without allocating a second helper.
     *
     * Parameters:
     *   data — bytes to read; not copied.
     *
     * Returns: nothing; resets offset and error to OK.
     */
    void setRead(buffer data) {
        bytes = data
        offset = 0
        error = OK
    }

    /*
     * Append one unsigned byte.
     *
     * Purpose: write version, verb, flags, and u8 payload fields.
     *
     * Parameters:
     *   value — 0..255.
     *
     * Returns: true on success; false and BAD_VALUE on overflow.
     */
    bool writeU8(int64 value) {
        if (error != OK) {
            return(false)
        }
        if (value < 0 or value > 255) {
            error = BAD_VALUE
            return(false)
        }
        bytes.append(value)
        return(true)
    }

    /*
     * Append a little-endian unsigned 16-bit value.
     *
     * Purpose: write path lengths and short counts.
     *
     * Parameters:
     *   value — 0..65535.
     *
     * Returns: true on success; false and BAD_VALUE on overflow.
     */
    bool writeU16(int64 value) {
        if (error != OK) {
            return(false)
        }
        if (value < 0 or value > 65535) {
            error = BAD_VALUE
            return(false)
        }
        bytes.append(value % 256)
        bytes.append((value / 256) % 256)
        return(true)
    }

    /*
     * Append a little-endian unsigned 32-bit value.
     *
     * Purpose: write body lengths and tick/player ids on the wire.
     *
     * Parameters:
     *   value — 0..4294967295.
     *
     * Returns: true on success; false and BAD_VALUE on overflow.
     */
    bool writeU32(int64 value) {
        if (error != OK) {
            return(false)
        }
        if (value < 0 or value > 4294967295) {
            error = BAD_VALUE
            return(false)
        }
        bytes.append(value % 256)
        bytes.append((value / 256) % 256)
        bytes.append((value / 65536) % 256)
        bytes.append((value / 16777216) % 256)
        return(true)
    }

    /*
     * Append raw bytes without a length prefix.
     *
     * Purpose: write path UTF-8 and body blobs after their lengths.
     *
     * Parameters:
     *   data — bytes to copy; empty is valid.
     *
     * Returns: true on success (always when error was OK).
     */
    bool writeBytes(buffer data) {
        if (error != OK) {
            return(false)
        }
        int64 index = 0
        while (index < data.length) {
            bytes.append(data[index])
            index = index + 1
        }
        return(true)
    }

    /*
     * Append a length-prefixed UTF-8 string (u16 length + bytes).
     *
     * Purpose: encode envelope paths and short text fields.
     *
     * Parameters:
     *   text — string whose byte length fits in u16.
     *
     * Returns: true on success; false on BAD_VALUE / prior error.
     */
    bool writeString(String text) {
        if (error != OK) {
            return(false)
        }
        if (text.length < 0 or text.length > 65535) {
            error = BAD_VALUE
            return(false)
        }
        if (not writeU16(text.length)) {
            return(false)
        }
        int64 index = 0
        while (index < text.length) {
            bytes.append(text[index])
            index = index + 1
        }
        return(true)
    }

    /*
     * Read one unsigned byte and advance.
     *
     * Purpose: decode version, verb, codec, and u8 fields.
     *
     * Parameters: none.
     *
     * Returns: value 0..255, or 0 with error TRUNCATED.
     */
    int64 readU8() {
        if (error != OK) {
            return(0)
        }
        if (offset < 0 or offset >= bytes.length) {
            error = TRUNCATED
            return(0)
        }
        int64 value = int64(bytes[offset])
        offset = offset + 1
        return(value)
    }

    /*
     * Read a little-endian unsigned 16-bit value.
     *
     * Purpose: decode path lengths and short counts.
     *
     * Parameters: none.
     *
     * Returns: value 0..65535, or 0 with error TRUNCATED.
     */
    int64 readU16() {
        if (error != OK) {
            return(0)
        }
        if (offset < 0 or bytes.length - offset < 2) {
            error = TRUNCATED
            return(0)
        }
        int64 lo = int64(bytes[offset])
        int64 hi = int64(bytes[offset + 1]) * 256
        int64 value = lo + hi
        offset = offset + 2
        return(value)
    }

    /*
     * Read a little-endian unsigned 32-bit value.
     *
     * Purpose: decode body lengths and tick/player ids.
     *
     * Parameters: none.
     *
     * Returns: value 0..4294967295, or 0 with error TRUNCATED.
     */
    int64 readU32() {
        if (error != OK) {
            return(0)
        }
        if (offset < 0 or bytes.length - offset < 4) {
            error = TRUNCATED
            return(0)
        }
        int64 b0 = int64(bytes[offset])
        int64 b1 = int64(bytes[offset + 1]) * 256
        int64 b2 = int64(bytes[offset + 2]) * 65536
        int64 b3 = int64(bytes[offset + 3]) * 16777216
        int64 value = b0 + b1 + b2 + b3
        offset = offset + 4
        return(value)
    }

    /*
     * Read exactly count bytes into a new buffer.
     *
     * Purpose: slice path and body payloads from the frame.
     *
     * Parameters:
     *   count — number of bytes to copy; 0 yields empty.
     *
     * Returns: buffer of length count, or empty on TRUNCATED.
     */
    buffer readBytes(int64 count) {
        buffer out = buffer[]
        if (error != OK) {
            return(out)
        }
        if (count < 0) {
            error = BAD_VALUE
            return(out)
        }
        if (bytes.length - offset < count) {
            error = TRUNCATED
            return(out)
        }
        int64 index = 0
        while (index < count) {
            out.append(bytes[offset + index])
            index = index + 1
        }
        offset = offset + count
        return(out)
    }

    /*
     * Read a u16-length-prefixed UTF-8 string.
     *
     * Purpose: decode envelope paths and short text fields.
     *
     * Parameters: none.
     *
     * Returns: String on success; empty string on error.
     */
    String readString() {
        String empty = ""
        if (error != OK) {
            return(empty)
        }
        int64 length = readU16()
        if (error != OK) {
            return(empty)
        }
        buffer raw = readBytes(length)
        if (error != OK) {
            return(empty)
        }
        return(stringFromBytes(raw))
    }

    /*
     * Build a managed String from UTF-8 / ASCII bytes.
     *
     * Purpose: recover paths after a binary decode. Paths in v1
     * are ASCII verb paths; each byte becomes one string unit.
     *
     * Parameters:
     *   raw — byte content; empty yields "".
     *
     * Returns: String whose length equals raw.length.
     */
    String stringFromBytes(buffer raw) {
        String out = ""
        int64 index = 0
        while (index < raw.length) {
            String ch = " "
            ch[0] = raw[index]
            out.append(ch)
            index = index + 1
        }
        return(out)
    }

    /*
     * True when no decode/encode error has been recorded.
     *
     * Purpose: let callers gate round-trip asserts.
     *
     * Parameters: none.
     *
     * Returns: true when error == OK.
     */
    bool ok() {
        return(error == OK)
    }
}
