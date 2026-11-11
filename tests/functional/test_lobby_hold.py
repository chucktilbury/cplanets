#!/usr/bin/env python3
"""Live serve-loop lobby hold: connect must not start the clock.

#65's unit_lobbyHoldGhosts called GameDriver.maybeTick directly and
passed while the live path still accepted explore/build on connect
(AI serve-loop) and published paused=false. This harness drives the
real cplanets-server accept/maybeTick loop over TCP.
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
    admin_go,
    decode_envelope,
    encode_envelope,
    get_state,
    handshake,
    parse_handshake_ack,
    put_assign,
    put_build,
    put_fleet,
    put_order,
)


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


def start_server(
    server: Path, config: Path, extra: list[str]
) -> tuple[subprocess.Popen[str], int, str]:
    cmd = [
        str(server),
        "--config",
        str(config),
        "--serve",
        "--port",
        "0",
        *extra,
    ]
    if Path("/usr/bin/stdbuf").is_file():
        cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=subprocess.PIPE,
        text=True,
        bufsize=1,
        cwd=str(server.parent.parent),
    )
    assert proc.stdout is not None
    port: int | None = None
    phase = ""
    deadline = time.time() + 5.0
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        line = line.strip()
        if line.startswith("PORT="):
            port = int(line.split("=", 1)[1])
        if line.startswith("PHASE="):
            phase = line.split("=", 1)[1]
        if port is not None and phase and "Lobby:" in line:
            break
    if port is None or port <= 0:
        err = proc.stderr.read() if proc.stderr else ""
        proc.kill()
        raise RuntimeError(f"no PORT= from server; stderr={err!r}")
    return proc, port, phase


def write_config(extra_lines: list[str] | None = None) -> Path:
    path = Path(
        tempfile.mkstemp(prefix="lobby-hold-", suffix=".cfg")[1]
    )
    lines = [
        "host = 127.0.0.1",
        "port = 0",
        "players = 0",
        "seed = 7",
        "serve = true",
        "cycles = 0",
        "injectable = true",
        "verbosity = 0",
        "handshake_miss_ms = 60000",
        "accept_poll_ms = 50",
        "scenario_mode = closed",
        "tick_period_seconds = 5",
        "tick_auto_config_from_ai_lag = false",
    ]
    if extra_lines:
        lines.extend(extra_lines)
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def state_tick(port: int, seat: int) -> int:
    resp = exchange("127.0.0.1", port, get_state(seat, 0))
    _, _, path, body = decode_envelope(resp)
    if path != "/state" or len(body) < 4:
        raise RuntimeError(f"bad state path={path} body={body!r}")
    return int.from_bytes(body[0:4], "little")


def state_paused(port: int, seat: int) -> bool:
    """Decode chrome paused from GET /state (after LIST/CHROME markers)."""
    resp = exchange("127.0.0.1", port, get_state(seat, 0))
    _, _, path, body = decode_envelope(resp)
    if path != "/state":
        raise RuntimeError(f"bad state path={path}")
    # CHROME_MARKER = 1129465393 ('CHRM' layout in publish.cw)
    marker = (1129465393).to_bytes(4, "little")
    idx = body.find(marker)
    if idx < 0 or idx + 5 > len(body):
        raise RuntimeError("chrome marker missing from state blob")
    return body[idx + 4] == 1


def run_case(
    server: Path, extra_lines: list[str] | None, label: str
) -> None:
    cfg = write_config(extra_lines)
    proc: subprocess.Popen[str] | None = None
    try:
        proc, port, phase = start_server(
            server, cfg, ["--injectable", "--cycles", "800"]
        )
        if phase != "lobby":
            raise RuntimeError(f"{label}: banner PHASE={phase!r}")

        # AI kind=1 allocate (live serve starts empty).
        resp = exchange(
            "127.0.0.1", port, encode_envelope(2, "/handshake", b"\x01")
        )
        _, _, path, body = decode_envelope(resp)
        accepted, tick0, ended, seat, token = parse_handshake_ack(body)
        if (
            path != "/handshake"
            or not accepted
            or seat != 0
            or tick0 != 0
            or ended
            or len(token) != 16
        ):
            raise RuntimeError(
                f"{label}: bad handshake path={path} body={body!r}"
            )

        # Second human seat may still attach in lobby.
        resp = exchange("127.0.0.1", port, handshake())
        _, _, path, body = decode_envelope(resp)
        accepted, tick1, ended, seat1, token1 = parse_handshake_ack(body)
        if (
            path != "/handshake"
            or not accepted
            or seat1 != 1
            or tick1 != 0
            or len(token1) != 16
        ):
            raise RuntimeError(
                f"{label}: bad second handshake path={path} body={body!r}"
            )

        if state_tick(port, 0) != 0:
            raise RuntimeError(f"{label}: tick advanced on connect")
        if not state_paused(port, 0):
            raise RuntimeError(
                f"{label}: published paused=false in lobby after connect"
            )

        # Serve loop must reject play verbs before operator go.
        resp = exchange(
            "127.0.0.1", port, put_order(0, 1, 1, "explore")
        )
        _, _, path, body = decode_envelope(resp)
        if path != "/order" or body[0] != 0:
            raise RuntimeError(
                f"{label}: lobby order accepted path={path} body={body!r}"
            )
        resp = exchange("127.0.0.1", port, put_build(0, 0, 0))
        _, _, path, body = decode_envelope(resp)
        if path != "/build" or body[0] != 0:
            raise RuntimeError(
                f"{label}: lobby build accepted path={path} body={body!r}"
            )

        # Let the accept/maybeTick loop spin (injectable still blocked).
        time.sleep(0.4)
        if state_tick(port, 0) != 0:
            raise RuntimeError(
                f"{label}: tick advanced during serve-loop spin"
            )

        resp = exchange("127.0.0.1", port, admin_go())
        _, _, path, body = decode_envelope(resp)
        if path != "/admin/go" or body[0] != 1:
            raise RuntimeError(
                f"{label}: go failed path={path} body={body!r}"
            )
        if state_paused(port, 0):
            raise RuntimeError(
                f"{label}: still published paused after go"
            )

        # CPL-111: create+assign from home stock before dispatch.
        resp = exchange(
            "127.0.0.1", port, put_fleet(0, 0, "lobby-scout")
        )
        _, _, path, body = decode_envelope(resp)
        if path != "/fleet" or body[0] != 1:
            raise RuntimeError(
                f"{label}: fleet create after go failed path={path} "
                f"body={body!r}"
            )
        resp = exchange(
            "127.0.0.1", port, put_assign(0, 1, "scout", 1)
        )
        _, _, path, body = decode_envelope(resp)
        if path != "/assign" or body[0] != 1:
            raise RuntimeError(
                f"{label}: assign after go failed path={path} "
                f"body={body!r}"
            )
        resp = exchange(
            "127.0.0.1", port, put_order(0, 1, 1, "explore")
        )
        _, _, path, body = decode_envelope(resp)
        if path != "/order" or body[0] != 1:
            raise RuntimeError(
                f"{label}: order after go rejected path={path} "
                f"body={body!r}"
            )
    finally:
        if proc is not None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        cfg.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--server-config", required=True)
    parser.add_argument(
        "--fixture",
        default="",
        help="unused (compat); both cases use unified server config",
    )
    args = parser.parse_args()
    server = Path(args.server)
    if not server.is_file():
        print(f"missing server: {server}", file=sys.stderr)
        return 2

    # Drive from repo root (operator-like cwd).
    os.chdir(server.parent.parent)

    try:
        # Ctor §14 defaults only (no extra scenario overlays).
        run_case(server, None, "defaults-scenario")
        # Explicit overlays (former closed-default magnitudes).
        run_case(
            server,
            [
                "world_count = 24",
                "useful_mix = 0.35",
                "scout_range = 3.0",
                "galaxy_radius = 20.0",
                "start_wealth = 1000.0",
            ],
            "with-scenario-overlays",
        )
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
