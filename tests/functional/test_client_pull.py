#!/usr/bin/env python3
"""Spawn wall-clock server; assert bin/cplanets --pull sees ticks.

Regression for one-shot TCP: HumanSession must redial per verb
because ServerListen closes after each reply. A reused socket after
handshake used to yield tick=0 / empty lists (solo GUI looked frozen).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--client", required=True)
    parser.add_argument(
        "--server-config",
        required=True,
        help="server --config path (mandatory on the binary)",
    )
    parser.add_argument(
        "--setup",
        default="",
        help="optional scenario --setup path",
    )
    args = parser.parse_args()
    server = Path(args.server)
    client = Path(args.client)
    server_config = Path(args.server_config)
    if not server.is_file() or not client.is_file():
        print(f"missing bins: {server} {client}", file=sys.stderr)
        return 2
    if not server_config.is_file():
        print(f"missing server config: {server_config}", file=sys.stderr)
        return 2

    env = os.environ.copy()
    cmd = [
        str(server),
        "--config",
        str(server_config),
        "--serve",
        "--port",
        "0",
        "--players",
        "1",
        "--seed",
        "77",
    ]
    if args.setup:
        cmd.extend(["--setup", args.setup])
    if Path("/usr/bin/stdbuf").is_file():
        cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]

    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        bufsize=1,
    )
    assert proc.stdout is not None
    assert proc.stdin is not None
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

    cfg = tempfile.NamedTemporaryFile(
        "w", suffix=".cfg", delete=False, encoding="utf-8"
    )
    try:
        # No player_id — TCP seat comes from handshake allocate.
        cfg.write(f"host = 127.0.0.1\nport = {port}\n")
        cfg.close()

        # Leave lobby so wall ticks may fire (operator go).
        proc.stdin.write("g\n")
        proc.stdin.flush()
        # Default tick period is 5s; wait past one period after go.
        time.sleep(5.5)

        pull = subprocess.run(
            [
                str(client),
                "--config",
                cfg.name,
                "--pull",
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if pull.returncode != 0:
            print(pull.stderr, file=sys.stderr)
            return pull.returncode or 1
        out = pull.stdout
        if "pull_failed" in out:
            print(f"pull_failed: {out!r}", file=sys.stderr)
            return 1
        match = re.search(r"tick=(\d+)", out)
        if match is None:
            print(f"missing tick=: {out!r}", file=sys.stderr)
            return 1
        tick = int(match.group(1))
        if tick < 1:
            print(f"tick did not advance: {out!r}", file=sys.stderr)
            return 1
        planets = re.search(r"planets_visible=(\d+)", out)
        if planets is None or int(planets.group(1)) < 1:
            print(f"no visible planets: {out!r}", file=sys.stderr)
            return 1
        fleets = re.search(r"fleets_visible=(\d+)", out)
        if fleets is None or int(fleets.group(1)) < 1:
            print(f"no visible fleets: {out!r}", file=sys.stderr)
            return 1
    finally:
        Path(cfg.name).unlink(missing_ok=True)
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()

    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
