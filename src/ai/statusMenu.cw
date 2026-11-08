/*
 * src/ai/statusMenu.cw — interactive read-only AI status CLI.
 *
 * In-process console over AiExploreState (what this client knows).
 * Walks seat / snapshot / planets / fleets / designs / config /
 * decisions without mutating game state or inventing server-only
 * facts. Opened on demand from the serve-loop (stdin `m`); Quit
 * returns to the decision loop.
 *
 * Created: 2026-11-08
 * Author: Auto
 *
 * Changelog:
 *   2026-11-08  Initial AI client status menu.
 */

include "statusViews.cw"

/*
 * AiStatusMenu is the read-only AI explore console.
 *
 * Driven by stdin lines (numbers / b / q). Quitting the top menu
 * returns to the caller (serve-loop resumes after pause clear).
 */
class AiStatusMenu {
    AiStatusViews views
    Sys.StandardIO io

    /*
     * Construct the console around live formatters.
     *
     * Purpose: share explore state with --serve-loop without a
     * second world.
     *
     * Parameters:
     *   liveViews — AiStatusViews bound to AiExploreState.
     *
     * Returns: AiStatusMenu ready for runInteractive.
     */
    AiStatusMenu(AiStatusViews liveViews) {
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
     * Purpose: Status / Seat / Snapshot / Planets / Fleets /
     * Designs / Config / Decisions.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void printTopMenu() {
        print("\n=== CPlanets AI status (read-only) ===\n")
        print(views.summaryLine())
        print("\n")
        print("1) Status summary\n")
        print("2) Seat / role\n")
        print("3) Last snapshot\n")
        print("4) Planets (client-visible)\n")
        print("5) Fleets (client-visible)\n")
        print("6) Designs / jobs\n")
        print("7) Config (read-only)\n")
        print("8) Decisions / errors\n")
        print("q) Quit menu (resume AI loop)\n")
    }

    /*
     * Run the interactive top loop until quit / EOF.
     *
     * Purpose: operator explore while --serve-loop is running
     * (stdin `m`).
     *
     * Parameters: none.
     *
     * Returns: nothing (caller clears pause and continues cycles).
     */
    void runInteractive() {
        print("cplanets-ai status menu\n")
        print("MENU=1\n")
        print("Note: AI decision loop stays paused while this ")
        print("menu is open; q returns to serve-loop cycles.\n")
        print("Scope: this client's knowledge only ")
        print("(decoded GET view + local config/decisions).\n")
        io.flush()
        while (true) {
            printTopMenu()
            String choice = readChoice("ai-status> ")
            if (choice.length == 0) {
                return()
            }
            if (choice.equals("q") or choice.equals("Q")) {
                return()
            }
            if (choice.equals("1")) {
                print(views.statusSummary())
            } else (choice.equals("2")) {
                print(views.seatDetail())
                readChoice("press Enter> ")
            } else (choice.equals("3")) {
                print(views.snapshotSummary())
                readChoice("press Enter> ")
            } else (choice.equals("4")) {
                browsePlanets()
            } else (choice.equals("5")) {
                browseFleets()
            } else (choice.equals("6")) {
                print(views.designList())
                readChoice("press Enter> ")
            } else (choice.equals("7")) {
                print(views.configDump())
                readChoice("press Enter> ")
            } else (choice.equals("8")) {
                print(views.decisionsDump())
                readChoice("press Enter> ")
            } else {
                print("Unknown choice. Use 1-8 or q.\n")
            }
        }
    }

    /*
     * Planet list → planet detail.
     *
     * Purpose: client-visible rocks drill-down.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void browsePlanets() {
        while (true) {
            print(views.planetList())
            print("Enter list number for detail, or b to go back.\n")
            String choice = readChoice("planets> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            int64 ordinal = parseOrdinal(choice)
            int64 planetId = views.planetIdAt(ordinal)
            if (planetId < 0) {
                print("No such planet in this list.\n")
            } else {
                print(views.planetDetail(planetId))
                readChoice("press Enter> ")
            }
        }
    }

    /*
     * Fleet list → fleet detail.
     *
     * Purpose: client-visible fleets drill-down.
     *
     * Parameters: none.
     *
     * Returns: nothing.
     */
    void browseFleets() {
        while (true) {
            print(views.fleetList())
            print("Enter list number for detail, or b to go back.\n")
            String choice = readChoice("fleets> ")
            if (choice.length == 0
                or choice.equals("b")
                or choice.equals("B")) {
                return()
            }
            int64 ordinal = parseOrdinal(choice)
            int64 fleetId = views.fleetIdAt(ordinal)
            if (fleetId < 0) {
                print("No such fleet in this list.\n")
            } else {
                print(views.fleetDetail(fleetId))
                readChoice("press Enter> ")
            }
        }
    }
}
