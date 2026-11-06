/*
 * src/cplanets-server.cw — server executable (Phase F).
 *
 * Default (no args): print program name + lib identity (smoke).
 * --serve [--port N] [--players N] [--injectable] [--cycles N]:
 * bind TCP, run accept + cadence loop (sole writer). Stand-alone
 * and online share this driver (RULES §2 / PLAN §4.F).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial stub.
 *   2026-11-05  CODING file header.
 *   2026-11-05  Phase F: TCP serve + injectable driver entry.
 */

import system as Sys

include "lib/machine.cw"
include "lib/state.cw"
include "server/driver.cw"
include "server/handler.cw"
include "server/listen.cw"

/*
 * ServerMain parses argv and runs smoke or serve mode.
 *
 * Kept as a class so method comments stay with the entry logic
 * (CODING.md).
 */
class ServerMain {
    /*
     * Construct the entry helper.
     *
     * Purpose: host argv parsing without free functions.
     *
     * Parameters: none.
     *
     * Returns: ServerMain instance.
     */
    ServerMain() {
    }

    /*
     * Print the smoke identity lines and exit path.
     *
     * Purpose: keep smoke_cplanets-server green (name + lib id).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printSmoke() {
        Machine machine = Machine()
        print("cplanets-server\n")
        print(machine.identity())
        print("\n")
    }

    /*
     * True when argv asks for --serve.
     *
     * Purpose: gate the TCP loop so bare smoke stays instant.
     *
     * Parameters:
     *   args — Sys.Process argv list.
     *
     * Returns: true when --serve is present.
     */
    bool wantsServe(list args) {
        int64 index = 1
        while (index < args.length) {
            String arg = args[index]
            if (arg.equals("--serve")) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Read an int64 flag value following a name, or default.
     *
     * Purpose: parse --port / --players / --cycles without Cli.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag such as "--port".
     *   fallback — value when missing / bad.
     *
     * Returns: parsed int64 or fallback.
     */
    int64 flagInt(list args, String name, int64 fallback) {
        int64 index = 1
        while (index + 1 < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                String text = args[index + 1]
                return(text.toInt64())
            }
            index = index + 1
        }
        return(fallback)
    }

    /*
     * True when a bare flag is present.
     *
     * Purpose: detect --injectable.
     *
     * Parameters:
     *   args — argv list.
     *   name — flag string.
     *
     * Returns: true when found.
     */
    bool hasFlag(list args, String name) {
        int64 index = 1
        while (index < args.length) {
            String arg = args[index]
            if (arg.equals(name)) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

    /*
     * Run the TCP server loop.
     *
     * Purpose: Phase F driver under --serve. Prints PORT= so
     * Python functional tests can connect.
     *
     * Parameters:
     *   args — argv list.
     *
     * Returns: process exit code (0 ok, 1 bind failure).
     */
    int64 runServe(list args) {
        int64 port = flagInt(args, "--port", 0)
        int64 players = flagInt(args, "--players", 2)
        int64 cycles = flagInt(args, "--cycles", 0)
        bool injectable = hasFlag(args, "--injectable")
        if (players < 1) {
            players = 1
        }
        State game = State()
        game.startClosed(7u, players)
        GameDriver driver = GameDriver(
            game,
            injectable,
            "",
            true,
            5000u)
        ServerHandler handler = ServerHandler(driver)
        ServerListen listener = ServerListen(
            handler, driver, 50, cycles)
        if (not listener.listenOn("127.0.0.1", port)) {
            print("cplanets-server: bind failed\n")
            driver.close()
            return(1)
        }
        print("cplanets-server\n")
        print(format("PORT={}\n", listener.getPort()))
        if (injectable) {
            print("INJECTABLE=1\n")
        } else {
            print("INJECTABLE=0\n")
        }
        # Flush so Python functional tests see PORT= before accept.
        Sys.StandardIO().flush()
        listener.serve()
        listener.close()
        driver.close()
        return(0)
    }
}

start {
    ServerMain main = ServerMain()
    Sys.Process process = Sys.Process()
    list args = process.argv()
    if (main.wantsServe(args)) {
        int64 code = main.runServe(args)
        if (code != 0) {
            process.exit(code)
        }
    } else {
        main.printSmoke()
    }
}
