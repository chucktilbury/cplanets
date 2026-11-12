/*
 * tests/unit/unit_serverConfig.cw — unit program for ServerConfigParse.
 *
 * Overlays process/network and §14 scenario keys from application
 * text; checks clamp, host/address alias, setup= migration reject,
 * ai-client parse, and that unknown keys fail loud.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial server config unit program.
 *   2026-11-07  Assert handshake_miss_ms / accept_poll_ms.
 *   2026-11-08  Assert menu key.
 *   2026-11-08  Drop menu key (status via stdin m while serving).
 *   2026-11-09  Unified config: §14 keys ok; setup= rejected.
 *   2026-11-10  Assert spawn_ai_* keys (CPL-106).
 *   2026-11-11  CPL-115: assert ai-client; reject spawn_ai_count.
 */

include "server/configParse.cw"

start {
    String text = ""
    text.append("host = 10.0.0.9\n")
    text.append("port = 7700\n")
    text.append("players = 4\n")
    text.append("seed = 99\n")
    text.append("cycles = 12\n")
    text.append("serve = true\n")
    text.append("injectable = true\n")
    text.append("verbosity = 2\n")
    text.append("handshake_miss_ms = 7500\n")
    text.append("accept_poll_ms = 25\n")
    text.append("recv_buffer_bytes = 8192\n")
    text.append("seat_hard_cap = 32\n")
    text.append("verbose_capture_lines = 16\n")
    text.append("ai-client = \"Alex\", soft\n")
    text.append("ai-client = Bethany, mid\n")
    text.append("ai-client = Cameron\n")
    text.append("spawn_ai_dir = /tmp/ai-spawn\n")
    text.append("spawn_ai_bin = /bin/cplanets-ai\n")
    text.append("world_count = 18\n")
    text.append("start_wealth = 2500.0\n")
    text.append("tick_period_seconds = 12\n")
    ServerConfigParse parser = ServerConfigParse()
    ServerConfig cfg = parser.parseText(text)
    bool ok = true
    if (not parser.ok) {
        ok = false
    }
    if (ok and cfg.aiClients.length != 3) {
        ok = false
    }
    if (ok) {
        AiClientEntry a0 = cfg.aiClients[0]
        AiClientEntry a1 = cfg.aiClients[1]
        AiClientEntry a2 = cfg.aiClients[2]
        if (not a0.name.equals("Alex") or not a0.level.equals("soft")) {
            ok = false
        }
        if (not a1.name.equals("Bethany") or not a1.level.equals("mid")) {
            ok = false
        }
        if (not a2.name.equals("Cameron")
            or not a2.level.equals("soft")) {
            ok = false
        }
    }
    if (ok and not cfg.spawnAiDir.equals("/tmp/ai-spawn")) {
        ok = false
    }
    if (ok and not cfg.spawnAiBin.equals("/bin/cplanets-ai")) {
        ok = false
    }
    if (not cfg.host.equals("10.0.0.9")) {
        ok = false
    }
    if (cfg.port != 7700) {
        ok = false
    }
    if (cfg.players != 4) {
        ok = false
    }
    if (cfg.seed != 99) {
        ok = false
    }
    if (cfg.cycles != 12) {
        ok = false
    }
    if (not cfg.serve) {
        ok = false
    }
    if (not cfg.injectable) {
        ok = false
    }
    if (cfg.verbosity != 2) {
        ok = false
    }
    if (cfg.handshakeMissMs != 7500) {
        ok = false
    }
    if (cfg.acceptPollMs != 25) {
        ok = false
    }
    if (cfg.recvBufferBytes != 8192) {
        ok = false
    }
    if (cfg.seatHardCap != 32) {
        ok = false
    }
    if (cfg.verboseCaptureLines != 16) {
        ok = false
    }
    if (cfg.scenario.worldCount != 18) {
        ok = false
    }
    if (cfg.scenario.startWealth != 2500.0f64) {
        ok = false
    }
    if (cfg.scenario.tickPeriodSeconds != 12) {
        ok = false
    }

    # address is an alias for host; verbosity clamps.
    ServerConfigParse aliasParser = ServerConfigParse()
    ServerConfig aliased = aliasParser.parseText(
        "address = 0.0.0.0\nverbosity = 99\n")
    if (not aliasParser.ok) {
        ok = false
    }
    if (not aliased.host.equals("0.0.0.0")) {
        ok = false
    }
    if (aliased.verbosity != 10) {
        ok = false
    }

    # Legacy setup= path must fail loud with migration hint.
    ServerConfigParse setupParser = ServerConfigParse()
    setupParser.parseText(
        "setup = scenarios/closed-default.setup\n")
    if (setupParser.ok) {
        ok = false
    }
    if (not setupParser.lastError.startsWith("setup path removed")) {
        ok = false
    }

    # Legacy spawn_ai_count must fail loud with migration hint.
    ServerConfigParse spawnParser = ServerConfigParse()
    spawnParser.parseText("spawn_ai_count = 2\n")
    if (spawnParser.ok) {
        ok = false
    }
    if (not spawnParser.lastError.startsWith("spawn_ai_count")) {
        ok = false
    }

    # Truly unknown keys still fail loud.
    String bad = ""
    bad.append("port = 1\n")
    bad.append("not_a_real_knob = 1\n")
    ServerConfigParse badParser = ServerConfigParse()
    ServerConfig ignored = badParser.parseText(bad)
    if (badParser.ok) {
        ok = false
    }
    if (not badParser.lastError.startsWith(
        "unknown server config key:")) {
        ok = false
    }
    if (ignored.port != 1) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
