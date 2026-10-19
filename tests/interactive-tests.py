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
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--autosuggestions", type=Path)
parser.add_argument("--plugin-first", action="store_true")
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="ghost-args-pty-") as home:
    environment = os.environ.copy()
    for key in ("GHOST_ARGS_INSTALL_DIR", "GHOST_ARGS_ZSHRC"):
        environment.pop(key, None)
    environment.update(HOME=home, ZDOTDIR=home, XDG_DATA_HOME=home + "/data", TERM="xterm-256color")
    subprocess.run(["sh", str(root / "install.sh")], env=environment, check=True, capture_output=True)
    if args.autosuggestions:
        autosuggestions = str(args.autosuggestions.resolve()).replace("'", "'\\''")
        rc = Path(home) / ".zshrc"
        source = f"source '{autosuggestions}'\n"
        rc.write_text(rc.read_text() + source if args.plugin_first else source + rc.read_text())
    # Snapshot existing ZLE state before the redraw caused by the probe key.
    snapshot = Path(home) / "snapshot"
    with (Path(home) / ".zshrc").open("a") as rc:
        rc.write("\n_ghost_test_snapshot() { print -rl -- \"$BUFFER\" \"$POSTDISPLAY\" > \"$HOME/snapshot\"; }\n")
        rc.write("zle -N _ghost_test_snapshot\nbindkey '^X^G' _ghost_test_snapshot\n")
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

    def assert_state(buffer, hint):
        deadline = time.monotonic() + 0.25
        while time.monotonic() < deadline:
            if select.select([fd], [], [], 0.01)[0]:
                os.read(fd, 65536)
        snapshot.unlink(missing_ok=True)
        send("\x18\x07")
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if snapshot.exists():
                lines = snapshot.read_text().splitlines()
                if len(lines) == 2:
                    assert lines == [buffer, hint], lines
                    return
            if select.select([fd], [], [], 0.01)[0]:
                os.read(fd, 65536)
        output = b""
        while select.select([fd], [], [], 0)[0]:
            output += os.read(fd, 65536)
        raise AssertionError(f"ZLE state probe did not finish: {output!r}")

    try:
        # Shell quoting without interpolating executable shell expressions.
        example = str(root / "examples/greet").replace("'", "'\\''")
        send("PROMPT='GHOST_READY> '\n")
        until("GHOST_READY> ")
        send(f"'{example}'")
        until("<name> <greeting>")
        assert_state(f"'{example}'", " <name> <greeting>")
        send(" Alice")
        until("<greeting>")
        assert_state(f"'{example}' Alice", " <greeting>")
        # Accepting a suggestion must never insert argument placeholders.
        send("\x1b[C")
        assert_state(f"'{example}' Alice", " <greeting>")
        send(" Hello\n")
        until("Hello, Alice!")
        # Repeat with a matching history entry; usage hints still win.
        send(f"'{example}'")
        assert_state(f"'{example}'", " <name> <greeting>")
        send(" Alice")
        assert_state(f"'{example}' Alice", " <greeting>")
        if args.autosuggestions:
            # Commands without usage metadata keep normal history acceptance.
            send("\x15echo ghost_history_value\n")
            until("ghost_history_value")
            send("echo ghost_")
            assert_state("echo ghost_", "history_value")
            send("\x1b[C")
            assert_state("echo ghost_history_value", "")
        send("\x15exit\n")
        print("PASS: installed startup config, real Zsh ghost text, argument advancement, command execution")
    finally:
        os.close(fd)
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
