#!/usr/bin/env python3
"""Smoke the read-only status menu opened via stdin m while serving."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_serve_menu(
    server: Path, config: Path, script: str, cycles: int = 40
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
            str(cycles),
        ],
        input=script,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def require_needles(out: str, needles: list[str], label: str) -> None:
    missing = [n for n in needles if n not in out]
    if missing:
        raise AssertionError(f"{label} missing needles: {missing}\nstdout:\n{out}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    parser.add_argument("--server-config", required=True, type=Path)
    args = parser.parse_args()

    # While serving: open menu with m, walk a few views, quit back to
    # serve (cycles eventually end the process).
    walk_script = "\n".join(
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
    proc = run_serve_menu(args.server, args.server_config, walk_script)
    out = proc.stdout
    err = proc.stderr
    if proc.returncode != 0:
        sys.stderr.write(
            f"status menu exit {proc.returncode}\nstdout:\n{out}\nstderr:\n{err}\n"
        )
        print("false")
        return 1

    try:
        require_needles(
            out,
            [
                "PORT=",
                "MENU_KEY=m",
                "GO_KEY=g",
                "PHASE=lobby",
                "MENU_OPEN=1",
                "MENU=1",
                "=== CPlanets status (read-only) ===",
                "phase=lobby",
                "tick=0",
                "paused=true",
                # Grow-on-connect: no seats until a client handshakes.
                "seated=0",
                "softMax=2",
                "Players:",
                "Planets:",
                "Planet id=",
                # Homes/fleets spawn on client connect — empty before seating.
                "Fleets:",
                "fleets=0",
                "Designs:",
                "Build jobs:",
                "Server config (read-only):",
                "players=2 (soft max; 0=unlimited)",
                "Scenario setup (read-only):",
                "status>",
                "MENU_OPEN=0",
                "PAUSE_RESTORED=0",
            ],
            "walk",
        )
    except AssertionError as exc:
        sys.stderr.write(f"{exc}\n")
        print("false")
        return 1

    # Lobby menu Go must leave lobby, close the menu, and restore pause
    # (not stay in a non-lobby menu while clients remain held).
    go_script = "\n".join(["m", "g", ""])
    go_proc = run_serve_menu(
        args.server, args.server_config, go_script, cycles=20
    )
    if go_proc.returncode != 0:
        sys.stderr.write(
            f"menu go exit {go_proc.returncode}\n"
            f"stdout:\n{go_proc.stdout}\nstderr:\n{go_proc.stderr}\n"
        )
        print("false")
        return 1
    go_out = go_proc.stdout
    try:
        require_needles(
            go_out,
            [
                "MENU_OPEN=1",
                "GO=1 PHASE=running (leaving menu; ticks may advance)",
                "MENU_OPEN=0",
                "PHASE=running",
                "PAUSE_RESTORED=0",
            ],
            "menu-go",
        )
    except AssertionError as exc:
        sys.stderr.write(f"{exc}\n")
        print("false")
        return 1
    # After Go the top menu must not keep offering a non-lobby explore
    # loop (no second status> prompt after GO=1).
    go_idx = go_out.find("GO=1 PHASE=running (leaving menu; ticks may advance)")
    if go_idx < 0 or "status>" in go_out[go_idx:]:
        sys.stderr.write(
            "menu go left a status> prompt after GO=1 "
            "(menu should have closed)\n"
            f"stdout:\n{go_out}\n"
        )
        print("false")
        return 1

    # Stray / blank lines must be flushed so a later m still opens.
    flush_script = "\n".join(["x", "", " ", "m", "q", ""])
    flush_proc = run_serve_menu(
        args.server, args.server_config, flush_script, cycles=30
    )
    if flush_proc.returncode != 0:
        sys.stderr.write(
            f"stdin flush exit {flush_proc.returncode}\n"
            f"stdout:\n{flush_proc.stdout}\nstderr:\n{flush_proc.stderr}\n"
        )
        print("false")
        return 1
    flush_out = flush_proc.stdout
    try:
        require_needles(
            flush_out,
            [
                "serve> unknown console line",
                "MENU_OPEN=1",
                "MENU=1",
                "MENU_OPEN=0",
                "PAUSE_RESTORED=0",
            ],
            "stdin-flush",
        )
    except AssertionError as exc:
        sys.stderr.write(f"{exc}\n")
        print("false")
        return 1

    print("true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
