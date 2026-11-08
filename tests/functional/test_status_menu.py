#!/usr/bin/env python3
"""Smoke the read-only cplanets-server --menu paths via stdin."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_menu(server: Path, config: Path, script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(server), "--config", str(config), "--menu", "--players", "2", "--seed", "7"],
        input=script,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    parser.add_argument("--server-config", required=True, type=Path)
    args = parser.parse_args()

    # Walk: status summary → players → seat 1 detail → back →
    # planets → first detail → fleets → first detail →
    # designs → config both → quit.
    script = "\n".join(
        [
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
    proc = run_menu(args.server, args.server_config, script)
    out = proc.stdout
    err = proc.stderr
    if proc.returncode != 0:
        sys.stderr.write(
            f"status menu exit {proc.returncode}\nstdout:\n{out}\nstderr:\n{err}\n"
        )
        print("false")
        return 1

    needles = [
        "MENU=1",
        "=== CPlanets status (read-only) ===",
        "tick=0",
        "Players:",
        "Player id=0",
        "Planets:",
        "Planet id=",
        "Fleets:",
        "Fleet id=",
        "Designs:",
        "Build jobs:",
        "Server config (read-only):",
        "Scenario setup (read-only):",
        "status>",
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
