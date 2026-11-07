#!/usr/bin/env python3
"""Headless --once smoke for the human list client (no display)."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", required=True, help="cplanets path")
    parser.add_argument(
        "--client-config",
        required=True,
        help="human --config path (mandatory on the binary)",
    )
    args = parser.parse_args()
    client = Path(args.client)
    client_config = Path(args.client_config)
    if not client.is_file():
        print(f"missing client: {client}", file=sys.stderr)
        return 2
    if not client_config.is_file():
        print(f"missing client config: {client_config}", file=sys.stderr)
        return 2
    proc = subprocess.run(
        [str(client), "--config", str(client_config), "--once"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if proc.returncode != 0:
        print(proc.stderr, file=sys.stderr)
        return proc.returncode or 1
    out = proc.stdout
    if "cplanets" not in out:
        print(f"missing banner: {out!r}", file=sys.stderr)
        return 1
    if "planets_visible=" not in out:
        print(f"missing planet count: {out!r}", file=sys.stderr)
        return 1
    if "digest:" not in out:
        print(f"missing digest: {out!r}", file=sys.stderr)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
