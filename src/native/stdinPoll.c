/*
 * src/native/stdinPoll.c — non-blocking stdin readiness for serve.
 *
 * poll(2) with timeout 0 on STDIN_FILENO so the TCP accept loop can
 * notice an operator keystroke without blocking forever on readLine.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial cplanets_stdin_pending binding.
 */

#include <poll.h>
#include <stdint.h>
#include <unistd.h>

/*
 * Return whether stdin has bytes ready to read (non-blocking).
 *
 * Bound from Cwhip as StdinPoll.pending() / cplanets_stdin_pending.
 * The unused `self` matches the out-of-line native method ABI.
 */
int32_t cplanets_stdin_pending(void *self) {
    (void)self;
    struct pollfd pfd;
    pfd.fd = STDIN_FILENO;
    pfd.events = POLLIN;
    pfd.revents = 0;
    if (poll(&pfd, 1, 0) <= 0) {
        return 0;
    }
    if ((pfd.revents & (POLLERR | POLLNVAL)) != 0) {
        return 0;
    }
    return ((pfd.revents & POLLIN) != 0) ? 1 : 0;
}
