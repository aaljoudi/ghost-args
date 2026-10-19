# Ghost Args guide

[← Back to the README](../README.md)

## Other installation options

**ZIP download:** choose **Code → Download ZIP** on GitHub, extract it, then run `sh install.sh` and `exec zsh` from the extracted folder.

**Pinned release:** after a release tag has been published, use that tag in both places:

```sh
curl -fsSL https://raw.githubusercontent.com/aaljoudi/ghost-args/v0.1.0/install.sh | GHOST_ARGS_REF=v0.1.0 sh
```

The quick installer follows `main`. To review it first, download `install.sh`, inspect it, then run `sh install.sh`.

Installation uses `${XDG_DATA_HOME:-$HOME/.local/share}/ghost-args` and adds a managed source block to `${ZDOTDIR:-$HOME}/.zshrc`. Existing startup files receive uniquely named backups. Repeating installation updates the plugin without duplicating the source block.

## Configure

Set the style **before** sourcing the plugin in `.zshrc`:

```zsh
SCRIPT_ARG_HINT_STYLE='fg=8'       # default: dim gray
# Or: SCRIPT_ARG_HINT_STYLE='fg=cyan'
```

The style uses Zsh's `region_highlight` format. To use a custom install or startup location:

```sh
GHOST_ARGS_INSTALL_DIR="$HOME/.local/share/ghost-args" \
GHOST_ARGS_ZSHRC="${ZDOTDIR:-$HOME}/.zshrc" \
sh install.sh
```

The install directory must be absolute and cannot contain single quotes or newlines. Use the same overrides for updates and uninstall.

For manual installation or an existing plugin manager, source the file directly from your checkout:

```zsh
source '/absolute/path/to/ghost-args/script-arg-hints.zsh'
```

Choose either manual loading or the installer. Re-sourcing is supported.

## Uninstall without a download

From an existing checkout or ZIP download:

```sh
sh install.sh uninstall
exec zsh
```

Uninstall removes the managed source block and installed plugin; startup-file backups remain available. For a manual installation, remove your `source` line.

To remove a quick installation offline, delete the `# >>> ghost-args >>>` through `# <<< ghost-args <<<` block from `.zshrc`, delete the installed `script-arg-hints.zsh` file, and start a new Zsh session. Use the same path overrides for uninstall as for installation.

## Behavior and limitations

- Hints appear only at the end of the command line, for readable executable files.
- Quoted arguments count as one value; quoted executable paths may contain spaces.
- Commands on `PATH`, `~/` paths, leading environment assignments, and common redirections are supported.
- In a pipeline or `&&`/`||` list, hints follow the simple command at the cursor.
- Arguments advance as soon as you begin typing a value. Hints do not validate values or make arguments required.
- Usage metadata is positional: each whitespace-separated word after the documented command counts as an argument. Options, optional groups, variadic arguments, shell functions, aliases, interpreter prefixes such as `python script.py`, and full shell grammar are not modeled.
- Existing ghost text from another plugin takes priority. For example, an autosuggestion can temporarily hide these hints.
- No network calls or telemetry occur while typing. Local usage comments are read without executing scripts or evaluating substitutions. Comments containing terminal control characters are ignored.

## Troubleshooting

**No hints:** start a new Zsh session, confirm the plugin source line is present in your active `.zshrc`, run `chmod +x` on your script, and check that the usage comment is exactly on line 2 and names the same script. A script without usage metadata intentionally shows no hint.

**Hints disappear:** move the cursor to the end of the line. Another plugin may be using Zsh's shared ghost-text area.

**Custom dotfiles:** set `GHOST_ARGS_ZSHRC` when installing if your configuration loads a different startup file. The installer respects `ZDOTDIR` and preserves startup-file symlinks.

**Restore configuration:** the installer prints its backup path. Review that backup and copy it back if needed; restoring an older backup also restores the other settings from that point in time.

