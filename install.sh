#!/bin/sh
# Copyright (c) 2026 Abdulrahman Aljoudi (aaljoudi)
# SPDX-License-Identifier: MIT
# Install or remove Ghost Args without administrator privileges.
# Parse the complete installer before running it, including when piped to sh.
main() {
set -eu

# Override these to install a fork or a reviewed release tag.
repository=${GHOST_ARGS_REPO:-aaljoudi/ghost-args}
revision=${GHOST_ARGS_REF:-main}
mode=${1:-install}
case "$mode" in
    install|uninstall) ;;
    *) printf 'Usage: sh install.sh [install|uninstall]\n' >&2; exit 2 ;;
esac

install_dir=${GHOST_ARGS_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ghost-args}
rc_file=${GHOST_ARGS_ZSHRC:-${ZDOTDIR:-$HOME}/.zshrc}
start='# >>> ghost-args >>>'
end='# <<< ghost-args <<<'

case "$install_dir$rc_file" in
    *"$(printf '\r')"*|*"
"*) printf 'Paths must not contain newlines.\n' >&2; exit 1 ;;
esac
case "$install_dir" in
    /*) ;;
    *) printf 'GHOST_ARGS_INSTALL_DIR must be an absolute path.\n' >&2; exit 1 ;;
esac
# Single quotes would break the literal source line written below.
case "$install_dir" in
    *"'"*) printf 'The install directory must not contain single quotes.\n' >&2; exit 1 ;;
esac

command -v zsh >/dev/null 2>&1 || {
    printf 'Ghost Args requires Zsh. Install Zsh, then run this installer again.\n' >&2
    exit 1
}

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ghost-args.XXXXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ "$mode" = install ]; then
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    if [ -f "$0" ] && [ -f "$script_dir/script-arg-hints.zsh" ]; then
        cp "$script_dir/script-arg-hints.zsh" "$work_dir/plugin.zsh"
    else
        case "$repository" in
            ''|*[!A-Za-z0-9_./-]*|*..*|/*|*/|*/*/*)
                printf 'Set GHOST_ARGS_REPO to the public GitHub owner/repository.\n' >&2
                exit 1 ;;
            */*) ;;
            *) printf 'GHOST_ARGS_REPO must be owner/repository.\n' >&2; exit 1 ;;
        esac
        case "$revision" in
            ''|*[!A-Za-z0-9_.-]*|*..*) printf 'Invalid GHOST_ARGS_REF.\n' >&2; exit 1 ;;
        esac
        command -v curl >/dev/null 2>&1 || {
            printf 'curl is required for remote installation.\n' >&2; exit 1
        }
        curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
            "https://raw.githubusercontent.com/$repository/$revision/script-arg-hints.zsh" \
            -o "$work_dir/plugin.zsh"
    fi
    zsh -n "$work_dir/plugin.zsh"
fi

mkdir -p "$(dirname -- "$rc_file")"
if [ -e "$rc_file" ]; then
    [ -f "$rc_file" ] && [ -r "$rc_file" ] || {
        printf 'Cannot read startup file: %s\n' "$rc_file" >&2; exit 1
    }
    # Refuse malformed markers instead of discarding unrelated configuration.
    awk -v start="$start" -v end="$end" '
        $0 == start { if (inside || seen) exit 1; inside=1; seen=1; next }
        $0 == end { if (!inside) exit 1; inside=0 }
        END { if (inside) exit 1 }
    ' "$rc_file" || {
        printf 'Malformed Ghost Args markers in %s; fix them before retrying.\n' "$rc_file" >&2
        exit 1
    }
    awk -v start="$start" -v end="$end" '
        $0 == start { inside=1; next }
        $0 == end { inside=0; next }
        !inside { print }
    ' "$rc_file" > "$work_dir/zshrc"
else
    : > "$work_dir/zshrc"
fi

if [ "$mode" = install ]; then
    mkdir -p "$install_dir"
    cp "$work_dir/plugin.zsh" "$install_dir/script-arg-hints.zsh"
    chmod 644 "$install_dir/script-arg-hints.zsh"
    printf "%s\n[ ! -r '%s/script-arg-hints.zsh' ] || source '%s/script-arg-hints.zsh'\n%s\n" \
        "$start" "$install_dir" "$install_dir" "$end" >> "$work_dir/zshrc"
fi

if [ -e "$rc_file" ]; then
    backup=$(mktemp "$rc_file.ghost-args-backup.XXXXXXXX")
    cp -p "$rc_file" "$backup"
    printf 'Startup file backup: %s\n' "$backup"
fi
# Write through existing symlinks (for dotfile managers) and preserve permissions.
cat "$work_dir/zshrc" > "$rc_file"

if [ "$mode" = uninstall ]; then
    rm -f "$install_dir/script-arg-hints.zsh"
    rmdir "$install_dir" 2>/dev/null || :
    printf 'Ghost Args removed. Open a new Zsh session.\n'
else
    printf 'Ghost Args installed. Open a new Zsh session, or run: exec zsh\n'
fi
}

main "$@"
