/*
 * tests/unit/unit_displayName.cw — seat names + publish (CPL-106).
 *
 * Created: 2026-11-10
 * Author: Auto
 *
 * Changelog:
 *   2026-11-10  Initial display-name round-trip unit.
 */

include "ai/configParse.cw"
include "client/configParse.cw"
include "client/publishDecode.cw"
include "lib/state.cw"
include "server/configParse.cw"
include "server/driver.cw"
include "server/policyTable.cw"
include "server/publish.cw"

start {
    bool ok = true

    # --- Player.label fallback + setDisplayName ---
    Player bare = Player(3)
    if (not bare.label().equals("Player 3")) {
        ok = false
    }
    if (ok and not bare.setDisplayName("Bethany")) {
        ok = false
    }
    if (ok and not bare.label().equals("Bethany")) {
        ok = false
    }
    if (ok and bare.setDisplayName("  ")) {
        ok = false
    }

    # --- Driver PUT /name path + publish decode ---
    State game = State()
    game.startClosed(17u, 0)
    GameDriver drv = GameDriver(game, true, "", false, 5000u)
    int64 seat = drv.handshakeAllocateAs(false)
    if (seat != 0) {
        ok = false
    }
    if (ok and not drv.setPlayerDisplayName(seat, "Alex")) {
        ok = false
    }
    Player named = drv.game.players[seat]
    if (ok and not named.displayName.equals("Alex")) {
        ok = false
    }

    PolicyTable policies = PolicyTable()
    policies.ensureSeats(drv.game.players.length)
    PublishCodec codec = PublishCodec()
    buffer blob = codec.encodeStateView(
        drv.game, policies, seat, false)
    if (blob.length < 1) {
        ok = false
    }
    PublishDecode decoder = PublishDecode()
    ClientStateView view = decoder.decodeState(blob, seat)
    if (ok and view.players.length < 1) {
        ok = false
    }
    if (ok and not view.playerDisplayName(seat).equals("Alex")) {
        ok = false
    }
    PlanetRow home = view.findPlanet(0)
    if (ok and home.id == 0) {
        if (not home.ownerName.equals("Alex")) {
            ok = false
        }
        if (ok and not home.listLabel().contains("owner=Alex")) {
            ok = false
        }
    }

    # --- AI allocate + name ---
    int64 aiSeat = drv.handshakeAllocateAs(true)
    if (ok and aiSeat < 1) {
        ok = false
    }
    if (ok and not drv.setPlayerDisplayName(aiSeat, "Cameron")) {
        ok = false
    }
    Player ai = drv.game.players[aiSeat]
    if (ok and ai.human) {
        ok = false
    }
    if (ok and not ai.label().equals("Cameron")) {
        ok = false
    }

    # --- config keys ---
    HumanConfigParse hp = HumanConfigParse()
    HumanConfig hcfg = hp.parseText("display_name = Dana\n")
    if (ok and not hcfg.displayName.equals("Dana")) {
        ok = false
    }
    if (ok and not hcfg.resolvedDisplayName().equals("Dana")) {
        ok = false
    }
    AiConfigParse ap = AiConfigParse()
    AiConfig acfg = ap.parseText(
        "display_name = Elena\nseed = 7\n")
    if (ok and not ap.ok) {
        ok = false
    }
    if (ok and not acfg.displayName.equals("Elena")) {
        ok = false
    }
    AiConfig blank = AiConfig()
    blank.seed = 11u
    String picked = blank.ensureDisplayName()
    if (ok and picked.length < 1) {
        ok = false
    }
    ServerConfigParse sp = ServerConfigParse()
    String stext = ""
    stext.append("spawn_ai_count = 2\n")
    stext.append("spawn_ai_template = config/ai-default.cfg\n")
    stext.append("spawn_ai_dir = /tmp/cplanets-ai\n")
    stext.append("spawn_ai_bin = /opt/cplanets-ai\n")
    ServerConfig scfg = sp.parseText(stext)
    if (ok and not sp.ok) {
        ok = false
    }
    if (ok and scfg.spawnAiCount != 2) {
        ok = false
    }
    if (ok and not scfg.spawnAiTemplate.equals(
        "config/ai-default.cfg")) {
        ok = false
    }
    if (ok and not scfg.spawnAiDir.equals("/tmp/cplanets-ai")) {
        ok = false
    }
    if (ok and not scfg.spawnAiBin.equals("/opt/cplanets-ai")) {
        ok = false
    }

    if (ok) {
        print("true\n")
    } else {
        print("false\n")
    }
}
