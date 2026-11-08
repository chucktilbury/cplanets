#!/usr/bin/env python3
"""Headless tuning session: setup + seed + AI join + digest advance.

TUNING-PLAYABLE C2: spawn injectable server on a closed fixture,
attach cplanets-ai (--serve-loop), human-shaped wire GET/PUT, and
assert tick/digest growth without GTK.
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from wire import (
    admin_advance,
    decode_envelope,
    get_digest,
    get_state,
    handshake,
    parse_handshake_ack,
    put_policy,
)

LIST_MARKER = 1196445777
# Fixed seed for comparable re-runs after knob edits.
HARNESS_SEED = 77


def exchange(host: str, port: int, frame: bytes, timeout: float = 2.0) -> bytes:
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(frame)
        chunks: list[bytes] = []
        while True:
            try:
                data = sock.recv(65536)
            except socket.timeout:
                break
            if not data:
                break
            chunks.append(data)
        return b"".join(chunks)


def u32(buf: bytes, off: int) -> int:
    return int.from_bytes(buf[off : off + 4], "little")


def state_payload(body: bytes) -> bytes:
    blob_len = u32(body, 4)
    return body[8 : 8 + blob_len]


def parse_state_tick_planets(blob: bytes) -> tuple[int, int]:
    """Return (tick, planet_count) from a publish state blob."""
    off = 0
    tick = u32(blob, off)
    off += 4
    off += 1  # ended
    off += 4  # winner
    player_count = u32(blob, off)
    off += 4
    for _ in range(player_count):
        off += 4  # id
        off += 4  # wealth milli
        off += 3  # quit, drop, human
    policy_count = u32(blob, off)
    off += 4
    for _ in range(policy_count):
        plen = u32(blob, off)
        off += 4 + plen
    if off + 8 > len(blob):
        raise ValueError("missing list marker")
    marker = u32(blob, off)
    off += 4
    if marker != LIST_MARKER:
        raise ValueError(f"bad list marker {marker}")
    off += 4  # viewerId+1
    planet_count = u32(blob, off)
    return tick, planet_count


def parse_digest_body(body: bytes) -> tuple[int, int, int]:
    """Return (resp_tick, blob_tick, event_count) from GET /digest."""
    resp_tick = u32(body, 0)
    blob_len = u32(body, 4)
    blob = body[8 : 8 + blob_len]
    if blob_len < 8:
        return resp_tick, -1, 0
    blob_tick = u32(blob, 0)
    event_count = u32(blob, 4)
    return resp_tick, blob_tick, event_count


def spawn_server(
    server: Path, setup: Path, server_config: Path, seed: int
) -> tuple[subprocess.Popen, int]:
    env = os.environ.copy()
    cmd = [
        str(server),
        "--config",
        str(server_config),
        "--serve",
        "--port",
        "0",
        "--players",
        "2",
        "--seed",
        str(seed),
        "--setup",
        str(setup),
        "--injectable",
        "--cycles",
        "600",
    ]
    if Path("/usr/bin/stdbuf").is_file():
        cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        bufsize=1,
    )
    assert proc.stdout is not None
    port = None
    setup_seen = False
    seed_seen = False
    deadline = time.time() + 5.0
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        line = line.strip()
        if line.startswith("PORT="):
            port = int(line.split("=", 1)[1])
        if line.startswith("SETUP=") and str(setup) in line:
            setup_seen = True
        if line.startswith("SEED=") and line.endswith(f"={seed}"):
            seed_seen = True
        if port is not None and setup_seen and seed_seen:
            break
    if port is None or port <= 0 or not setup_seen or not seed_seen:
        err = proc.stderr.read() if proc.stderr else ""
        proc.kill()
        print(
            f"no PORT/SETUP/SEED from server; stderr={err!r}",
            file=sys.stderr,
        )
        raise RuntimeError("server start failed")
    return proc, port


def write_ai_config(path: Path, port: int) -> None:
    """AI dial config — server assigns the seat on handshake."""
    path.write_text(
        "\n".join(
            [
                "aggression = 0.55",
                "role_stickiness = 0.70",
                "expansion = 0.50",
                "escort = 0.55",
                "agreement_appetite = 0.40",
                "tech_vs_hulls = 0.45",
                "reaction_lag_ticks = 0",
                "reaction_lag_seconds = 0.0",
                "surprise_rate = 0.0",
                "seed = 42",
                "host = 127.0.0.1",
                f"port = {port}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def run_ai_loop(ai: Path, config: Path, cycles: int = 4) -> int:
    proc = subprocess.run(
        [
            str(ai),
            "--config",
            str(config),
            "--serve-loop",
            "--cycles",
            str(cycles),
        ],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        print(
            f"ai exit={proc.returncode} out={proc.stdout!r} "
            f"err={proc.stderr!r}",
            file=sys.stderr,
        )
        return proc.returncode or 1
    if "ok" not in proc.stdout:
        print(f"ai missing ok: {proc.stdout!r}", file=sys.stderr)
        return 1
    if "dial_failed" in proc.stdout:
        print(f"ai dial failed: {proc.stdout!r}", file=sys.stderr)
        return 1
    return 0


def run_human_pull(client: Path, port: int, human_cfg: Path) -> int:
    """Headless human-shaped --pull (no GTK)."""
    proc = subprocess.run(
        [
            str(client),
            "--config",
            str(human_cfg),
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "--pull",
        ],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        print(
            f"pull exit={proc.returncode} out={proc.stdout!r} "
            f"err={proc.stderr!r}",
            file=sys.stderr,
        )
        return proc.returncode or 1
    out = proc.stdout
    if "planets_visible=" not in out:
        print(f"pull missing planets_visible: {out!r}", file=sys.stderr)
        return 1
    if "digest:" not in out:
        print(f"pull missing digest: {out!r}", file=sys.stderr)
        return 1
    return 0


def test_session(
    server: Path,
    ai: Path,
    client: Path,
    setup: Path,
    server_config: Path,
    human_cfg: Path,
    *,
    expected_worlds: int,
) -> int:
    if not setup.is_file():
        print(f"missing setup: {setup}", file=sys.stderr)
        return 2

    proc, port = spawn_server(
        server, setup, server_config, HARNESS_SEED
    )
    try:
        # No human handshake before injectable advance: a handshake
        # at clock 0 ages out when advanceMs(period) hits the
        # server miss window and refreshEndStatus ends the game.
        resp = exchange("127.0.0.1", port, put_policy(0, b"\x01\x02"))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/policy" or body[0] != 1:
            print(f"human policy failed path={path} body={body!r}")
            return 1

        resp = exchange("127.0.0.1", port, get_state(0, 0))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/state":
            print(f"bad state path={path}")
            return 1
        tick0, planets = parse_state_tick_planets(state_payload(body))
        if planets != expected_worlds:
            print(
                f"fixture world_count={expected_worlds} got {planets}"
            )
            return 1

        resp = exchange("127.0.0.1", port, get_digest(0, 0))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/digest":
            print(f"bad digest path={path}")
            return 1
        dig_tick0, _blob_tick0, events0 = parse_digest_body(body)

        with tempfile.TemporaryDirectory() as tmp:
            ai_cfg = Path(tmp) / "ai-harness.cfg"
            write_ai_config(ai_cfg, port)
            rc = run_ai_loop(ai, ai_cfg, cycles=4)
            if rc != 0:
                return rc

        resp = exchange("127.0.0.1", port, admin_advance(3))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/admin/advance" or body[0] != 1:
            print(f"bad advance path={path} body={body!r}")
            return 1
        fired = int.from_bytes(body[1:5], "little")
        if fired < 1:
            print(f"advance fired={fired}")
            return 1

        resp = exchange("127.0.0.1", port, get_state(0, 0))
        _, _verb, path, body = decode_envelope(resp)
        tick1, planets1 = parse_state_tick_planets(state_payload(body))
        if tick1 <= tick0:
            print(f"tick did not advance: {tick0} -> {tick1}")
            return 1
        if planets1 != expected_worlds:
            print(f"planet count drifted: {planets1}")
            return 1

        resp = exchange("127.0.0.1", port, get_digest(0, 0))
        _, _verb, path, body = decode_envelope(resp)
        dig_tick1, _blob_tick1, events1 = parse_digest_body(body)
        if dig_tick1 <= dig_tick0 and events1 <= events0:
            print(
                f"digest did not grow: tick {dig_tick0}->{dig_tick1} "
                f"events {events0}->{events1}"
            )
            return 1

        # Human presence after ticks: empty handshake allocates a
        # free seat (AI may have held / dropped seat 0).
        resp = exchange("127.0.0.1", port, handshake())
        _, _verb, path, body = decode_envelope(resp)
        accepted, _tick, _ended, seat = parse_handshake_ack(body)
        if path != "/handshake" or not accepted or seat > 1:
            print(
                f"human handshake failed path={path} body={body!r} "
                f"seat={seat}"
            )
            return 1

        rc = run_human_pull(client, port, human_cfg)
        if rc != 0:
            return rc
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
    return 0


def test_seed_banner(
    server: Path, setup: Path, server_config: Path
) -> int:
    """Same seed banner must echo for comparable re-runs."""
    proc, _port = spawn_server(
        server, setup, server_config, HARNESS_SEED
    )
    try:
        # spawn_server already required SEED=; second spawn proves
        # restart-with-same-seed path is stable.
        pass
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
    proc2, _port2 = spawn_server(
        server, setup, server_config, HARNESS_SEED
    )
    try:
        return 0
    finally:
        proc2.terminate()
        try:
            proc2.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc2.kill()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--ai", required=True)
    parser.add_argument("--client", required=True)
    parser.add_argument(
        "--server-config",
        required=True,
        help="server --config path (mandatory on the binary)",
    )
    parser.add_argument(
        "--fixture",
        required=True,
        help="scenarios/tuning-small.setup (or other closed fixture)",
    )
    parser.add_argument(
        "--human-config",
        default="",
        help="path to config/human-default.cfg",
    )
    parser.add_argument(
        "--worlds",
        type=int,
        default=12,
        help="expected world_count from the fixture",
    )
    args = parser.parse_args()
    server = Path(args.server)
    ai = Path(args.ai)
    client = Path(args.client)
    server_config = Path(args.server_config)
    fixture = Path(args.fixture)
    human_cfg = Path(args.human_config) if args.human_config else (
        Path(__file__).resolve().parents[2] / "config" / "human-default.cfg"
    )
    for path, label in (
        (server, "server"),
        (ai, "ai"),
        (client, "client"),
        (server_config, "server-config"),
        (human_cfg, "human-config"),
    ):
        if not path.is_file():
            print(f"missing {label}: {path}", file=sys.stderr)
            return 2

    rc = test_seed_banner(server, fixture, server_config)
    if rc != 0:
        return rc
    rc = test_session(
        server,
        ai,
        client,
        fixture,
        server_config,
        human_cfg,
        expected_worlds=args.worlds,
    )
    if rc != 0:
        return rc

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
