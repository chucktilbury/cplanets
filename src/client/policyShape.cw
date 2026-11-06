/*
 * src/client/policyShape.cw — human policy editor shape (G).
 *
 * Same v1 opaque PUT /policy layout as the AI shape so the
 * server table stays protocol-shared. No dumb-order warnings —
 * every field here is a standing policy knob (PLAN §4.G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial HumanPolicyShape encode/decode.
 */

include "../lib/wireBytes.cw"

/*
 * HumanPolicyShape is one human policy snapshot for the editor.
 *
 * roleName is neutral / conqueror / pirate / trader / hermit.
 * Percent fields are 0..100. surpriseApplied stays false for
 * humans (AI-only oddity bit on the shared wire layout).
 */
class HumanPolicyShape {
    int64 version
    String roleName
    int64 expansionPct
    int64 escortPct
    int64 agreementS
    int64 techBiasPct
    bool surpriseApplied

    enum {
        ROLE_NEUTRAL = 0,
        ROLE_CONQUEROR = 1,
        ROLE_PIRATE = 2,
        ROLE_TRADER = 3,
        ROLE_HERMIT = 4
    }

    /*
     * Construct a neutral empty policy shape.
     *
     * Purpose: editor defaults and decode target.
     *
     * Parameters: none.
     *
     * Returns: HumanPolicyShape version 1, neutral mid tech bias.
     */
    HumanPolicyShape() {
        version = 1
        roleName = "neutral"
        expansionPct = 50
        escortPct = 50
        agreementS = 0
        techBiasPct = 50
        surpriseApplied = false
    }

    /*
     * Map a role name to a wire role code.
     *
     * Purpose: stable LE encoding for PUT /policy blobs.
     *
     * Parameters:
     *   name — role string.
     *
     * Returns: ROLE_* code; unknown → ROLE_NEUTRAL.
     */
    int64 roleCode(String name) {
        if (name.equals("conqueror")) {
            return(ROLE_CONQUEROR)
        }
        if (name.equals("pirate")) {
            return(ROLE_PIRATE)
        }
        if (name.equals("trader")) {
            return(ROLE_TRADER)
        }
        if (name.equals("hermit")) {
            return(ROLE_HERMIT)
        }
        return(ROLE_NEUTRAL)
    }

    /*
     * Map a wire role code back to a name.
     *
     * Purpose: decode blobs for editor echo.
     *
     * Parameters:
     *   code — ROLE_* value.
     *
     * Returns: role name string.
     */
    String roleFromCode(int64 code) {
        if (code == ROLE_CONQUEROR) {
            return("conqueror")
        }
        if (code == ROLE_PIRATE) {
            return("pirate")
        }
        if (code == ROLE_TRADER) {
            return("trader")
        }
        if (code == ROLE_HERMIT) {
            return("hermit")
        }
        return("neutral")
    }

    /*
     * Encode this shape into a PUT /policy blob.
     *
     * Purpose: produce opaque bytes matching AI v1 layout.
     *
     * Parameters: none.
     *
     * Returns: 8-byte buffer, or empty on encode failure.
     */
    buffer encode() {
        WireBytes w = WireBytes()
        w.writeU8(version)
        w.writeU8(roleCode(roleName))
        w.writeU8(clampPct(expansionPct))
        w.writeU8(clampPct(escortPct))
        w.writeU8(clampPct(agreementS))
        w.writeU8(clampPct(techBiasPct))
        w.writeU8(0)
        w.writeU8(0)
        if (w.error != WireBytes.OK) {
            return(buffer[])
        }
        return(w.bytes)
    }

    /*
     * Decode a v1 policy blob into this shape.
     *
     * Purpose: round-trip and load last policy into the editor.
     *
     * Parameters:
     *   blob — bytes from encode() or a PUT table.
     *
     * Returns: true when version and length parse cleanly.
     */
    bool decode(buffer blob) {
        if (blob.length < 8) {
            return(false)
        }
        WireBytes r = WireBytes()
        r.setRead(blob)
        int64 ver = r.readU8()
        int64 role = r.readU8()
        int64 exp = r.readU8()
        int64 esc = r.readU8()
        int64 agree = r.readU8()
        int64 tech = r.readU8()
        int64 sur = r.readU8()
        int64 pad = r.readU8()
        if (not r.ok() or ver != 1) {
            return(false)
        }
        version = ver
        roleName = roleFromCode(role)
        expansionPct = exp
        escortPct = esc
        agreementS = agree
        techBiasPct = tech
        surpriseApplied = (sur == 1)
        return(pad >= 0)
    }

    /*
     * Clamp a percent field into 0..100.
     *
     * Purpose: keep wire u8 fields in band.
     *
     * Parameters:
     *   value — raw percent.
     *
     * Returns: value forced into [0, 100].
     */
    int64 clampPct(int64 value) {
        if (value < 0) {
            return(0)
        }
        if (value > 100) {
            return(100)
        }
        return(value)
    }
}
