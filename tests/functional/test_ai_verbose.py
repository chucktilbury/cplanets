#!/usr/bin/env python3
"""CLI + AI config verbosity; --once emits policy when verbose."""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


def run_ai(ai: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(ai), *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def test_help(ai: Path) -> int:
    proc = run_ai(ai, ["--help"])
    if proc.returncode != 0:
        print(f"--help exit {proc.returncode}: {proc.stderr!r}")
        return 1
    text = proc.stdout + proc.stderr
    if "--verbosity" not in text:
        print(f"--help missing --verbosity: {text!r}")
        return 1
    return 0


def test_cli_verbosity(ai: Path, config: Path) -> int:
    proc = run_ai(
        ai,
        ["--config", str(config), "--once", "--verbosity", "1"],
    )
    if proc.returncode != 0:
        print(f"cli once exit {proc.returncode}: {proc.stderr!r}")
        return 1
    out = proc.stdout
    if "VERBOSITY=1" not in out:
        print(f"missing VERBOSITY=1: {out!r}")
        return 1
    if "verbosity: policy" not in out or "via=once" not in out:
        print(f"missing policy decision line: {out!r}")
        return 1
    return 0


def test_quiet_default(ai: Path, config: Path) -> int:
    proc = run_ai(ai, ["--config", str(config), "--once"])
    if proc.returncode != 0:
        print(f"quiet once exit {proc.returncode}: {proc.stderr!r}")
        return 1
    out = proc.stdout
    if "verbosity: policy" in out:
        print(f"quiet should not emit policy line: {out!r}")
        return 1
    if "VERBOSITY=0" not in out:
        print(f"missing VERBOSITY=0: {out!r}")
        return 1
    return 0


def test_config_key_and_overlay(ai: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ai.cfg"
        path.write_text(
            "\n".join(
                [
                    "aggression = 0.55",
                    "surprise_rate = 0.0",
                    "seed = 7",
                    "player_id = 0",
                    "verbosity = 2",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        proc = run_ai(ai, ["--config", str(path), "--once"])
        if proc.returncode != 0:
            print(f"config once exit {proc.returncode}: {proc.stderr!r}")
            return 1
        if "VERBOSITY=2" not in proc.stdout:
            print(f"config verbosity not applied: {proc.stdout!r}")
            return 1
        if "verbosity: policy" not in proc.stdout:
            print(f"config level 2 missing policy: {proc.stdout!r}")
            return 1

        overlay = run_ai(
            ai,
            [
                "--config",
                str(path),
                "--once",
                "--verbosity",
                "0",
            ],
        )
        if overlay.returncode != 0:
            print(
                f"overlay once exit {overlay.returncode}: "
                f"{overlay.stderr!r}"
            )
            return 1
        if "VERBOSITY=0" not in overlay.stdout:
            print(f"CLI overlay failed: {overlay.stdout!r}")
            return 1
        if "verbosity: policy" in overlay.stdout:
            print(f"overlay 0 still noisy: {overlay.stdout!r}")
            return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ai", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args()
    ai = args.ai
    config = args.config
    if not ai.is_file():
        print(f"missing ai binary: {ai}", file=sys.stderr)
        return 1
    if not config.is_file():
        print(f"missing config: {config}", file=sys.stderr)
        return 1

    for name, fn in (
        ("help", lambda: test_help(ai)),
        ("cli", lambda: test_cli_verbosity(ai, config)),
        ("quiet", lambda: test_quiet_default(ai, config)),
        ("config", lambda: test_config_key_and_overlay(ai)),
    ):
        rc = fn()
        if rc != 0:
            print(f"FAIL {name}", file=sys.stderr)
            return rc
        print(f"ok {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
