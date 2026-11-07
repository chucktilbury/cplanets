#!/usr/bin/env python3
"""CLI + setup verbosity; settings PUT emits when verbose."""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from wire import decode_envelope, put_policy


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


def spawn(
    server: Path,
    extra: list[str],
) -> tuple[subprocess.Popen[str], int, list[str]]:
    env = os.environ.copy()
    cmd = [
        str(server),
        "--serve",
        "--port",
        "0",
        "--players",
        "2",
        "--injectable",
        "--cycles",
        "200",
        *extra,
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
    preamble: list[str] = []
    deadline = time.time() + 5.0
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        stripped = line.strip()
        preamble.append(stripped)
        if stripped.startswith("PORT="):
            port = int(stripped.split("=", 1)[1])
        if port is not None and any(
            item.startswith("VERBOSITY=") for item in preamble
        ):
            break
    if port is None or port <= 0:
        err = proc.stderr.read() if proc.stderr else ""
        proc.kill()
        raise RuntimeError(f"no PORT=; stderr={err!r} out={preamble!r}")
    return proc, port, preamble


def v1_policy_blob() -> bytes:
    # version, trader, expansion, escort, agreement, tech, pad, pad
    return bytes([1, 3, 40, 50, 10, 60, 0, 0])


def test_cli_verbosity(server: Path) -> int:
    proc, port, preamble = spawn(server, ["--verbosity", "1"])
    try:
        if "VERBOSITY=1" not in preamble:
            print(f"missing VERBOSITY=1 in {preamble!r}")
            return 1
        resp = exchange("127.0.0.1", port, put_policy(0, v1_policy_blob()))
        _, verb, path, body = decode_envelope(resp)
        if verb != 2 or path != "/policy" or body[0] != 1:
            print(f"bad policy ack verb={verb} path={path}")
            return 1
        # Drain a few stdout lines for the settings emit.
        assert proc.stdout is not None
        deadline = time.time() + 2.0
        found = False
        while time.time() < deadline:
            line = proc.stdout.readline()
            if not line:
                break
            if "verbosity: settings player=0" in line and "role=trader" in line:
                found = True
                break
        if not found:
            err = proc.stderr.read() if proc.stderr else ""
            print(f"missing settings log line; stderr={err!r}")
            return 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
    return 0


def test_setup_verbosity(server: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        setup = Path(tmp) / "verbose.setup"
        setup.write_text(
            "\n".join(
                [
                    "scenario_mode = closed",
                    "tick_period_seconds = 5",
                    "tick_auto_config_from_ai_lag = false",
                    "world_count = 8",
                    "verbosity = 2",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        proc, port, preamble = spawn(
            server, ["--setup", str(setup)]
        )
        try:
            if "VERBOSITY=2" not in preamble:
                print(f"setup verbosity not applied: {preamble!r}")
                return 1
            # CLI overlay wins when provided.
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()

        proc, port, preamble = spawn(
            server, ["--setup", str(setup), "--verbosity", "0"]
        )
        try:
            if "VERBOSITY=0" not in preamble:
                print(f"CLI overlay failed: {preamble!r}")
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
    args = parser.parse_args()
    server_path = Path(args.server)
    if not server_path.is_file():
        print(f"missing server: {server_path}", file=sys.stderr)
        return 2

    rc = test_cli_verbosity(server_path)
    if rc != 0:
        return rc
    rc = test_setup_verbosity(server_path)
    if rc != 0:
        return rc

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
