#!/usr/bin/env python3
"""File defaults for CLI flags; argv overrides silently."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def run_bin(path: Path, args: list[str], timeout: float = 30.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(path), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def spawn_server(server: Path, extra: list[str]) -> tuple[subprocess.Popen[str], list[str]]:
    env = os.environ.copy()
    cmd = [str(server), *extra]
    if Path("/usr/bin/stdbuf").is_file():
        cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=subprocess.PIPE,
        text=True,
        env=env,
        bufsize=1,
    )
    assert proc.stdout is not None
    preamble: list[str] = []
    deadline = time.time() + 5.0
    port_seen = False
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        stripped = line.strip()
        preamble.append(stripped)
        if stripped.startswith("PORT="):
            port_seen = True
        if port_seen and any(item.startswith("INJECTABLE=") for item in preamble):
            break
    return proc, preamble


def stop(proc: subprocess.Popen[str]) -> None:
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()


def test_server_file_defaults_and_override(server: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        setup = Path(tmp) / "galaxy.setup"
        setup.write_text(
            "\n".join(
                [
                    "scenario_mode = closed",
                    "tick_period_seconds = 5",
                    "tick_auto_config_from_ai_lag = false",
                    "world_count = 8",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        cfg = Path(tmp) / "server.cfg"
        cfg.write_text(
            "\n".join(
                [
                    f"setup = {setup}",
                    "host = 127.0.0.1",
                    "serve = true",
                    "port = 0",
                    "players = 3",
                    "seed = 99",
                    "cycles = 40",
                    "injectable = true",
                    "verbosity = 3",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        # File defaults alone (no --serve / --seed / … on argv).
        proc, preamble = spawn_server(server, ["--config", str(cfg)])
        try:
            joined = "\n".join(preamble)
            for needle in (
                "HOST=127.0.0.1",
                "SEED=99",
                "PLAYERS=3",
                "CYCLES=40",
                "VERBOSITY=3",
                "INJECTABLE=1",
            ):
                if needle not in preamble:
                    print(f"missing {needle} in file-default preamble: {joined!r}")
                    return 1
            if not any(item.startswith("SETUP=") and str(setup) in item for item in preamble):
                print(f"missing SETUP from config: {joined!r}")
                return 1
            port_line = next((item for item in preamble if item.startswith("PORT=")), "")
            try:
                port = int(port_line.split("=", 1)[1])
            except (IndexError, ValueError):
                port = 0
            if port <= 0:
                print(f"bad PORT from file defaults: {joined!r}")
                return 1
        finally:
            stop(proc)

        # CLI silently overrides seed / verbosity / players / setup.
        other_setup = Path(tmp) / "other.setup"
        other_setup.write_text(
            "\n".join(
                [
                    "scenario_mode = closed",
                    "tick_period_seconds = 5",
                    "tick_auto_config_from_ai_lag = false",
                    "world_count = 6",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        proc, preamble = spawn_server(
            server,
            [
                "--config",
                str(cfg),
                "--setup",
                str(other_setup),
                "--seed",
                "11",
                "--verbosity",
                "0",
                "--players",
                "2",
            ],
        )
        try:
            for needle in ("SEED=11", "VERBOSITY=0", "PLAYERS=2", "CYCLES=40"):
                if needle not in preamble:
                    print(f"CLI overlay missing {needle}: {preamble!r}")
                    return 1
            if not any(
                item.startswith("SETUP=") and str(other_setup) in item
                for item in preamble
            ):
                print(f"--setup overlay failed: {preamble!r}")
                return 1
        finally:
            stop(proc)
    return 0


def test_ai_file_defaults_and_override(ai: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ai.cfg"
        path.write_text(
            "\n".join(
                [
                    "aggression = 0.55",
                    "surprise_rate = 0.0",
                    "seed = 7",
                    "player_id = 0",
                    "verbosity = 4",
                    "cycles = 3",
                    "once = true",
                    "serve_loop = false",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        # once=true from file; no --once on argv.
        proc = run_bin(ai, ["--config", str(path)])
        if proc.returncode != 0:
            print(f"ai file-once exit {proc.returncode}: {proc.stderr!r}")
            return 1
        if "VERBOSITY=4" not in proc.stdout:
            print(f"ai file verbosity missing: {proc.stdout!r}")
            return 1
        if "cplanets-ai" not in proc.stdout:
            print(f"ai once summary missing: {proc.stdout!r}")
            return 1

        overlay = run_bin(
            ai,
            ["--config", str(path), "--verbosity", "0"],
        )
        if overlay.returncode != 0:
            print(f"ai overlay exit {overlay.returncode}: {overlay.stderr!r}")
            return 1
        if "VERBOSITY=0" not in overlay.stdout:
            print(f"ai CLI overlay failed: {overlay.stdout!r}")
            return 1
    return 0


def test_human_file_defaults_and_override(
    client: Path, human_default: Path
) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "human.cfg"
        path.write_text(
            "\n".join(
                [
                    "player_id = 1",
                    "host = 127.0.0.1",
                    "port = 0",
                    "once = true",
                    "pull = false",
                    "gui = false",
                    "test = false",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        # once=true from file; no --once on argv.
        proc = run_bin(client, ["--config", str(path)])
        if proc.returncode != 0:
            print(f"human file-once exit {proc.returncode}: {proc.stderr!r}")
            return 1
        if "cplanets" not in proc.stdout:
            print(f"human once summary missing: {proc.stdout!r}")
            return 1
        # Modes false in sample → smoke identity.
        smoke = run_bin(client, ["--config", str(human_default)])
        if smoke.returncode != 0:
            print(f"human smoke exit {smoke.returncode}")
            return 1
        if "cplanets\n" not in smoke.stdout and not smoke.stdout.startswith(
            "cplanets"
        ):
            print(f"human smoke missing name: {smoke.stdout!r}")
            return 1
    return 0


def help_mentions_config(text: str) -> bool:
    return "--config" in text or "config" in text.lower()


def test_missing_config_prints_help(bin_path: Path, label: str) -> int:
    """Bare argv (no --config) must print help and exit 2."""
    missing = run_bin(bin_path, [])
    if missing.returncode != 2:
        print(
            f"{label} missing-config exit {missing.returncode} "
            f"(want 2); out={missing.stdout!r} err={missing.stderr!r}"
        )
        return 1
    combined = missing.stdout + missing.stderr
    if not help_mentions_config(combined):
        print(f"{label} missing-config help missing --config: {combined!r}")
        return 1
    # Explicit -h still exits 0.
    help_proc = run_bin(bin_path, ["-h"])
    if help_proc.returncode != 0:
        print(f"{label} -h exit {help_proc.returncode}")
        return 1
    if not help_mentions_config(help_proc.stdout + help_proc.stderr):
        print(f"{label} -h missing --config text")
        return 1
    return 0


def test_tick_requires_config(tick: Path, tick_config: Path) -> int:
    rc = test_missing_config_prints_help(tick, "tick")
    if rc != 0:
        return rc
    smoke = run_bin(tick, ["--config", str(tick_config)])
    if smoke.returncode != 0:
        print(f"tick smoke exit {smoke.returncode}: {smoke.stderr!r}")
        return 1
    if not smoke.stdout.startswith("cplanets-tick"):
        print(f"tick smoke missing name: {smoke.stdout!r}")
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True, type=Path)
    parser.add_argument("--ai", required=True, type=Path)
    parser.add_argument("--client", required=True, type=Path)
    parser.add_argument("--tick", required=True, type=Path)
    parser.add_argument("--human-config", required=True, type=Path)
    parser.add_argument("--tick-config", required=True, type=Path)
    args = parser.parse_args()
    for label, path in (
        ("server", args.server),
        ("ai", args.ai),
        ("client", args.client),
        ("tick", args.tick),
        ("human-config", args.human_config),
        ("tick-config", args.tick_config),
    ):
        if not path.is_file():
            print(f"missing {label}: {path}", file=sys.stderr)
            return 2

    for name, fn in (
        ("server", lambda: test_server_file_defaults_and_override(args.server)),
        ("ai", lambda: test_ai_file_defaults_and_override(args.ai)),
        (
            "human",
            lambda: test_human_file_defaults_and_override(
                args.client, args.human_config
            ),
        ),
        (
            "missing-config",
            lambda: (
                test_missing_config_prints_help(args.server, "server")
                or test_missing_config_prints_help(args.ai, "ai")
                or test_missing_config_prints_help(args.client, "human")
            ),
        ),
        (
            "tick",
            lambda: test_tick_requires_config(args.tick, args.tick_config),
        ),
    ):
        rc = fn()
        if rc != 0:
            print(f"FAIL {name}", file=sys.stderr)
            return rc
        print(f"ok {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
