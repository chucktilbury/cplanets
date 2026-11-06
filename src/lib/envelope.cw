/*
 * src/lib/envelope.cw — versioned wire frame (Phase E).
 *
 * Frames carry version, verb, path, length, and a compressed body
 * (PLAN §2 / RULES §2). Reject unknown versions. No listen socket.
 *
 * Wire (little-endian):
 *   version u8 (=1)
 *   verb    u8  (GET=1, PUT=2; no POST-turn barrier)
 *   path    u16-len + UTF-8
 *   bodyLen u32 + BodyCompress blob
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial envelope v1 encode/decode.
 */

include "compress.cw"
include "wireBytes.cw"

/*
 * Envelope is one decoded REST-shaped frame.
 *
 * version must be 1. verb is GET or PUT. path is the resource
 * string ("/state", "/policy", "/events", "/digest"). body is the
 * uncompressed payload after BodyCompress.decompress.
 */
class Envelope {
    int64 version
    int64 verb
    String path
    buffer body
    bool ok
    String error

    enum {
        VERSION = 1,
        VERB_GET = 1,
        VERB_PUT = 2
    }

    /*
     * Construct an empty failed envelope shell.
     *
     * Purpose: allow encode helpers to fill fields, and decode to
     * return a structured failure without nulls.
     *
     * Parameters: none.
     *
     * Returns: Envelope with ok false and empty body.
     */
    Envelope() {
        version = 0
        verb = 0
        path = ""
        body = buffer[]
        ok = false
        error = "unset"
    }

    /*
     * Build a successful envelope value.
     *
     * Purpose: fill version/verb/path/body for encode or as a
     * decode success result.
     *
     * Parameters:
     *   frameVerb — VERB_GET or VERB_PUT.
     *   framePath — resource path string.
     *   rawBody — uncompressed body bytes.
     *
     * Returns: Envelope with ok true and VERSION set.
     */
    Envelope make(int64 frameVerb, String framePath, buffer rawBody) {
        Envelope env = Envelope()
        env.version = VERSION
        env.verb = frameVerb
        env.path = framePath
        env.body = rawBody
        env.ok = true
        env.error = ""
        return(env)
    }
}

/*
 * EnvelopeCodec encodes and decodes Envelope frames on bytes.
 *
 * encode compresses the body; decode decompresses and rejects
 * version != 1 or truncated frames.
 */
class EnvelopeCodec {
    BodyCompress compressor

    /*
     * Construct a codec with a body compressor.
     *
     * Purpose: share one BodyCompress across encode/decode calls.
     *
     * Parameters: none.
     *
     * Returns: EnvelopeCodec ready for encode / decode.
     */
    EnvelopeCodec() {
        compressor = BodyCompress()
    }

    /*
     * Encode an envelope to wire bytes.
     *
     * Purpose: produce the TCP payload for one request or response.
     * Compresses env.body. Does not open a socket.
     *
     * Parameters:
     *   env — frame with verb, path, and raw body (version forced
     *         to VERSION).
     *
     * Returns: framed buffer, or empty when env.ok is false or
     * verb/path are out of range.
     */
    buffer encode(Envelope env) {
        buffer empty = buffer[]
        if (not env.ok) {
            return(empty)
        }
        if (env.verb != Envelope.VERB_GET
            and env.verb != Envelope.VERB_PUT) {
            return(empty)
        }
        buffer blob = compressor.compress(env.body)
        WireBytes w = WireBytes()
        if (not w.writeU8(Envelope.VERSION)) {
            return(empty)
        }
        if (not w.writeU8(env.verb)) {
            return(empty)
        }
        if (not w.writeString(env.path)) {
            return(empty)
        }
        if (not w.writeU32(blob.length)) {
            return(empty)
        }
        if (not w.writeBytes(blob)) {
            return(empty)
        }
        if (not w.ok()) {
            return(empty)
        }
        return(w.bytes)
    }

    /*
     * Decode wire bytes into an Envelope.
     *
     * Purpose: parse one frame from a received buffer. Rejects
     * unknown version, bad verb, truncated fields, and compress
     * failures.
     *
     * Parameters:
     *   frame — complete envelope bytes (not a stream slice).
     *
     * Returns: Envelope; check ok / error. body is uncompressed.
     */
    Envelope decode(buffer frame) {
        Envelope env = Envelope()
        WireBytes r = WireBytes()
        r.setRead(frame)
        int64 version = r.readU8()
        if (not r.ok()) {
            env.error = "truncated version"
            return(env)
        }
        if (version != Envelope.VERSION) {
            env.error = "unsupported version"
            return(env)
        }
        int64 verb = r.readU8()
        if (not r.ok()) {
            env.error = "truncated verb"
            return(env)
        }
        if (verb != Envelope.VERB_GET and verb != Envelope.VERB_PUT) {
            env.error = "bad verb"
            return(env)
        }
        String path = r.readString()
        if (not r.ok()) {
            env.error = "truncated path"
            return(env)
        }
        int64 bodyLen = r.readU32()
        if (not r.ok()) {
            env.error = "truncated body length"
            return(env)
        }
        buffer blob = r.readBytes(bodyLen)
        if (not r.ok()) {
            env.error = "truncated body"
            return(env)
        }
        if (r.offset != frame.length) {
            env.error = "trailing bytes"
            return(env)
        }
        CompressResult expanded = compressor.decompress(blob)
        if (not expanded.ok) {
            env.error = "decompress failed"
            return(env)
        }
        env.version = version
        env.verb = verb
        env.path = path
        env.body = expanded.data
        env.ok = true
        env.error = ""
        return(env)
    }
}
