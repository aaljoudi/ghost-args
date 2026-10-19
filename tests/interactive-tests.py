#!/usr/bin/env python3
# Copyright (c) 2026 Abdulrahman Aljoudi (aaljoudi)
# SPDX-License-Identifier: MIT
"""Exercise real ZLE rendering in a disposable pseudo-terminal."""
import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="ghost-args-pty-") as home:
    environment = os.environ.copy()
    for key in ("GHOST_ARGS_INSTALL_DIR", "GHOST_ARGS_ZSHRC"):
        environment.pop(key, None)
    environment.update(HOME=home, ZDOTDIR=home, XDG_DATA_HOME=home + "/data", TERM="xterm-256color")
    subprocess.run(["sh", str(root / "install.sh")], env=environment, check=True, capture_output=True)
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe("zsh", ["zsh", "-d"], environment)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 240, 0, 0))

    def send(text):
        os.write(fd, text.encode())

    def until(fragment, timeout=8):
        output = b""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if select.select([fd], [], [], 0.1)[0]:
                try:
                    data = os.read(fd, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                output += data
                if fragment.encode() in re.sub(rb"\x1b\[[0-?]*[ -/]*[@-~]", b"", output):
                    return output
        raise AssertionError(f"Missing {fragment!r} in terminal output: {output!r}")

    try:
        # Shell quoting without interpolating executable shell expressions.
        example = str(root / "examples/greet").replace("'", "'\\''")
        send("PROMPT='GHOST_READY> '\n")
        until("GHOST_READY> ")
        send(f"'{example}'")
        until("<name> <greeting>")
        send(" Alice")
        until("<greeting>")
        send(" Hello\n")
        until("Hello, Alice!")
        send("exit\n")
        print("PASS: installed startup config, real Zsh ghost text, argument advancement, command execution")
    finally:
        os.close(fd)
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
