/*
 * src/native/socketCloexec.c — FD_CLOEXEC on listen sockets.
 *
 * AsyncProcess / posix_spawnp inherits open fds. Without CLOEXEC on
 * the TCP listen socket, spawned cplanets-ai children keep a duplicate
 * of the listen fd. After the parent exits (or is killed), those
 * orphans still hold host:port and the next cplanets-server prints
 * "bind failed" (EADDRINUSE). Set FD_CLOEXEC immediately after bind.
 *
 * Created: 2026-11-12
 * Author: Auto
 *
 * Changelog:
 *   2026-11-12  CPL-117: initial cplanets_socket_cloexec binding.
 */

#include <fcntl.h>
#include <stdint.h>

/*
 * Set FD_CLOEXEC on an open socket fd.
 *
 * Bound from Cwhip as SocketCloexec.apply(fd) /
 * cplanets_socket_cloexec. The unused `self` matches the out-of-line
 * native method ABI. Returns 1 on success, 0 on invalid fd or fcntl
 * failure (caller still owns the socket either way).
 */
int32_t cplanets_socket_cloexec(void *self, int64_t fd) {
    (void)self;
    if (fd < 0) {
        return 0;
    }
    int flags = fcntl((int)fd, F_GETFD);
    if (flags < 0) {
        return 0;
    }
    if (fcntl((int)fd, F_SETFD, flags | FD_CLOEXEC) < 0) {
        return 0;
    }
    return 1;
}
