/*
 * src/lib/setupParse.cw — load scenario from application text.
 *
 * Setup file syntax is still open in RULES §17; this loader accepts
 * a simple line-oriented key = value form (not JSON/TOML/HTTP).
 * Unknown keys fail loud (ok=false + lastError) so tuning typos
 * cannot silently no-op. Known keys overlay closed defaults.
 * Process / network runtime (host, port, serve, seed, …) lives on
 * ServerConfigParse — not here. Operator play loads §14 keys through
 * the unified server config; SetupParse remains the shared §14
 * overlay helper (State.startFromText, ServerConfigParse, units).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial key=value setup loader.
 *   2026-11-06  Fail loud on unknown keys (TUNING A2).
 *   2026-11-07  verbosity setup key (server stdout logging).
 *   2026-11-07  Clamp verbosity to 0–10 after parse.
 *   2026-11-07  Process CLI mirror keys (port/players/seed/…).
 *   2026-11-07  Drop process keys — server config owns them.
 *   2026-11-07  Production/build/galaxy/design template keys.
 *   2026-11-09  Shared §14 helper for unified ServerConfigParse.
 *   2026-11-11  CPL-112: rare_mineral_weight, access_*, habit_*.
 */

include "scenario.cw"

/*
 * SetupParse turns application text into a Scenario snapshot.
 *
 * Starts from Scenario() closed defaults, then overlays each
 * recognized §14 key. Always clampTickPeriod() before returning.
 * Callers must check ok after parseText; lastError names the
 * first unknown key or malformed line. Process defaults
 * (port / host / serve / …) belong on ServerConfigParse.
 */
class SetupParse {
    bool ok
    String lastError

    /*
     * Construct a parser helper.
     *
     * Purpose: match other Phase B value objects; all work lives in
     * parseText / applyPair. ok starts true until a bad line.
     *
     * Parameters: none.
     *
     * Returns: an empty SetupParse instance with ok=true.
     */
    SetupParse() {
        ok = true
        lastError = ""
    }

    /*
     * Parse a full setup document into a Scenario.
     *
     * Purpose: load admin/application text without a stdlib format.
     * Blank lines and # comments are skipped. Resets ok/lastError
     * for this parse. On unknown key or malformed line, ok becomes
     * false and lastError is set; overlay still continues so tests
     * can inspect both the partial Scenario and the error.
     *
     * Parameters:
     *   text — entire setup body (newline-separated key = value).
     *
     * Returns: Scenario with overlays applied and tick period
     * clamped. Check ok / lastError before trusting the result.
     */
    Scenario parseText(String text) {
        ok = true
        lastError = ""
        Scenario scenario = Scenario()
        list lines = text.split("\n")
        int64 index = 0
        while (index < lines.length) {
            String line = lines[index]
            line = line.trim()
            if (line.length > 0 and not line.startsWith("#")) {
                applyLine(scenario, line)
            }
            index = index + 1
        }
        scenario.clampTickPeriod()
        scenario.clampVerbosity()
        return(scenario)
    }

    /*
     * Apply one physical line to a scenario.
     *
     * Purpose: split on the first '=' and dispatch key/value.
     * Lines without '=' are a loud failure (not silent skips).
     *
     * Parameters:
     *   scenario — mutable snapshot.
     *   line — trimmed non-comment line.
     *
     * Returns: nothing.
     */
    void applyLine(Scenario scenario, String line) {
        list parts = line.split("=")
        if (parts.length < 2) {
            if (ok) {
                ok = false
                lastError = format(
                    "malformed setup line (need key = value): {}",
                    line)
            }
            return()
        }
        String key = parts[0]
        String val = parts[1]
        key = key.trim()
        val = val.trim()
        applyPair(scenario, key, val)
    }

    /*
     * Overlay one recognized setup key onto a scenario.
     *
     * Purpose: name every §14 knob the closed fixture ships so text
     * and code stay aligned. Unknown keys fail loud (first error
     * wins in lastError). Process keys are rejected so they move
     * to config/server-*.cfg instead of silently living here.
     *
     * Parameters:
     *   scenario — mutable snapshot.
     *   key — setup field name.
     *   val — trimmed value text.
     *
     * Returns: nothing.
     */
    void applyPair(Scenario scenario, String key, String val) {
        if (key.equals("scenario_mode")) {
            scenario.scenarioMode = val
        } else (key.equals("tick_period_seconds")) {
            scenario.tickPeriodSeconds = val.toInt64()
        } else (key.equals("tick_auto_config_from_ai_lag")) {
            scenario.tickAutoConfigFromAiLag = parseBool(val)
        } else (key.equals("ai_reaction_lag_ticks")) {
            scenario.aiReactionLagTicks = val.toInt64()
        } else (key.equals("ai_reaction_lag_seconds")) {
            scenario.aiReactionLagSeconds = val.toFp64()
        } else (key.equals("afk_timeout_seconds")) {
            scenario.afkTimeoutSeconds = val.toFp64()
        } else (key.equals("afk_shrink_factor")) {
            scenario.afkShrinkFactor = val.toFp64()
        } else (key.equals("world_count")) {
            scenario.worldCount = val.toInt64()
        } else (key.equals("useful_mix")) {
            scenario.usefulMix = val.toFp64()
        } else (key.equals("scout_range")) {
            scenario.scoutRange = val.toFp64()
        } else (key.equals("galaxy_radius")) {
            scenario.galaxyRadius = val.toFp64()
        } else (key.equals("identify_attacker_base")) {
            scenario.identifyAttackerBase = val.toFp64()
        } else (key.equals("identify_attacker_per_attr")) {
            scenario.identifyAttackerPerAttr = val.toFp64()
        } else (key.equals("identify_defender_base")) {
            scenario.identifyDefenderBase = val.toFp64()
        } else (key.equals("identify_defender_per_attr")) {
            scenario.identifyDefenderPerAttr = val.toFp64()
        } else (key.equals("tech_range_base")) {
            scenario.techRangeBase = val.toFp64()
        } else (key.equals("tech_range_per_tech")) {
            scenario.techRangePerTech = val.toFp64()
        } else (key.equals("tech_teleport_threshold")) {
            scenario.techTeleportThreshold = val.toFp64()
        } else (key.equals("tech_teleport_enabled")) {
            scenario.techTeleportEnabled = parseBool(val)
        } else (key.equals("design_develop_ticks")) {
            scenario.designDevelopTicks = val.toInt64()
        } else (key.equals("yard_build_ticks")) {
            scenario.yardBuildTicks = val.toInt64()
        } else (key.equals("yard_build_extra_hull_time_frac")) {
            scenario.yardBuildExtraHullTimeFrac = val.toFp64()
        } else (key.equals("design_speed_cost_coeff")) {
            scenario.designSpeedCostCoeff = val.toFp64()
        } else (key.equals("design_range_cost_coeff")) {
            scenario.designRangeCostCoeff = val.toFp64()
        } else (key.equals("reclaim_percent")) {
            scenario.reclaimPercent = val.toFp64()
        } else (key.equals("capture_use_chance")) {
            scenario.captureUseChance = val.toFp64()
        } else (key.equals("cover_factor")) {
            scenario.coverFactor = val.toFp64()
        } else (key.equals("voyage_cost")) {
            scenario.voyageCost = val.toFp64()
        } else (key.equals("pirate_idle_ticks")) {
            scenario.pirateIdleTicks = val.toInt64()
        } else (key.equals("stranded_ticks_n")) {
            scenario.strandedTicksN = val.toInt64()
        } else (key.equals("trade_bump")) {
            scenario.tradeBump = val.toFp64()
        } else (key.equals("attack_bump")) {
            scenario.attackBump = val.toFp64()
        } else (key.equals("dispatch_weight_scout")) {
            scenario.dispatchWeightScout = val.toFp64()
        } else (key.equals("dispatch_weight_colony")) {
            scenario.dispatchWeightColony = val.toFp64()
        } else (key.equals("pirate_attrition")) {
            scenario.pirateAttrition = val.toFp64()
        } else (key.equals("pirate_leftover")) {
            scenario.pirateLeftover = val.toFp64()
        } else (key.equals("battle_strength_duration_coeff")) {
            scenario.battleStrengthDurationCoeff = val.toFp64()
        } else (key.equals("battle_short_circuit_gap")) {
            scenario.battleShortCircuitGap = val.toFp64()
        } else (key.equals("productive_inherent_defense")) {
            scenario.productiveInherentDefense = val.toFp64()
        } else (key.equals("production_tick_rate")) {
            scenario.productionTickRate = val.toFp64()
        } else (key.equals("yard_build_cost_per_size")) {
            scenario.yardBuildCostPerSize = val.toFp64()
        } else (key.equals("design_develop_cost_per_size")) {
            scenario.designDevelopCostPerSize = val.toFp64()
        } else (key.equals("colony_hop_fraction")) {
            scenario.colonyHopFraction = val.toFp64()
        } else (key.equals("home_spawn_min_radius_fraction")) {
            scenario.homeSpawnMinRadiusFraction = val.toFp64()
        } else (key.equals("home_spawn_max_radius_fraction")) {
            scenario.homeSpawnMaxRadiusFraction = val.toFp64()
        } else (key.equals("home_spawn_min_radius_floor")) {
            scenario.homeSpawnMinRadiusFloor = val.toFp64()
        } else (key.equals("useful_livability_fraction")) {
            scenario.usefulLivabilityFraction = val.toFp64()
        } else (key.equals("poor_livability_fraction")) {
            scenario.poorLivabilityFraction = val.toFp64()
        } else (key.equals("poor_resources_fraction")) {
            scenario.poorResourcesFraction = val.toFp64()
        } else (key.equals("home_fallback_livability")) {
            scenario.homeFallbackLivability = val.toFp64()
        } else (key.equals("home_fallback_resources")) {
            scenario.homeFallbackResources = val.toFp64()
        } else (key.equals("contact_reach")) {
            scenario.contactReach = val.toFp64()
        } else (key.equals("rare_mineral_weight")) {
            scenario.rareMineralWeight = val.toFp64()
        } else (key.equals("access_min")) {
            scenario.accessMin = val.toFp64()
        } else (key.equals("access_max")) {
            scenario.accessMax = val.toFp64()
        } else (key.equals("access_floor")) {
            scenario.accessFloor = val.toFp64()
        } else (key.equals("habit_base_ticks")) {
            scenario.habitBaseTicks = val.toInt64()
        } else (key.equals("habit_base_wealth_cost")) {
            scenario.habitBaseWealthCost = val.toFp64()
        } else (key.equals("design_scout_speed")) {
            scenario.designScoutSpeed = val.toFp64()
        } else (key.equals("design_scout_size")) {
            scenario.designScoutSize = val.toFp64()
        } else (key.equals("design_colony_speed")) {
            scenario.designColonySpeed = val.toFp64()
        } else (key.equals("design_colony_size")) {
            scenario.designColonySize = val.toFp64()
        } else (key.equals("design_colony_hold")) {
            scenario.designColonyHold = val.toFp64()
        } else (key.equals("design_freighter_speed")) {
            scenario.designFreighterSpeed = val.toFp64()
        } else (key.equals("design_freighter_size")) {
            scenario.designFreighterSize = val.toFp64()
        } else (key.equals("design_freighter_hold")) {
            scenario.designFreighterHold = val.toFp64()
        } else (key.equals("design_escort_speed")) {
            scenario.designEscortSpeed = val.toFp64()
        } else (key.equals("design_escort_size")) {
            scenario.designEscortSize = val.toFp64()
        } else (key.equals("design_frigate_speed")) {
            scenario.designFrigateSpeed = val.toFp64()
        } else (key.equals("design_frigate_size")) {
            scenario.designFrigateSize = val.toFp64()
        } else (key.equals("design_destroyer_speed")) {
            scenario.designDestroyerSpeed = val.toFp64()
        } else (key.equals("design_destroyer_size")) {
            scenario.designDestroyerSize = val.toFp64()
        } else (key.equals("livability_internal_min")) {
            scenario.livabilityInternalMin = val.toFp64()
        } else (key.equals("livability_internal_max")) {
            scenario.livabilityInternalMax = val.toFp64()
        } else (key.equals("livability_display_min")) {
            scenario.livabilityDisplayMin = val.toInt64()
        } else (key.equals("livability_display_max")) {
            scenario.livabilityDisplayMax = val.toInt64()
        } else (key.equals("start_wealth")) {
            scenario.startWealth = val.toFp64()
        } else (key.equals("start_resources")) {
            scenario.startResources = val.toFp64()
        } else (key.equals("start_tech")) {
            scenario.startTech = val.toFp64()
        } else (key.equals("start_power")) {
            scenario.startPower = val.toFp64()
        } else (key.equals("start_experience")) {
            scenario.startExperience = val.toFp64()
        } else {
            if (ok) {
                ok = false
                lastError = format("unknown setup key: {}", key)
            }
        }
    }

    /*
     * Parse a bool from setup text.
     *
     * Purpose: accept true/false/1/0 without a stdlib bool parser.
     *
     * Parameters:
     *   val — trimmed token.
     *
     * Returns: true for "true"/"1" (case-sensitive true), else false
     * for "false"/"0"; other tokens also false.
     */
    bool parseBool(String val) {
        if (val.equals("true") or val.equals("1")) {
            return(true)
        }
        return(false)
    }
}
