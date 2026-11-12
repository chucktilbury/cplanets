#!/usr/bin/env python3
"""CPL-118: configured ai-client children spawn after a human connects.

Listen/start must not print SPAWN_AI_COUNT. After a human handshake,
the serve loop should launch armed children and print SPAWN_AI_COUNT.
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from wire import (
    decode_envelope,
    handshake,
    parse_handshake_ack,
)


def exchange(host: str, port: int, frame: bytes, timeout: float = 2.0) -> bytes:
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(frame)
        chunks: list[bytes] = []
        while True:
            try:
                data = sock.recv(65536)
            except socket.timeout:
                break
            if not data:
                break
            chunks.append(data)
        return b"".join(chunks)


class BannerTail:
    """Collect server stdout lines in a background thread."""

    def __init__(self, proc: subprocess.Popen[str]) -> None:
        self.lines: list[str] = []
        self._lock = threading.Lock()
        self._done = threading.Event()

        def _reader() -> None:
            assert proc.stdout is not None
            while True:
                line = proc.stdout.readline()
                if not line:
                    break
                with self._lock:
                    self.lines.append(line.rstrip("\n"))
            self._done.set()

        self._thread = threading.Thread(target=_reader, daemon=True)
        self._thread.start()

    def snapshot(self) -> list[str]:
        with self._lock:
            return list(self.lines)

    def wait_for(self, prefix: str, timeout: float) -> str | None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            for line in self.snapshot():
                if line.startswith(prefix):
                    return line
            time.sleep(0.05)
        return None


def write_config(ai_bin: Path, spawn_dir: Path) -> Path:
    path = Path(
        tempfile.mkstemp(prefix="ai-spawn-defer-", suffix=".cfg")[1]
    )
    # Place ai-soft.cfg beside the server config for level resolve.
    soft = spawn_dir / "ai-soft.cfg"
    soft.write_text(
        "\n".join(
            [
                "aggression = 0.25",
                "surprise_rate = 0.0",
                "seed = 42",
                "host = 127.0.0.1",
                "port = 7700",
                "verbosity = 0",
                "cycles = 0",
                "once = false",
                "serve_loop = true",
                "loop_period_ms = 100",
                "",
            ]
        ),
        encoding="utf-8",
    )
    cfg_path = spawn_dir / "server-defer.cfg"
    cfg_path.write_text(
        "\n".join(
            [
                "host = 127.0.0.1",
                "port = 0",
                "players = 0",
                "seed = 7",
                "serve = true",
                "cycles = 0",
                "injectable = true",
                "verbosity = 0",
                "handshake_miss_ms = 60000",
                "accept_poll_ms = 50",
                "scenario_mode = closed",
                "tick_period_seconds = 5",
                "tick_auto_config_from_ai_lag = false",
                'ai-client = "DeferBot", soft',
                f"spawn_ai_dir = {spawn_dir / 'children'}",
                f"spawn_ai_bin = {ai_bin}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    path.unlink(missing_ok=True)
    return cfg_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--ai", required=True)
    parser.add_argument("--server-config", required=True)
    args = parser.parse_args()
    server = Path(args.server)
    ai = Path(args.ai)
    if not server.is_file() or not ai.is_file():
        print(f"missing bins server={server} ai={ai}", file=sys.stderr)
        return 2

    os.chdir(server.parent.parent)
    spawn_dir = Path(tempfile.mkdtemp(prefix="cplanets-ai-defer-"))
    cfg = write_config(ai, spawn_dir)
    proc: subprocess.Popen[str] | None = None
    try:
        cmd = [
            str(server),
            "--config",
            str(cfg),
            "--serve",
            "--port",
            "0",
            "--injectable",
            "--cycles",
            "800",
        ]
        if Path("/usr/bin/stdbuf").is_file():
            cmd = ["/usr/bin/stdbuf", "-oL", "-eL", *cmd]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.PIPE,
            text=True,
            bufsize=1,
            cwd=str(server.parent.parent),
        )
        tail = BannerTail(proc)
        port_line = tail.wait_for("PORT=", 5.0)
        if port_line is None:
            err = proc.stderr.read() if proc.stderr else ""
            raise RuntimeError(f"no PORT=; stderr={err!r}")
        port = int(port_line.split("=", 1)[1])
        if tail.wait_for("PHASE=lobby", 2.0) is None:
            raise RuntimeError("missing PHASE=lobby")

        # Listen must not have spawned yet.
        time.sleep(0.3)
        early = "\n".join(tail.snapshot())
        if "SPAWN_AI_COUNT=" in early:
            raise RuntimeError(
                f"AI spawned at listen before human: {early!r}"
            )

        resp = exchange("127.0.0.1", port, handshake())
        _, _, path, body = decode_envelope(resp)
        accepted, tick0, ended, seat, token = parse_handshake_ack(body)
        if (
            path != "/handshake"
            or not accepted
            or seat != 0
            or tick0 != 0
            or ended
            or len(token) != 16
        ):
            raise RuntimeError(
                f"bad human handshake path={path} body={body!r}"
            )

        spawn_line = tail.wait_for("SPAWN_AI_COUNT=", 5.0)
        if spawn_line is None:
            late = "\n".join(tail.snapshot())
            err = ""
            if proc.stderr is not None:
                # Best-effort; may block if still running — skip.
                err = "(stderr not drained)"
            raise RuntimeError(
                f"no SPAWN_AI_COUNT after human; stdout={late!r} "
                f"{err}"
            )
        count = int(spawn_line.split("=", 1)[1])
        if count != 1:
            raise RuntimeError(f"expected SPAWN_AI_COUNT=1 got {count}")

        print("true")
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        if proc is not None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()


if __name__ == "__main__":
    sys.exit(main())
