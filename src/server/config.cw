/*
 * src/server/config.cw — unified server process + scenario knobs.
 *
 * One operator file for listen/serve runtime and former §14 scenario
 * magnitudes (RULES §2 / preferences). Missing or unopenable
 * --config is a hard error; there is no separate setup= path and no
 * silent builtin fallback when a file was expected.
 *
 * Created: 2026-11-07
 * Author: Auto
 *
 * Changelog:
 *   2026-11-07  Initial ServerConfig (split from setup process keys).
 *   2026-11-07  handshake_miss_ms + accept_poll_ms (former literals).
 *   2026-11-08  menu flag for read-only operator status console.
 *   2026-11-08  Drop menu flag; status opens via stdin m while serving.
 *   2026-11-08  players = optional soft max seats (0 = unlimited).
 *   2026-11-09  Fold Scenario into ServerConfig; drop setup path.
 *   2026-11-09  recv_buffer_bytes, seat_hard_cap, verbose_capture_lines.
 *   2026-11-10  spawn_ai_* keys for server-launched AI clients
 *               (CPL-106).
 */

/*
 * ServerConfig holds network / process defaults plus the Scenario
 * snapshot for one serve start. Callers must include Scenario
 * (via setupParse / state / scenario.cw) before this file.
 *
 * Every CLI flag except --config PATH maps to a field here (or to
 * a Scenario §14 key with no argv overlay). Load from text via
 * ServerConfigParse, then let argv override silently when
 * wasProvided. scenario starts as Scenario() closed defaults;
 * recognized §14 keys overlay in-file. configPath is runtime-only
 * (the --config path; not a file key).
 */
class ServerConfig {
    # Runtime-only: path passed as --config (banner / diagnostics).
    String configPath
    String host
    int64 port
    # Soft maximum of allocated seats (0 = unlimited). Also the
    # expected-ceiling hint shown in status when > 0. Not a fixed
    # pre-created seat array — live serve starts empty and grows.
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
    # Max bytes per accepted client recv (former 65536 literal).
    int64 recvBufferBytes
    # Absolute seat bound when players soft max is 0 / unlimited
    # (former State.appendSeat 256 literal). Soft max still wins when set.
    int64 seatHardCap
    # ServerVerboseLog ring size (former maxLines 64 literal).
    int64 verboseCaptureLines
    # How many AI client processes to spawn after listen (0 = none).
    # Each child gets its own config file under spawnAiDir with a
    # unique display_name from the proper-name pool (CPL-106).
    int64 spawnAiCount
    # AI config template copied per spawned child (required when
    # spawnAiCount > 0). Typically config/ai-default.cfg.
    String spawnAiTemplate
    # Directory for generated per-AI configs. Empty → system temp
    # dir under a cplanets-ai-spawn-* folder.
    String spawnAiDir
    # Path to cplanets-ai. Empty → sibling of this process argv[0].
    String spawnAiBin
    # §14 galaxy / economy / combat / design magnitudes.
    Scenario scenario

    /*
     * Construct CLI-matching process defaults + closed Scenario.
     *
     * Purpose: give loaders and bare-argv serve the same baseline as
     * buildCli() defaults (loopback bind, ephemeral port, soft max
     * 0 = unlimited seats grown on connect) plus Scenario() §14
     * closed fixture magnitudes.
     *
     * Parameters: none.
     *
     * Returns: ServerConfig with host 127.0.0.1, port 0, seed 7,
     * closed scenario defaults, and practical buffer/seat caps.
     */
    ServerConfig() {
        configPath = ""
        host = "127.0.0.1"
        port = 0
        players = 0
        seed = 7
        cycles = 0
        serve = false
        injectable = false
        verbosity = 0
        handshakeMissMs = 5000
        acceptPollMs = 50
        recvBufferBytes = 65536
        seatHardCap = 256
        verboseCaptureLines = 64
        spawnAiCount = 0
        spawnAiTemplate = ""
        spawnAiDir = ""
        spawnAiBin = ""
        scenario = Scenario()
    }

    /*
     * Clamp seat, port, seed, cycles, verbosity, and buffer bands.
     *
     * Purpose: harden after text load so listen / start never see
     * negative ports or out-of-range verbosity. players is a soft
     * max: 0 stays 0 (unlimited); negatives clamp to 0. Also clamps
     * nested scenario tick period and verbosity fields.
     *
     * Parameters: none (mutates this config).
     *
     * Returns: nothing.
     */
    void clampAll() {
        if (port < 0) {
            port = 0
        }
        if (players < 0) {
            players = 0
        }
        if (seed < 0) {
            seed = 0
        }
        if (cycles < 0) {
            cycles = 0
        }
        if (verbosity < 0) {
            verbosity = 0
        }
        if (spawnAiCount < 0) {
            spawnAiCount = 0
        } else (verbosity > 10) {
            verbosity = 10
        }
        if (handshakeMissMs < 1) {
            handshakeMissMs = 1
        }
        if (acceptPollMs < 1) {
            acceptPollMs = 1
        }
        if (recvBufferBytes < 1024) {
            recvBufferBytes = 1024
        }
        if (seatHardCap < 1) {
            seatHardCap = 1
        }
        if (verboseCaptureLines < 1) {
            verboseCaptureLines = 1
        }
        if (host.length == 0) {
            host = "127.0.0.1"
        }
        scenario.clampTickPeriod()
        scenario.clampVerbosity()
    }
}
