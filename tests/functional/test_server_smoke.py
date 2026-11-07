#!/usr/bin/env python3
"""Spawn cplanets-server, PUT policy, advance ticks, GET state."""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

from wire import admin_advance, decode_envelope, get_state, put_policy


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, help="cplanets-server path")
    parser.add_argument(
        "--server-config",
        required=True,
        help="server --config path (mandatory on the binary)",
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

    env = os.environ.copy()
    # Line-buffer the server so PORT= is visible before serve() blocks.
    # Without stdbuf, full stdout buffering delays PORT until exit.
    cmd = [
        str(server_path),
        "--config",
        str(server_config),
        "--serve",
        "--port",
        "0",
        "--players",
        "2",
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
    deadline = time.time() + 5.0
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        line = line.strip()
        if line.startswith("PORT="):
            port = int(line.split("=", 1)[1])
            break
    if port is None or port <= 0:
        err = proc.stderr.read() if proc.stderr else ""
        proc.kill()
        print(f"no PORT= from server; stderr={err!r}", file=sys.stderr)
        return 1

    try:
        # PUT policy for seat 0 (anytime; no ready barrier).
        resp = exchange("127.0.0.1", port, put_policy(0, b"\x01\x02"))
        _, verb, path, body = decode_envelope(resp)
        if verb != 2 or path != "/policy" or body[0] != 1:
            print(f"bad policy ack verb={verb} path={path} body={body!r}")
            return 1

        # Admin advance 2 ticks on injectable clock.
        resp = exchange("127.0.0.1", port, admin_advance(2))
        _, verb, path, body = decode_envelope(resp)
        if path != "/admin/advance" or body[0] != 1:
            print(f"bad advance ack path={path} body={body!r}")
            return 1
        fired = int.from_bytes(body[1:5], "little")
        tick = int.from_bytes(body[5:9], "little")
        if fired < 1 or tick < 1:
            print(f"advance did not fire: fired={fired} tick={tick}")
            return 1

        # GET published state.
        resp = exchange("127.0.0.1", port, get_state(0, 0))
        _, verb, path, body = decode_envelope(resp)
        if verb != 1 or path != "/state":
            print(f"bad state path={path}")
            return 1
        state_tick = int.from_bytes(body[0:4], "little")
        if state_tick < 1:
            print(f"state tick not advanced: {state_tick}")
            return 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
