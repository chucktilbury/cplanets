/*
 * src/unit_clientPolicy.cw — human policy shape round-trip (G).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial unit.
 */

include "client/policyShape.cw"

start {
    bool ok = true
    HumanPolicyShape shape = HumanPolicyShape()
    shape.roleName = "trader"
    shape.expansionPct = 40
    shape.escortPct = 60
    shape.agreementS = 12
    shape.techBiasPct = 55
    buffer blob = shape.encode()
    if (blob.length != 8) {
        ok = false
    }
    HumanPolicyShape back = HumanPolicyShape()
    if (ok and not back.decode(blob)) {
        ok = false
    }
    if (ok and not back.roleName.equals("trader")) {
        ok = false
    }
    if (ok and back.expansionPct != 40) {
        ok = false
    }
    if (ok and back.agreementS != 12) {
        ok = false
    }
    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
