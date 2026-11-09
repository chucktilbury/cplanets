/*
 * src/native/stdinPoll.c — non-blocking stdin readiness for serve.
 *
 * poll(2) with timeout 0 on STDIN_FILENO so the TCP accept loop can
 * notice an operator keystroke without blocking forever on readLine.
 * Also peeks the stdio FILE buffer: after one readLine(), libc may
 * already hold later pipe lines while poll(2) reports idle.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial cplanets_stdin_pending binding.
 *   2026-11-09  Treat stdio-buffered bytes as pending (stray-then-m).
 *   2026-11-09  Do not treat EOF POLLIN (/dev/null, closed pipe) as
 *               pending — peek a real byte so ServeMenuGate cannot
 *               starve TCP accept under ctest.
 */

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

/*
 * True when stdin's stdio buffer already holds at least one byte.
 *
 * Purpose: after StandardIO.readLine consumes one line from a pipe,
 * libc often has the next lines buffered while poll(2) on the fd is
 * idle. A non-blocking fgetc/ungetc peeks that buffer (and will also
 * pull from the fd when the buffer is empty) without blocking the
 * serve loop.
 *
 * Parameters: none.
 *
 * Returns: 1 when a byte is available to read without blocking,
 * 0 when not (including true EOF with nothing left).
 */
static int stdin_stdio_readable(void) {
    int flags = fcntl(STDIN_FILENO, F_GETFL);
    if (flags < 0) {
        return 0;
    }
    if (fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) < 0) {
        return 0;
    }
    errno = 0;
    int ch = fgetc(stdin);
    int got = 0;
    if (ch != EOF) {
        ungetc(ch, stdin);
        got = 1;
    } else {
        /*
         * EOF or EAGAIN/EWOULDBLOCK. clearerr so a transient
         * non-blocking miss does not poison later reads; leave feof
         * alone when truly at EOF so readLine can still observe it.
         */
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            clearerr(stdin);
        } else if (!feof(stdin)) {
            clearerr(stdin);
        }
        got = 0;
    }
    (void)fcntl(STDIN_FILENO, F_SETFL, flags);
    return got;
}

/*
 * Return whether stdin has bytes ready to read (non-blocking).
 *
 * Bound from Cwhip as StdinPoll.pending() / cplanets_stdin_pending.
 * True only when a real byte is available (kernel or stdio buffer),
 * so a drain loop can keep calling readLine after the first line
 * without blocking — and so EOF POLLIN on /dev/null does not look
 * like pending input. The unused `self` matches the out-of-line
 * native method ABI.
 */
int32_t cplanets_stdin_pending(void *self) {
    (void)self;
    struct pollfd pfd;
    pfd.fd = STDIN_FILENO;
    pfd.events = POLLIN;
    pfd.revents = 0;
    int pr = poll(&pfd, 1, 0);
    if (pr < 0 || (pfd.revents & (POLLERR | POLLNVAL)) != 0) {
        return 0;
    }
    /*
     * POLLIN is also set at EOF (/dev/null under ctest, closed
     * pipe). Returning 1 here made ServeMenuGate drain forever
     * and never reach accept — harness handshakes saw empty
     * replies. Always require a real readable byte (kernel or
     * stdio buffer), including the buffered-after-readLine case.
     */
    (void)pr;
    return stdin_stdio_readable() ? 1 : 0;
}
