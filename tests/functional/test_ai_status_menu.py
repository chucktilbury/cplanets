#!/usr/bin/env python3
"""Smoke the AI status menu opened via stdin m during serve-loop."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def spawn_server(
    server: Path, server_config: Path
) -> tuple[subprocess.Popen[str], int]:
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
        "7",
        "--injectable",
        "--cycles",
        "200",
    ]
    if Path("/usr/bin/stdbuf").is_file():
        cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=os.environ.copy(),
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
        raise RuntimeError(f"no PORT from server; stderr={err!r}")
    return proc, port


def write_ai_config(path: Path, port: int) -> None:
    path.write_text(
        "\n".join(
            [
                "aggression = 0.55",
                "surprise_rate = 0.0",
                "seed = 42",
                "host = 127.0.0.1",
                f"port = {port}",
                "verbosity = 0",
                "cycles = 40",
                "serve_loop = true",
                "",
            ]
        ),
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    parser.add_argument("--ai", required=True, type=Path)
    parser.add_argument("--server-config", required=True, type=Path)
    args = parser.parse_args()

    server_proc = None
    try:
        server_proc, port = spawn_server(args.server, args.server_config)
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "ai.cfg"
            write_ai_config(cfg, port)
            # Open menu with m, walk a few views, quit back to loop.
            script = "\n".join(
                [
                    "m",
                    "1",
                    "2",
                    "",
                    "3",
                    "",
                    "4",
                    "1",
                    "",
                    "b",
                    "5",
                    "1",
                    "",
                    "b",
                    "6",
                    "",
                    "7",
                    "",
                    "8",
                    "",
                    "q",
                    "",
                ]
            )
            ai_proc = subprocess.run(
                [
                    str(args.ai),
                    "--config",
                    str(cfg),
                    "--serve-loop",
                    "--cycles",
                    "40",
                ],
                input=script,
                capture_output=True,
                text=True,
                timeout=45,
                check=False,
            )
            out = ai_proc.stdout
            err = ai_proc.stderr
            if ai_proc.returncode != 0:
                sys.stderr.write(
                    f"ai status menu exit {ai_proc.returncode}\n"
                    f"stdout:\n{out}\nstderr:\n{err}\n"
                )
                print("false")
                return 1

            needles = [
                "MENU_KEY=m",
                "MENU_OPEN=1",
                "MENU=1",
                "=== CPlanets AI status (read-only) ===",
                "seat=0",
                "paused=true",
                "ai-status>",
                "Seat id=0",
                "Snapshot",
                "Planets (client-visible):",
                "Fleets (client-visible):",
                "Designs (from last snapshot):",
                "AI config (read-only):",
                "lastPolicy",
                "MENU_OPEN=0",
                "ok",
            ]
            missing = [n for n in needles if n not in out]
            if missing:
                sys.stderr.write(
                    f"missing needles: {missing}\nstdout:\n{out}\n"
                )
                print("false")
                return 1
    except Exception as exc:  # noqa: BLE001 — surface smoke failures
        sys.stderr.write(f"ai status menu smoke failed: {exc}\n")
        print("false")
        return 1
    finally:
        if server_proc is not None:
            server_proc.kill()
            try:
                server_proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass

    print("true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
