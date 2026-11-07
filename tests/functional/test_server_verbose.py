#!/usr/bin/env python3
"""CLI + server-config verbosity; settings PUT emits when verbose."""

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
    server_config: Path,
    extra: list[str],
) -> tuple[subprocess.Popen[str], int, list[str]]:
    env = os.environ.copy()
    # Callers that supply their own --config in extra skip the default.
    has_config = any(
        item == "--config" or item.startswith("--config=")
        for item in extra
    )
    cmd = [str(server)]
    if not has_config:
        cmd.extend(["--config", str(server_config)])
    cmd.extend(
        [
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
    )
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


def test_cli_verbosity(server: Path, server_config: Path) -> int:
    proc, port, preamble = spawn(
        server, server_config, ["--verbosity", "3"]
    )
    try:
        if "VERBOSITY=3" not in preamble:
            print(f"missing VERBOSITY=3 in {preamble!r}")
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


def test_config_verbosity(server: Path, server_config: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        cfg = Path(tmp) / "verbose.cfg"
        cfg.write_text(
            "\n".join(
                [
                    "serve = true",
                    "host = 127.0.0.1",
                    "port = 0",
                    "players = 2",
                    "cycles = 200",
                    "injectable = true",
                    "verbosity = 6",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        # File verbosity alone (spawn still passes --serve etc.;
        # --verbosity omitted so config key wins).
        env = os.environ.copy()
        cmd = [str(server), "--config", str(cfg)]
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
        preamble: list[str] = []
        deadline = time.time() + 5.0
        while time.time() < deadline:
            line = proc.stdout.readline()
            if not line:
                break
            stripped = line.strip()
            preamble.append(stripped)
            if stripped.startswith("VERBOSITY="):
                break
        try:
            if "VERBOSITY=6" not in preamble:
                print(f"config verbosity not applied: {preamble!r}")
                return 1
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()

        proc, _port, preamble = spawn(
            server,
            server_config,
            ["--config", str(cfg), "--verbosity", "0"],
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

        # Out-of-range CLI clamps into 0..10.
        proc, _port, preamble = spawn(
            server, server_config, ["--verbosity", "99"]
        )
        try:
            if "VERBOSITY=10" not in preamble:
                print(f"CLI clamp failed: {preamble!r}")
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
    args = parser.parse_args()
    server_path = Path(args.server)
    server_config = Path(args.server_config)
    if not server_path.is_file():
        print(f"missing server: {server_path}", file=sys.stderr)
        return 2
    if not server_config.is_file():
        print(f"missing server config: {server_config}", file=sys.stderr)
        return 2

    rc = test_cli_verbosity(server_path, server_config)
    if rc != 0:
        return rc
    rc = test_config_verbosity(server_path, server_config)
    if rc != 0:
        return rc

    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
