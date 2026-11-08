#!/usr/bin/env python3
"""Smoke the read-only status menu opened via stdin m while serving."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_serve_menu(
    server: Path, config: Path, script: str
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            str(server),
            "--config",
            str(config),
            "--serve",
            "--port",
            "0",
            "--players",
            "2",
            "--seed",
            "7",
            "--injectable",
            "--cycles",
            "40",
        ],
        input=script,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    parser.add_argument("--server-config", required=True, type=Path)
    args = parser.parse_args()

    # While serving: open menu with m, walk a few views, quit back to
    # serve (cycles eventually end the process).
    script = "\n".join(
        [
            "m",
            "1",
            "2",
            "1",
            "b",
            "b",
            "3",
            "1",
            "",
            "b",
            "4",
            "1",
            "",
            "b",
            "5",
            "",
            "6",
            "3",
            "b",
            "q",
            "",
        ]
    )
    proc = run_serve_menu(args.server, args.server_config, script)
    out = proc.stdout
    err = proc.stderr
    if proc.returncode != 0:
        sys.stderr.write(
            f"status menu exit {proc.returncode}\nstdout:\n{out}\nstderr:\n{err}\n"
        )
        print("false")
        return 1

    needles = [
        "PORT=",
        "MENU_KEY=m",
        "MENU_OPEN=1",
        "MENU=1",
        "=== CPlanets status (read-only) ===",
        "tick=0",
        "paused=true",
        "Players:",
        "Player id=0",
        "Planets:",
        "Planet id=",
        # Homes/fleets spawn on client connect — empty before seating.
        "Fleets:",
        "fleets=0",
        "Designs:",
        "Build jobs:",
        "Server config (read-only):",
        "Scenario setup (read-only):",
        "status>",
        "MENU_OPEN=0",
        "PAUSE_RESTORED=0",
    ]
    missing = [n for n in needles if n not in out]
    if missing:
        sys.stderr.write(f"missing needles: {missing}\nstdout:\n{out}\n")
        print("false")
        return 1

    print("true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
