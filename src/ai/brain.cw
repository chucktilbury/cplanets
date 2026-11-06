/*
 * src/ai/brain.cw — seeded AI policy generator (Phase H).
 *
 * Difficulty axes drive a legal policy shape. Surprise is a
 * capped, seeded chance of a legal oddity — same visibility, no
 * second rule engine (PLAN §4.H / gameplay-principles §4).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial AiBrain generate + surprise.
 */

include "../lib/rng.cw"
include "config.cw"
include "policyShape.cw"
include "view.cw"

/*
 * AiBrain turns config + view into an AiPolicyShape.
 *
 * Owns a SeededRng so repeated generate() calls advance the
 * surprise stream reproducibly under a fixed seed.
 */
class AiBrain {
    AiConfig config
    SeededRng rng
    String stickyRole

    /*
     * Construct a brain from a clamped config.
     *
     * Purpose: pin the seed and remember stickiness baseline.
     *
     * Parameters:
     *   cfg — AI difficulty axes (should already be clampAll'd).
     *
     * Returns: AiBrain ready for generate().
     */
    AiBrain(AiConfig cfg) {
        config = cfg
        rng = SeededRng(cfg.seed)
        stickyRole = "neutral"
    }

    /*
     * Generate one legal policy for the current view.
     *
     * Purpose: map axes → role / percents; optionally apply a
     * legal surprise. Does not cheat visibility (view-only).
     *
     * Parameters:
     *   view — same-visibility snapshot for this seat.
     *
     * Returns: AiPolicyShape ready to encode().
     */
    AiPolicyShape generate(AiView view) {
        AiPolicyShape shape = AiPolicyShape()
        String baseRole = pickBaseRole(view)
        String role = applyStickiness(baseRole, view)
        shape.roleName = role
        stickyRole = role
        shape.expansionPct = pctFromAxis(config.expansion)
        shape.escortPct = pctFromAxis(config.escort)
        shape.agreementS = pctFromAxis(config.agreementAppetite)
        shape.techBiasPct = pctFromAxis(config.techVsHulls)
        shape.surpriseApplied = false
        if (rollSurprise()) {
            applySurprise(shape, view)
            shape.surpriseApplied = true
        }
        return(shape)
    }

    /*
     * Pick the soft/hard base role from aggression (+ appetite).
     *
     * Purpose: soft end → hermit/trader; hard end → conqueror.
     * Pirate is not the default hard end (surprise / fluid only).
     *
     * Parameters:
     *   view — unused pools today; reserved for later bias.
     *
     * Returns: one legal role name.
     */
    String pickBaseRole(AiView view) {
        fp64 a = config.aggression
        if (a < 0.25) {
            if (config.agreementAppetite >= 0.5) {
                return("trader")
            }
            return("hermit")
        }
        if (a < 0.55) {
            return("neutral")
        }
        if (a < 0.85) {
            return("conqueror")
        }
        return("conqueror")
    }

    /*
     * Keep or flip role according to stickiness.
     *
     * Purpose: high stickiness rarely flips; low stickiness is
     * fluid. Never leave pirate while ambushLocked (RULES §5).
     *
     * Parameters:
     *   baseRole — axis-preferred role.
     *   view — carries currentRole and ambushLocked.
     *
     * Returns: role name after stickiness roll.
     */
    String applyStickiness(String baseRole, AiView view) {
        String current = view.currentRole
        if (current.length == 0) {
            current = stickyRole
        }
        if (view.ambushLocked and current.equals("pirate")) {
            return("pirate")
        }
        if (current.equals(baseRole)) {
            return(baseRole)
        }
        fp64 keep = config.roleStickiness
        if (rng.nextFp01() < keep) {
            return(current)
        }
        return(baseRole)
    }

    /*
     * Roll whether this update takes the surprise branch.
     *
     * Purpose: surpriseRate is a per-update probability under the
     * seeded stream (reproducible band tests).
     *
     * Parameters: none.
     *
     * Returns: true when surprise should fire.
     */
    bool rollSurprise() {
        return(rng.nextFp01() < config.surpriseRate)
    }

    /*
     * Apply one legal surprise oddity to a shape.
     *
     * Purpose: role flip, odd S, or unescorted push — never
     * illegal, never extra visibility.
     *
     * Parameters:
     *   shape — mutable policy under construction.
     *   view — ambush lock and current role.
     *
     * Returns: nothing.
     */
    void applySurprise(AiPolicyShape shape, AiView view) {
        uint64 kind = rng.nextBounded(3u)
        if (kind == 0u) {
            shape.roleName = surpriseRole(shape.roleName, view)
            stickyRole = shape.roleName
        } else (kind == 1u) {
            int64 bump = int64(rng.nextBounded(41u)) - 20
            shape.agreementS = shape.clampPct(
                shape.agreementS + bump)
        } else {
            shape.escortPct = 0
            if (shape.expansionPct < 70) {
                shape.expansionPct = 70
            }
        }
    }

    /*
     * Choose a different legal role for a surprise flip.
     *
     * Purpose: avoid no-op flips; respect pirate+ambush lock.
     *
     * Parameters:
     *   current — role before surprise.
     *   view — ambushLocked flag.
     *
     * Returns: a different legal role name when possible.
     */
    String surpriseRole(String current, AiView view) {
        if (view.ambushLocked and current.equals("pirate")) {
            return("pirate")
        }
        list options = ["neutral", "conqueror", "trader", "hermit"]
        if (not view.ambushLocked) {
            options.append("pirate")
        }
        int64 tries = 0
        while (tries < 8) {
            uint64 pick = rng.nextBounded(uint64(options.length))
            String name = options[int64(pick)]
            if (not name.equals(current)) {
                return(name)
            }
            tries = tries + 1
        }
        return(current)
    }

    /*
     * Map a [0,1] axis onto a 0..100 percent field.
     *
     * Purpose: shared scaling for expansion / escort / S / tech.
     *
     * Parameters:
     *   axis — clamped config axis.
     *
     * Returns: int64 percent in [0, 100].
     */
    int64 pctFromAxis(fp64 axis) {
        int64 pct = int64(axis * 100.0 + 0.5)
        if (pct < 0) {
            return(0)
        }
        if (pct > 100) {
            return(100)
        }
        return(pct)
    }
}
