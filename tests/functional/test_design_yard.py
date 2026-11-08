#!/usr/bin/env python3
"""Spawn 1-human server; design develop + yard build over the wire."""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

from wire import (
    admin_advance,
    admin_go,
    decode_envelope,
    handshake,
    put_build,
    put_design,
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
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
    cmd = [
        str(server_path),
        "--config",
        str(server_config),
        "--serve",
        "--port",
        "0",
        # Two seats so an injectable-clock handshake miss on seat 0
        # does not trip all-humans-quit before the post-advance build
        # (seat 1 stays present/unseated). Home still lands on the
        # seat-0 handshake below.
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
        # Home yard is created on connect (handshake), not at server
        # start. Two-player fixture keeps the game alive if this
        # handshake later ages out during admin_advance.
        resp = exchange("127.0.0.1", port, handshake())
        _, _verb, path, body = decode_envelope(resp)
        if path != "/handshake" or body[0] != 1:
            print(f"handshake failed path={path} body={body!r}")
            return 1
        # First free seat is 0; later verbs use that assigned id.

        # Tiny size keeps develop wealth cost affordable on startWealth.
        resp = exchange(
            "127.0.0.1",
            port,
            put_design(
                0, "gunboat", "1.5", "4.0", "0.5", "0.0", "war"
            ),
        )
        _, _verb, path, body = decode_envelope(resp)
        if path != "/design" or body[0] != 1:
            print(f"design failed path={path} body={body!r}")
            return 1

        # Default scout (id 0) is ready at home yard planet 0.
        resp = exchange("127.0.0.1", port, put_build(0, 0, 0))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/build" or body[0] != 1:
            print(f"build failed path={path} body={body!r}")
            return 1

        # Unready custom design must refuse until develop ticks finish.
        # New design is typically id 2 after scout+colony seed.
        resp = exchange("127.0.0.1", port, put_build(0, 0, 2))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/build" or body[0] != 0:
            print(
                f"unready build not rejected path={path} body={body!r}"
            )
            return 1

        # Leave lobby, then advance past default designDevelopTicks (5).
        resp = exchange("127.0.0.1", port, admin_go())
        _, _verb, path, body = decode_envelope(resp)
        if path != "/admin/go" or body[0] != 1:
            print(f"go failed path={path} body={body!r}")
            return 1

        resp = exchange("127.0.0.1", port, admin_advance(8))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/admin/advance" or body[0] != 1:
            print(f"advance failed path={path} body={body!r}")
            return 1
        fired = int.from_bytes(body[1:5], "little")
        if fired < 1:
            print(f"advance fired={fired}")
            return 1

        # After develop ticks, building the custom design should work.
        resp = exchange("127.0.0.1", port, put_build(0, 0, 2))
        _, _verb, path, body = decode_envelope(resp)
        if path != "/build" or body[0] != 1:
            print(f"ready custom build failed path={path} body={body!r}")
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
