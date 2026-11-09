#!/usr/bin/env python3
"""AI serve-loop loop_period_ms config + CLI overlay.

Checks --help advertises --loop-period-ms, file default reaches the
serve-loop banner as LOOP_PERIOD_MS=, and argv overlays the file.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def run_ai(ai: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(ai), *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


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
        stdin=subprocess.PIPE,
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


def write_ai_config(path: Path, port: int, period_ms: int) -> None:
    path.write_text(
        "\n".join(
            [
                "aggression = 0.55",
                "surprise_rate = 0.0",
                "seed = 42",
                "host = 127.0.0.1",
                f"port = {port}",
                "verbosity = 0",
                "cycles = 0",
                "once = false",
                "serve_loop = false",
                f"loop_period_ms = {period_ms}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def read_until_banner(proc: subprocess.Popen[str], timeout: float = 5.0) -> str:
    assert proc.stdout is not None
    chunks: list[str] = []
    deadline = time.time() + timeout
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        chunks.append(line)
        if "MENU_KEY=m" in line:
            break
    return "".join(chunks)


def test_help(ai: Path) -> int:
    proc = run_ai(ai, ["--help"])
    if proc.returncode != 0:
        print(f"--help exit {proc.returncode}: {proc.stderr!r}")
        return 1
    text = proc.stdout + proc.stderr
    if "--loop-period-ms" not in text:
        print(f"--help missing --loop-period-ms: {text!r}")
        return 1
    return 0


def test_file_and_cli_overlay(
    server: Path, ai: Path, server_config: Path
) -> int:
    srv, port = spawn_server(server, server_config)
    try:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "ai-loop.cfg"
            write_ai_config(cfg, port, 250)

            # File value alone (no CLI overlay).
            cmd = [
                str(ai),
                "--config",
                str(cfg),
                "--serve-loop",
                "--cycles",
                "1",
            ]
            if Path("/usr/bin/stdbuf").is_file():
                cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True,
                env=os.environ.copy(),
                bufsize=1,
            )
            out = read_until_banner(proc)
            # Finite cycles exit quickly; wait for completion.
            try:
                rest_out, rest_err = proc.communicate(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
                rest_out, rest_err = proc.communicate(timeout=5)
                print(
                    f"AI timed out under finite serve-loop; "
                    f"banner={out!r} err={rest_err!r}"
                )
                return 1
            banner = out + (rest_out or "")
            if "LOOP_PERIOD_MS=250" not in banner:
                print(
                    f"file loop_period_ms missing from banner: "
                    f"{banner!r} stderr={rest_err!r}"
                )
                return 1
            if proc.returncode != 0:
                print(
                    f"file-period AI exit {proc.returncode}: "
                    f"{rest_err!r}"
                )
                return 1

            # CLI overlays the file value.
            overlay_cmd = [
                str(ai),
                "--config",
                str(cfg),
                "--serve-loop",
                "--cycles",
                "1",
                "--loop-period-ms",
                "50",
            ]
            if Path("/usr/bin/stdbuf").is_file():
                overlay_cmd = [
                    "/usr/bin/stdbuf",
                    "-oL",
                    "-eL",
                    *overlay_cmd,
                ]
            overlay = subprocess.Popen(
                overlay_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True,
                env=os.environ.copy(),
                bufsize=1,
            )
            overlay_banner = read_until_banner(overlay)
            try:
                rest_out, rest_err = overlay.communicate(timeout=15)
            except subprocess.TimeoutExpired:
                overlay.kill()
                rest_out, rest_err = overlay.communicate(timeout=5)
                print(
                    f"overlay AI timed out; banner={overlay_banner!r} "
                    f"err={rest_err!r}"
                )
                return 1
            full = overlay_banner + (rest_out or "")
            if "LOOP_PERIOD_MS=50" not in full:
                print(
                    f"CLI --loop-period-ms overlay failed: "
                    f"{full!r} stderr={rest_err!r}"
                )
                return 1
            if overlay.returncode != 0:
                print(
                    f"overlay AI exit {overlay.returncode}: "
                    f"{rest_err!r}"
                )
                return 1
    finally:
        srv.kill()
        try:
            srv.wait(timeout=5)
        except subprocess.TimeoutExpired:
            srv.kill()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--ai", type=Path, required=True)
    parser.add_argument("--server-config", type=Path, required=True)
    args = parser.parse_args()
    rc = test_help(args.ai)
    if rc != 0:
        return rc
    rc = test_file_and_cli_overlay(
        args.server, args.ai, args.server_config
    )
    if rc != 0:
        return rc
    print("true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
