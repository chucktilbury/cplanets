/*
 * src/server/config.cw — server process / network runtime knobs.
 *
 * Own file surface parallel to AI/human configs (RULES §2). Holds
 * listen bind, serve loop, seed/players, and verbosity — not §14
 * galaxy magnitudes (those stay in --setup / scenario files).
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerConfig (split from setup process keys).
 *   2026-11-07  handshake_miss_ms + accept_poll_ms (former literals).
 */

/*
 * ServerConfig holds network + process defaults for cplanets-server.
 *
 * Every CLI flag except --config PATH maps to a field here. Load
 * from text via ServerConfigParse, then let argv override silently
 * when wasProvided. setup is a path to a scenario file (empty =
 * builtin closed defaults); CLI --setup overlays this key.
 */
class ServerConfig {
    String setup
    String host
    int64 port
    int64 players
    int64 seed
    int64 cycles
    bool serve
    bool injectable
    # Stdout log level 0–10 (clamped). Copied onto Scenario.verbosity
    # after galaxy start so driver / verboseLog keep reading scenario.
    int64 verbosity
    # Presence drop window without handshake (ms). Former 5000u literal.
    int64 handshakeMissMs
    # Accept/recv poll timeout (ms). Former 50 literal on ServerListen.
    int64 acceptPollMs

    /*
     * Construct CLI-matching process defaults.
     *
     * Purpose: give loaders and bare-argv serve the same baseline as
     * buildCli() defaults (loopback bind, ephemeral port, 2 seats).
     *
     * Parameters: none.
     *
     * Returns: ServerConfig with host 127.0.0.1, port 0, seed 7.
     */
    ServerConfig() {
        setup = ""
        host = "127.0.0.1"
        port = 0
        players = 2
        seed = 7
        cycles = 0
        serve = false
        injectable = false
        verbosity = 0
        handshakeMissMs = 5000
        acceptPollMs = 50
    }

    /*
     * Clamp seat, port, seed, cycles, and verbosity into legal bands.
     *
     * Purpose: harden after text load so listen / start never see
     * negative ports or out-of-range verbosity.
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void clampAll() {
        if (port < 0) {
            port = 0
        }
        if (players < 1) {
            players = 1
        }
        if (seed < 0) {
            seed = 0
        }
        if (cycles < 0) {
            cycles = 0
        }
        if (verbosity < 0) {
            verbosity = 0
        } else (verbosity > 10) {
            verbosity = 10
        }
        if (handshakeMissMs < 1) {
            handshakeMissMs = 1
        }
        if (acceptPollMs < 1) {
            acceptPollMs = 1
        }
        if (host.length == 0) {
            host = "127.0.0.1"
        }
    }
}
