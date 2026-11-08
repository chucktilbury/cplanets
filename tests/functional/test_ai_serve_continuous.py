#!/usr/bin/env python3
"""CLI --serve-loop without --cycles must be continuous (CYCLES=0).

Stale/sample configs may still say cycles = 1; operator
`cplanets-ai --config … --serve-loop` must not one-shot.
"""

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
    # Deliberate footgun: cycles = 1 like pre-fix sample configs.
    path.write_text(
        "\n".join(
            [
                "aggression = 0.85",
                "surprise_rate = 0.0",
                "seed = 42",
                "player_id = 1",
                "host = 127.0.0.1",
                f"port = {port}",
                "verbosity = 0",
                "cycles = 1",
                "once = false",
                "serve_loop = false",
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
            # One more line may follow (continuous hint / status).
            extra_deadline = time.time() + 0.5
            while time.time() < extra_deadline:
                # Non-blocking-ish: short poll via timeout on select not
                # available portably; read with a tiny wait by checking
                # poll and a short sleep when no line yet.
                if proc.poll() is not None:
                    break
                # Try one more readline with remaining time via overall.
                break
            break
    return "".join(chunks)


def test_cli_serve_loop_ignores_file_cycles_one(
    server: Path, ai: Path, server_config: Path
) -> None:
    srv, port = spawn_server(server, server_config)
    try:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "ai-hard-like.cfg"
            write_ai_config(cfg, port)
            cmd = [
                str(ai),
                "--config",
                str(cfg),
                "--verbosity",
                "10",
                "--serve-loop",
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
            try:
                out = read_until_banner(proc)
                if "CYCLES=0" not in out:
                    raise AssertionError(
                        f"expected CYCLES=0 for CLI --serve-loop; got:\n{out}"
                    )
                if "CYCLES=1" in out:
                    raise AssertionError(
                        f"stale config cycles=1 leaked into banner:\n{out}"
                    )
                # Must still be connected after more than one cycle beat.
                time.sleep(1.2)
                if proc.poll() is not None:
                    rest = ""
                    if proc.stdout is not None:
                        rest = proc.stdout.read()
                    raise AssertionError(
                        "AI exited early under continuous --serve-loop; "
                        f"banner+rest:\n{out}{rest}"
                    )
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
    finally:
        srv.terminate()
        try:
            srv.wait(timeout=2)
        except subprocess.TimeoutExpired:
            srv.kill()


def test_explicit_cycles_still_finite(
    server: Path, ai: Path, server_config: Path
) -> None:
    srv, port = spawn_server(server, server_config)
    try:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "ai.cfg"
            write_ai_config(cfg, port)
            result = subprocess.run(
                [
                    str(ai),
                    "--config",
                    str(cfg),
                    "--serve-loop",
                    "--cycles",
                    "2",
                ],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            if result.returncode != 0:
                raise AssertionError(
                    f"finite serve-loop exit {result.returncode}: "
                    f"{result.stderr!r}"
                )
            if "CYCLES=2" not in result.stdout:
                raise AssertionError(
                    f"expected CYCLES=2; got:\n{result.stdout}"
                )
            if "CYCLES_DONE=2" not in result.stdout:
                raise AssertionError(
                    f"expected CYCLES_DONE=2; got:\n{result.stdout}"
                )
            if not result.stdout.rstrip().endswith("ok"):
                raise AssertionError(
                    f"expected trailing ok; got:\n{result.stdout}"
                )
    finally:
        srv.terminate()
        try:
            srv.wait(timeout=2)
        except subprocess.TimeoutExpired:
            srv.kill()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--ai", type=Path, required=True)
    parser.add_argument("--server-config", type=Path, required=True)
    args = parser.parse_args()
    try:
        test_cli_serve_loop_ignores_file_cycles_one(
            args.server, args.ai, args.server_config
        )
        test_explicit_cycles_still_finite(
            args.server, args.ai, args.server_config
        )
    except Exception as exc:  # noqa: BLE001 — surface smoke failures
        sys.stderr.write(f"ai serve continuous failed: {exc}\n")
        return 1
    sys.stdout.write("true\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
