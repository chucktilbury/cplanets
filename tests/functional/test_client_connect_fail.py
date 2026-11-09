#!/usr/bin/env python3
"""Assert --pull fails loud with host:port and exits non-zero.

No server is started: dial must fail. Guards the silent-empty
session regression when sample configs use a real play port.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", required=True)
    args = parser.parse_args()
    client = Path(args.client)
    if not client.is_file():
        print(f"missing client: {client}", file=sys.stderr)
        return 2

    host = "127.0.0.1"
    # High unlikely-bound port; no listener expected.
    port = 65432
    cfg = tempfile.NamedTemporaryFile(
        "w", suffix=".cfg", delete=False, encoding="utf-8"
    )
    try:
        cfg.write(
            f"player_id = 0\nhost = {host}\nport = {port}\n"
            "pull = true\n"
            "gui = false\n"
        )
        cfg.close()
        proc = subprocess.run(
            [str(client), "--config", cfg.name, "--pull"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    finally:
        Path(cfg.name).unlink(missing_ok=True)

    if proc.returncode == 0:
        print(
            f"expected non-zero exit; stdout={proc.stdout!r} "
            f"stderr={proc.stderr!r}",
            file=sys.stderr,
        )
        return 1
    combined = f"{proc.stdout}{proc.stderr}"
    needle = f"cannot connect to {host}:{port}"
    if needle not in combined:
        print(
            f"missing {needle!r} in output: {combined!r}",
            file=sys.stderr,
        )
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
