#!/bin/sh
# Copyright (c) 2026 Abdulrahman Aljoudi (aaljoudi)
# SPDX-License-Identifier: MIT
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ghost-args-test.XXXXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
export HOME="$test_root/home with spaces"
export GHOST_ARGS_INSTALL_DIR="$HOME/data/ghost args"
export GHOST_ARGS_ZSHRC="$HOME/config/.zshrc"
mkdir -p "$(dirname "$GHOST_ARGS_ZSHRC")"
printf '# existing config\nexport KEEP_ME=yes\n' > "$GHOST_ARGS_ZSHRC"
cp "$GHOST_ARGS_ZSHRC" "$test_root/original"
sh "$project_dir/install.sh"
[ -r "$GHOST_ARGS_INSTALL_DIR/script-arg-hints.zsh" ]
cp "$GHOST_ARGS_ZSHRC" "$test_root/once"
sh "$project_dir/install.sh"
cmp "$test_root/once" "$GHOST_ARGS_ZSHRC"
zsh -fc 'source "$GHOST_ARGS_ZSHRC"; [[ $KEEP_ME == yes ]]; (( $+functions[_script_arg_hint_update] ))'
zsh -fic 'source "$GHOST_ARGS_ZSHRC"; source "$GHOST_ARGS_ZSHRC"' </dev/null
sh "$project_dir/install.sh" uninstall
cmp "$test_root/original" "$GHOST_ARGS_ZSHRC"
[ ! -e "$GHOST_ARGS_INSTALL_DIR/script-arg-hints.zsh" ]
# Preserve a symlink used by dotfile managers.
ln -s "$GHOST_ARGS_ZSHRC" "$HOME/linked-zshrc"
export GHOST_ARGS_ZSHRC="$HOME/linked-zshrc"
sh "$project_dir/install.sh"
[ -L "$GHOST_ARGS_ZSHRC" ]
sh "$project_dir/install.sh" uninstall
cmp "$test_root/original" "$GHOST_ARGS_ZSHRC"
# Malformed blocks must fail without altering the file.
printf '# >>> ghost-args >>>\nkeep this\n' > "$GHOST_ARGS_ZSHRC"
cp "$GHOST_ARGS_ZSHRC" "$test_root/malformed"
if sh "$project_dir/install.sh"; then
    printf 'FAIL: accepted malformed startup block\n' >&2
    exit 1
fi
cmp "$test_root/malformed" "$GHOST_ARGS_ZSHRC"
# Simulate the download path without contacting external services.
mkdir -p "$test_root/bin"
cp "$project_dir/install.sh" "$test_root/remote-install.sh"
cat > "$test_root/bin/curl" <<'CURL'
#!/bin/sh
set -eu
if [ "${GHOST_ARGS_TEST_DOWNLOAD_FAIL:-}" = yes ]; then
    exit 22
fi
while [ "$#" -gt 0 ]; do
    case "$1" in
        https://raw.githubusercontent.com/*) printf '%s\n' "$1" > "$GHOST_ARGS_TEST_DOWNLOAD_LOG" ;;
    esac
    if [ "$1" = -o ]; then
        cp "$GHOST_ARGS_TEST_PLUGIN" "$2"
        exit 0
    fi
    shift
done
exit 1
CURL
chmod +x "$test_root/bin/curl"
export GHOST_ARGS_TEST_PLUGIN="$project_dir/script-arg-hints.zsh"
export GHOST_ARGS_ZSHRC="$HOME/remote-zshrc"
export GHOST_ARGS_TEST_DOWNLOAD_LOG="$test_root/download-url"
PATH="$test_root/bin:$PATH" sh < "$project_dir/install.sh"
[ "$(cat "$GHOST_ARGS_TEST_DOWNLOAD_LOG")" = 'https://raw.githubusercontent.com/aaljoudi/ghost-args/main/script-arg-hints.zsh' ]
cmp "$GHOST_ARGS_TEST_PLUGIN" "$GHOST_ARGS_INSTALL_DIR/script-arg-hints.zsh"
sh "$test_root/remote-install.sh" uninstall
# A failed download must leave configuration and installed code untouched.
printf '# untouched startup file\n' > "$GHOST_ARGS_ZSHRC"
cp "$GHOST_ARGS_ZSHRC" "$test_root/before-failure"
if PATH="$test_root/bin:$PATH" GHOST_ARGS_TEST_DOWNLOAD_FAIL=yes sh < "$project_dir/install.sh"; then
    printf 'FAIL: ignored a failed download\n' >&2
    exit 1
fi
cmp "$test_root/before-failure" "$GHOST_ARGS_ZSHRC"
[ ! -e "$GHOST_ARGS_INSTALL_DIR/script-arg-hints.zsh" ]
printf 'PASS: local and piped install, updates, startup loading, uninstall, symlinks, malformed markers, download failures\n'
