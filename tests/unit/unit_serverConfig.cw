/*
 * tests/unit/unit_serverConfig.cw — unit program for ServerConfigParse.
 *
 * Overlays process/network keys from application text; checks clamp,
 * host/address alias, and that scenario-only knobs fail loud.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial server config unit program.
 *   2026-11-07  Assert handshake_miss_ms / accept_poll_ms.
 */

include "server/configParse.cw"

start {
    String text = ""
    text.append("setup = scenarios/closed-default.setup\n")
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
    ServerConfigParse parser = ServerConfigParse()
    ServerConfig cfg = parser.parseText(text)
    bool ok = true
    if (not parser.ok) {
        ok = false
    }
    if (not cfg.setup.equals("scenarios/closed-default.setup")) {
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

    # address is an alias for host.
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

    # Scenario-only keys must not silently no-op on the server surface.
    String bad = ""
    bad.append("port = 1\n")
    bad.append("world_count = 10\n")
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
