/*
 * src/server/listen.cw — TCP accept loop, one writer (Phase F).
 *
 * Binds a listen socket, accepts with SO_RCVTIMEO so the injectable
 * / wall cadence can run between accepts, and handles one request /
 * response per connection burst. Clients never open the DB
 * (RULES §2 / PLAN §4.F). Between accept cycles, an optional
 * ServeMenuGate may open the read-only status menu on stdin `m`
 * without blocking accept forever (non-blocking poll).
 *
 * Gap: Cwhip networking has no select/poll multiplex and no
 * stream reassembly helper — each recv assumes a complete envelope
 * in one read (fine on localhost smoke; document for LAN fragments).
 * Contract: one request / response per accepted connection; clients
 * must dial fresh for every verb (HumanSession / AiClient exchange).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial TCP listener with timeout accept.
 *   2026-11-06  Document one-shot TCP client contract.
 *   2026-11-08  Poll ServeMenuGate between accept / maybeTick cycles.
 *   2026-11-09  Menu gate drains stray stdin; lobby Go closes menu.
 *   2026-11-09  recvBufferBytes from server config (was 65536).
 *   2026-11-12  CPL-117: FD_CLOEXEC on listen fd (AI spawn inherit).
 *   2026-11-12  CPL-118: poll deferred AiSpawnBook (human / go).
 *   2026-11-12  AI spawn only after lobby go (not human connect).
 */

import networking as Networking

include "aiSpawn.cw"
include "handler.cw"
include "serveMenuGate.cw"
include "socketCloexec.cw"

/*
 * ServerListen owns the TCP socket and accept / handle loop.
 *
 * Uses Networking.Runtime directly so the listen fd can take
 * SO_RCVTIMEO (ServerSocket has no setTimeout). One writer: all
 * mutations go through ServerHandler → GameDriver. menuGate stays
 * disabled unless the server calls enable() before serve().
 * Optional aiSpawns (armDeferred) fires after lobby go — not at
 * listen and not on human connect alone.
 */
class ServerListen {
    Networking.Runtime net
    int64 fd
    int64 port
    ServerHandler handler
    GameDriver driver
    int64 acceptTimeoutMs
    int64 maxCycles
    int64 cycles
    int64 recvBufferBytes
    ServeMenuGate menuGate
    AiSpawnBook aiSpawns

    /*
     * Construct a listener bound to a handler/driver.
     *
     * Purpose: delay bind until listenOn so tests can skip TCP.
     *
     * Parameters:
     *   gameHandler — request dispatcher.
     *   gameDriver — sole writer (for maybeTick between accepts).
     *   timeoutMs — accept/recv timeout (cadence poll granularity).
     *   cycleLimit — stop after this many accept attempts
     *                (0 = unlimited; tests pass a small N).
     *   recvBytes — max bytes per accepted client recv
     *               (server config recv_buffer_bytes).
     *
     * Returns: ServerListen with fd -1 and a disabled menu gate.
     */
    ServerListen(
        ServerHandler gameHandler,
        GameDriver gameDriver,
        int64 timeoutMs,
        int64 cycleLimit,
        int64 recvBytes) {
        net = Networking.Runtime()
        fd = -1
        port = 0
        handler = gameHandler
        driver = gameDriver
        acceptTimeoutMs = timeoutMs
        maxCycles = cycleLimit
        cycles = 0
        recvBufferBytes = recvBytes
        if (recvBufferBytes < 1024) {
            recvBufferBytes = 1024
        }
        menuGate = ServeMenuGate()
        aiSpawns = null
    }

    /*
     * Attach a deferred AI spawn book for the serve loop.
     *
     * Purpose: cplanets-server arms AiSpawnBook after listen; serve
     * polls maybeSpawn so children launch after a human (or go).
     *
     * Parameters:
     *   book — armed AiSpawnBook (or null to disable).
     *
     * Returns: nothing.
     */
    void enableAiSpawn(AiSpawnBook book) {
        aiSpawns = book
    }

    /*
     * Bind and listen on host:port (0 = ephemeral).
     *
     * Purpose: start the TCP façade. Prints nothing; caller may
     * read getPort() for clients.
     *
     * Parameters:
     *   host — bind address ("" = all interfaces).
     *   wantPort — TCP port, or 0 for ephemeral.
     *
     * Returns: true when bound and listening.
     */
    bool listenOn(String host, int64 wantPort) {
        if (fd >= 0) {
            net.socketClose(fd)
            fd = -1
        }
        fd = net.serverBind(host, wantPort, 16)
        if (fd < 0) {
            return(false)
        }
        # Prevent AsyncProcess AI children from inheriting the listen
        # fd (orphans otherwise keep host:port after the parent exits).
        SocketCloexec().apply(fd)
        port = net.serverPort(fd)
        net.socketSetTimeout(fd, acceptTimeoutMs)
        return(port > 0)
    }

    /*
     * Return the bound TCP port.
     *
     * Purpose: Python / clients discover ephemeral ports.
     *
     * Parameters: none.
     *
     * Returns: port, or 0 when not bound.
     */
    int64 getPort() {
        return(port)
    }

    /*
     * Run accept / maybeTick cycles until ended or cycle limit.
     *
     * Purpose: sole server loop. On accept timeout, still calls
     * maybeTick so wall cadence advances without a client. When the
     * menu gate is enabled, a non-blocking stdin poll may open the
     * status console (ticks paused while open). When aiSpawns is
     * armed, maybeSpawn runs each cycle after accept handling so
     * lobby go (Pause uncheck / console g / admin go) can launch AI.
     *
     * Parameters: none.
     *
     * Returns: number of request frames handled.
     */
    int64 serve() {
        int64 handled = 0
        while (not driver.game.ended) {
            if (maxCycles > 0 and cycles >= maxCycles) {
                return(handled)
            }
            cycles = cycles + 1
            menuGate.pollOnce()
            pollDeferredAiSpawn()
            driver.maybeTick()
            if (driver.game.ended) {
                return(handled)
            }
            int64 client = net.serverAccept(fd)
            if (client < 0) {
                continue
            }
            net.socketSetTimeout(client, acceptTimeoutMs)
            buffer request = net.socketRecv(client, recvBufferBytes)
            if (request == null or request.length < 1) {
                net.socketClose(client)
                continue
            }
            buffer response = handler.handleFrame(request)
            if (response.length > 0) {
                net.socketSend(client, response)
                handled = handled + 1
            }
            net.socketClose(client)
            # Handshake may have seated a human on this frame —
            # try spawn before the next accept timeout wait.
            pollDeferredAiSpawn()
        }
        return(handled)
    }

    /*
     * Fire deferred AI spawn after lobby go (PHASE=running).
     *
     * Purpose: keep serve() free of spawn details; log once on
     * failure without aborting an already-connected human session.
     * Human connect alone must not spawn (lobby stays quiet).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void pollDeferredAiSpawn() {
        if (aiSpawns == null) {
            return()
        }
        if (not aiSpawns.maybeSpawn(driver.running)) {
            print(format(
                "cplanets-server: AI spawn failed: {}\n",
                aiSpawns.lastError))
            Sys.StandardIO().flush()
        }
    }

    /*
     * Close the listen socket.
     *
     * Purpose: shut down after serve / tests.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void close() {
        if (fd >= 0) {
            net.socketClose(fd)
            fd = -1
            port = 0
        }
    }
}
