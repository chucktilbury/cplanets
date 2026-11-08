#!/usr/bin/env python3
"""Spawn 1-human server; pause, dispatch, recall over the wire."""

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
    decode_envelope,
    handshake,
    put_order,
    put_pause,
    put_recall,
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
        "--players",
        "1",
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
        exchange("127.0.0.1", port, handshake())

        resp = exchange("127.0.0.1", port, put_pause(True))
        _, verb, path, body = decode_envelope(resp)
        if path != "/pause" or body[0] != 1:
            print(f"pause on failed path={path} body={body!r}")
            return 1

        # Paused: advance must fire 0.
        resp = exchange("127.0.0.1", port, admin_advance(1))
        _, verb, path, body = decode_envelope(resp)
        fired = int.from_bytes(body[1:5], "little")
        if fired != 0:
            print(f"advance while paused fired={fired}")
            return 1

        resp = exchange("127.0.0.1", port, put_pause(False))
        _, verb, path, body = decode_envelope(resp)
        if path != "/pause" or body[0] != 1:
            print(f"pause off failed path={path} body={body!r}")
            return 1

        # Closed start seats a home scout as fleet id 1 typically.
        resp = exchange(
            "127.0.0.1",
            port,
            put_order(0, 1, 1, "explore"),
        )
        _, verb, path, body = decode_envelope(resp)
        if path != "/order" or body[0] != 1:
            print(f"order failed path={path} body={body!r}")
            return 1

        # Locked rewrite should fail.
        resp = exchange(
            "127.0.0.1",
            port,
            put_order(0, 1, 1, "take"),
        )
        _, verb, path, body = decode_envelope(resp)
        if path != "/order" or body[0] != 0:
            print(f"locked rewrite not rejected path={path} body={body!r}")
            return 1

        resp = exchange("127.0.0.1", port, put_recall(0, 1))
        _, verb, path, body = decode_envelope(resp)
        if path != "/recall" or body[0] != 1:
            print(f"recall failed path={path} body={body!r}")
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
