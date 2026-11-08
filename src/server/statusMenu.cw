/*
 * src/server/statusMenu.cw — interactive read-only operator status CLI.
 *
 * In-process console over the same GameDriver State the serve path
 * owns. Walks players / planets / fleets / designs / config without
 * mutating game state. Config is dump-only (no create/save yet).
 * Opened on demand from the serve loop (stdin `m`); Quit returns to
 * accept / cadence.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial interactive status menu.
 *   2026-11-08  Serve-time only: drop --menu pre-serve / exit-without-serve.
 */

# Caller (cplanets-server) imports system as Sys; included files must
# not re-alias the same name (CWHIP1001 duplicate import).

include "statusViews.cw"

/*
 * StatusMenu is the read-only operator explore console.
 *
 * Driven by stdin lines (numbers / b / q). Quitting the top menu
 * returns to the caller (serve loop resumes after pause restore).
 */
class StatusMenu {
    StatusViews views
    Sys.StandardIO io

    /*
     * Construct the console around live formatters.
     *
     * Purpose: share driver state with --serve without a second world.
     *
     * Parameters:
     *   liveViews — StatusViews bound to GameDriver + ServerConfig.
     *
     * Returns: StatusMenu ready for runInteractive.
     */
    StatusMenu(StatusViews liveViews) {
        views = liveViews
        io = Sys.StandardIO()
    }

    /*
     * Read one trimmed stdin line for a menu prompt.
     *
     * Purpose: shared prompt helper; empty on EOF.
     *
     * Parameters:
     *   prompt — text written before blocking on readLine.
     *
     * Returns: trimmed line, or "" on EOF / empty.
     */
    String readChoice(String prompt) {
        print(prompt)
        io.flush()
        String line = io.readLine()
        if (line == null) {
            return("")
        }
        return(line.trim())
    }

    /*
     * Parse a positive integer choice; 0 on failure.
     *
     * Purpose: tolerate junk input without aborting the console.
     *
     * Parameters:
     *   text — trimmed user line.
     *
     * Returns: parsed int64, or 0 when empty / non-numeric.
     */
    int64 parseOrdinal(String text) {
        if (text.length == 0) {
            return(0)
        }
        int64 value = 0
        try {
            value = text.toInt64()
        } except() as error {
            value = 0
        }
        return(value)
    }

    /*
     * Print the top-level menu and banner.
     *
     * Purpose: Status / Players / Planets / Fleets / Designs / Config.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printTopMenu() {
        print("\n=== CPlanets status (read-only) ===\n")
        print(views.summaryLine())
        print("\n")
        print("1) Status summary\n")
        print("2) Players\n")
        print("3) Planets\n")
        print("4) Fleets\n")
        print("5) Designs / jobs\n")
        print("6) Config (read-only)\n")
        print("q) Quit menu (resume serve)\n")
    }

    /*
     * Run the interactive top loop until quit / EOF.
     *
     * Purpose: operator explore while serve is running (stdin `m`).
     *
     * Parameters: none.
     *
     * Returns: nothing (caller restores pause and continues accept).
     */
    void runInteractive() {
        print("cplanets-server status menu\n")
        print("MENU=1\n")
        print("Note: ticks stay paused while this menu is open; ")
        print("q returns to TCP accept / cadence.\n")
        io.flush()
        while (true) {
            printTopMenu()
            String choice = readChoice("status> ")
            if (choice.length == 0) {
                return()
            }
            if (choice.equals("q") or choice.equals("Q")) {
                return()
            }
            if (choice.equals("1")) {
                print(views.statusSummary())
            } else (choice.equals("2")) {
                browsePlayers()
            } else (choice.equals("3")) {
                browsePlanets(-1)
            } else (choice.equals("4")) {
                browseFleets(-1)
            } else (choice.equals("5")) {
                browseDesigns()
            } else (choice.equals("6")) {
                browseConfig()
            } else {
                print("Unknown choice. Use 1-6 or q.\n")
            }
        }
    }

    /*
     * Players list → seat detail → owned planets/fleets/designs.
     *
     * Purpose: drill from seats into inventory sub-views.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void browsePlayers() {
        while (true) {
            print(views.playerList())
            print("Enter seat number, or b to go back.\n")
            String choice = readChoice("players> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            int64 ordinal = parseOrdinal(choice)
            if (ordinal < 1
                or ordinal > views.driver.game.players.length) {
                print("No such seat.\n")
            } else {
                int64 playerId = ordinal - 1
                browsePlayer(playerId)
            }
        }
    }

    /*
     * One-seat submenu: detail + owned planets/fleets/designs.
     *
     * Purpose: player inventory drill-down.
     *
     * Parameters:
     *   playerId — empire seat id.
     *
     * Returns: nothing.
     */
    void browsePlayer(int64 playerId) {
        while (true) {
            print(views.playerDetail(playerId))
            print("1) Planets owned\n")
            print("2) Fleets\n")
            print("3) Designs\n")
            print("b) Back\n")
            String choice = readChoice(
                format("player-{}> ", playerId))
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            if (choice.equals("1")) {
                browsePlanets(playerId)
            } else (choice.equals("2")) {
                browseFleets(playerId)
            } else (choice.equals("3")) {
                print(views.designList())
                print("(Designs are global templates; ")
                print("not per-seat inventory.)\n")
                readChoice("press Enter> ")
            } else {
                print("Unknown choice.\n")
            }
        }
    }

    /*
     * Planet list → planet detail (owner filter optional).
     *
     * Purpose: top Planets menu or player-owned rocks.
     *
     * Parameters:
     *   ownerFilter — owner id, or -1 for all planets.
     *
     * Returns: nothing.
     */
    void browsePlanets(int64 ownerFilter) {
        while (true) {
            print(views.planetList(ownerFilter))
            print("Enter list number for detail, or b to go back.\n")
            String choice = readChoice("planets> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            int64 ordinal = parseOrdinal(choice)
            int64 planetId = views.planetIdAt(ownerFilter, ordinal)
            if (planetId < 0) {
                print("No such planet in this list.\n")
            } else {
                print(views.planetDetail(planetId))
                readChoice("press Enter> ")
            }
        }
    }

    /*
     * Fleet list → fleet detail (owner filter optional).
     *
     * Purpose: top Fleets menu or player-owned stacks.
     *
     * Parameters:
     *   ownerFilter — owner id, or -1 for all fleets.
     *
     * Returns: nothing.
     */
    void browseFleets(int64 ownerFilter) {
        while (true) {
            print(views.fleetList(ownerFilter))
            print("Enter list number for detail, or b to go back.\n")
            String choice = readChoice("fleets> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            int64 ordinal = parseOrdinal(choice)
            int64 fleetId = views.fleetIdAt(ownerFilter, ordinal)
            if (fleetId < 0) {
                print("No such fleet in this list.\n")
            } else {
                print(views.fleetDetail(fleetId))
                readChoice("press Enter> ")
            }
        }
    }

    /*
     * Designs list plus yard build/reclaim jobs.
     *
     * Purpose: top Designs / jobs menu.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void browseDesigns() {
        print(views.designList())
        print(views.jobsList())
        readChoice("press Enter> ")
    }

    /*
     * Config browse: server process knobs + scenario setup dump.
     *
     * Purpose: read-only dump / category browse (no write/save).
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void browseConfig() {
        while (true) {
            print("Config (read-only):\n")
            print("1) Server process / network\n")
            print("2) Scenario / setup knobs\n")
            print("3) Both\n")
            print("b) Back\n")
            String choice = readChoice("config> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            if (choice.equals("1")) {
                print(views.serverConfigDump())
            } else (choice.equals("2")) {
                print(views.scenarioConfigDump())
            } else (choice.equals("3")) {
                print(views.serverConfigDump())
                print(views.scenarioConfigDump())
            } else {
                print("Unknown choice.\n")
            }
        }
    }
}
