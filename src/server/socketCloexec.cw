/*
 * src/server/socketCloexec.cw — Cwhip binding for FD_CLOEXEC on fds.
 *
 * Wraps native cplanets_socket_cloexec so ServerListen can mark the
 * TCP listen socket close-on-exec before AsyncProcess spawns AI
 * children (CPL-117).
 *
 * Created: 2026-11-12
 * Author: Auto
 *
 * Changelog:
 *   2026-11-12  Initial SocketCloexec binding.
 */

/*
 * SocketCloexec sets FD_CLOEXEC on an open file descriptor.
 *
 * Construct a throwaway instance and call apply(fd) after serverBind.
 * Failures are soft — the listen socket remains usable; only child
 * inherit protection is missing.
 */
class SocketCloexec {
    /*
     * Construct the helper.
     *
     * Purpose: host the native apply() binding (no instance state).
     *
     * Parameters: none.
     *
     * Returns: SocketCloexec instance.
     */
    SocketCloexec() {
    }

    /*
     * Mark fd close-on-exec.
     *
     * Purpose: keep spawned AI clients from inheriting the listen
     * socket (otherwise orphans hold host:port after the server
     * exits and the next bind fails with EADDRINUSE).
     *
     * Parameters:
     *   fd — open socket descriptor from serverBind (≥ 0).
     *
     * Returns: true when fcntl succeeded.
     */
    bool apply(int64 fd)
}

bool SocketCloexec.apply(int64 fd) from "cplanets_socket_cloexec"
