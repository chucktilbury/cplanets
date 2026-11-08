#!/usr/bin/env python3
"""Load scenario by --setup path; assert knobs; reject unknown keys.

TUNING-PLAYABLE A4: edit knob → restart → advance N → stock delta.
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

from wire import admin_advance, decode_envelope, get_state, handshake

LIST_MARKER = 1196445777


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


def parse_state_blob(blob: bytes) -> tuple[int, int, int]:
    """Return (tick, seat0_wealth_milli, planet_count) from publish blob."""
    off = 0
    tick = u32(blob, off)
    off += 4
    # ended u8, winner u32
    off += 1
    off += 4
    player_count = u32(blob, off)
    off += 4
    wealth0 = 0
    for i in range(player_count):
        _pid = u32(blob, off)
        off += 4
        milli = u32(blob, off)
        off += 4
        off += 3  # quit, drop, human
        if i == 0:
            wealth0 = milli
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
    return tick, wealth0, planet_count


def state_payload(body: bytes) -> bytes:
    """Strip GET /state response wrapper to the publish blob."""
    blob_len = u32(body, 4)
    return body[8 : 8 + blob_len]


def spawn_server(
    server: Path,
    setup: Path,
    server_config: Path,
    seed: int = 42,
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
        "400",
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
        if port is not None and setup_seen:
            break
    if port is None or port <= 0 or not setup_seen:
        err = proc.stderr.read() if proc.stderr else ""
        out = ""
        proc.kill()
        print(
            f"no PORT/SETUP from server; stderr={err!r} leftover={out!r}",
            file=sys.stderr,
        )
        raise RuntimeError("server start failed")
    return proc, port


def write_setup(
    path: Path,
    *,
    world_count: int,
    start_wealth: float,
    cover_factor: float,
) -> None:
    path.write_text(
        "\n".join(
            [
                "scenario_mode = closed",
                "tick_period_seconds = 5",
                "tick_auto_config_from_ai_lag = false",
                f"world_count = {world_count}",
                "useful_mix = 0.35",
                "scout_range = 3.0",
                "galaxy_radius = 20.0",
                f"start_wealth = {start_wealth}",
                "start_resources = 500.0",
                "start_tech = 1.0",
                "start_power = 1.0",
                "start_experience = 0.0",
                f"cover_factor = {cover_factor}",
                "productive_inherent_defense = 1.0",
                "livability_internal_min = 0.0",
                "livability_internal_max = 100.0",
                "livability_display_min = 1",
                "livability_display_max = 10",
                "",
            ]
        ),
        encoding="utf-8",
    )


def test_knob_path(server: Path, server_config: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        setup = Path(tmp) / "tuning.setup"
        world_count = 10
        start_wealth = 2500.0
        write_setup(
            setup,
            world_count=world_count,
            start_wealth=start_wealth,
            cover_factor=2.0,
        )
        proc, port = spawn_server(server, setup, server_config, seed=99)
        try:
            # Homes spawn on connect — seat 0 before production ticks.
            resp = exchange("127.0.0.1", port, handshake())
            _, verb, path, body = decode_envelope(resp)
            if path != "/handshake" or body[0] != 1:
                print(f"handshake failed path={path} body={body!r}")
                return 1

            resp = exchange("127.0.0.1", port, get_state(0, 0))
            _, verb, path, body = decode_envelope(resp)
            if verb != 1 or path != "/state":
                print(f"bad state path={path}")
                return 1
            blob = state_payload(body)
            tick, wealth0, planets = parse_state_blob(blob)
            # Cadence may already have fired once before the first
            # GET (first fire is due immediately). Knobs must still
            # show: world_count and start_wealth floor.
            if planets != world_count:
                print(f"world_count not applied: planets={planets}")
                return 1
            expected_milli = int(start_wealth * 1000.0)
            if wealth0 < expected_milli:
                print(
                    f"start_wealth not applied: milli={wealth0} "
                    f"expected>={expected_milli}"
                )
                return 1

            # Keep seat 0 present across injectable advances so AFK
            # drop does not end the live game before stock deltas.
            resp = exchange("127.0.0.1", port, handshake(0))
            _, verb, path, body = decode_envelope(resp)
            if path != "/handshake" or body[0] != 1:
                print(f"re-handshake failed path={path} body={body!r}")
                return 1

            resp = exchange("127.0.0.1", port, admin_advance(3))
            _, verb, path, body = decode_envelope(resp)
            if path != "/admin/advance" or body[0] != 1:
                print(f"bad advance ack path={path} body={body!r}")
                return 1

            resp = exchange("127.0.0.1", port, get_state(0, 0))
            _, verb, path, body = decode_envelope(resp)
            blob = state_payload(body)
            tick2, wealth2, planets2 = parse_state_blob(blob)
            if tick2 <= tick:
                print(f"tick did not advance: before={tick} after={tick2}")
                return 1
            if planets2 != world_count:
                print(f"planet count drifted: {planets2}")
                return 1
            if wealth2 <= wealth0:
                print(
                    f"cover_factor stock delta missing: "
                    f"before={wealth0} after={wealth2}"
                )
                return 1
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
    return 0


def test_unknown_key(server: Path, server_config: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        setup = Path(tmp) / "bad.setup"
        setup.write_text(
            "scenario_mode = closed\nnot_a_real_knob = 1\n",
            encoding="utf-8",
        )
        env = os.environ.copy()
        cmd = [
            str(server),
            "--config",
            str(server_config),
            "--serve",
            "--port",
            "0",
            "--setup",
            str(setup),
            "--injectable",
            "--cycles",
            "10",
        ]
        if Path("/usr/bin/stdbuf").is_file():
            cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
        )
        try:
            out, err = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            print("unknown-key server did not exit", file=sys.stderr)
            return 1
        if proc.returncode == 0:
            print(f"expected non-zero exit; out={out!r} err={err!r}")
            return 1
        combined = (out or "") + (err or "")
        if "unknown setup key" not in combined:
            print(f"missing unknown-key message: {combined!r}")
            return 1
    return 0


def test_repo_fixture(
    server: Path, server_config: Path, fixture: Path
) -> int:
    if not fixture.is_file():
        print(f"missing fixture: {fixture}", file=sys.stderr)
        return 2
    proc, port = spawn_server(server, fixture, server_config, seed=7)
    try:
        resp = exchange("127.0.0.1", port, get_state(0, 0))
        _, verb, path, body = decode_envelope(resp)
        if verb != 1 or path != "/state":
            print(f"fixture state bad path={path}")
            return 1
        blob = state_payload(body)
        _tick, wealth0, planets = parse_state_blob(blob)
        if planets != 24:
            print(f"closed-default world_count expected 24 got {planets}")
            return 1
        # start_wealth 1000.0; may already include one production tick.
        if wealth0 < 1000000:
            print(f"closed-default start_wealth milli={wealth0}")
            return 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument(
        "--server-config",
        required=True,
        help="server --config path (mandatory on the binary)",
    )
    parser.add_argument(
        "--fixture",
        default="",
        help="optional path to scenarios/closed-default.setup",
    )
    args = parser.parse_args()
    server_path = Path(args.server)
    server_config = Path(args.server_config)
    if not server_path.is_file():
        print(f"missing server: {server_path}", file=sys.stderr)
        return 2
    if not server_config.is_file():
        print(f"missing server config: {server_config}", file=sys.stderr)
        return 2

    rc = test_knob_path(server_path, server_config)
    if rc != 0:
        return rc
    rc = test_unknown_key(server_path, server_config)
    if rc != 0:
        return rc
    if args.fixture:
        rc = test_repo_fixture(
            server_path, server_config, Path(args.fixture)
        )
        if rc != 0:
            return rc

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
