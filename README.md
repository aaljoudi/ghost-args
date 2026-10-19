# Ghost Args

Created by [Abdulrahman Aljoudi (@aaljoudi)](https://github.com/aaljoudi). [MIT licensed](LICENSE).

Lightweight argument hints for scripts in your Zsh terminal. Add a usage comment to a script, then see its remaining arguments as dim ghost text while you type.

```text
$ ./greet                          <name> <greeting>
$ ./greet Alice                    <greeting>
$ ./greet Alice Hello
Hello, Alice!
```

The placeholders are a visual guide. They are never inserted into your command or executed.

## Requirements

- Zsh 5.3 or later on macOS or Linux, with ZLE enabled.
- A terminal that supports Zsh's line editor and colors.
- No runtime packages, background service, Python, Node.js, or administrator access.

This version uses Zsh-specific line editor hooks. You can launch the installer from Bash, but hints appear in **Zsh sessions only**. A terminal application (Terminal, iTerm2, VS Code, etc.) and the shell running inside it are separate things. Run `echo "$ZSH_VERSION"` to check whether your current shell is Zsh.

## Quick install

Run this in your terminal:

```sh
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/aaljoudi/ghost-args/main/install.sh | sh
exec zsh
```

This downloads the installer and plugin from this repository's `main` branch. The command becomes publicly usable after the repository is public and these files are pushed. To review before running, download `install.sh`, inspect it, then run `sh install.sh`.

For a pinned release, use that tag in both the installer URL and `GHOST_ARGS_REF` (after the tag has been published):

```sh
curl -fsSL https://raw.githubusercontent.com/aaljoudi/ghost-args/v0.1.0/install.sh | GHOST_ARGS_REF=v0.1.0 sh
```

## Install from a download

On the GitHub repository page, choose **Code → Download ZIP**, extract it, and open a terminal in the extracted folder:

```sh
sh install.sh
exec zsh
```

Installation copies one plugin file into `${XDG_DATA_HOME:-$HOME/.local/share}/ghost-args` and adds a marked source block to `${ZDOTDIR:-$HOME}/.zshrc`. Existing startup files receive a uniquely named backup next to the original. No `sudo` is needed. Repeating installation updates the plugin and keeps a single source block.

If you already use a Git checkout, run the same commands from its root. Keep the download or checkout if you want to use its installer to uninstall later.

## Try it

If you installed with the one-line command, create a tiny example:

```sh
printf '%s\n' '#!/bin/sh' '# ./greet <name> <greeting>' 'printf "%s, %s!\n" "$2" "$1"' > greet
chmod +x greet
```

Type `./greet` without pressing Enter to see the hints.

From a downloaded project folder, you can also use the included example:

```sh
./examples/greet
```

Before pressing Enter, you should see `<name> <greeting>` in dim text. Type ` Alice` and the hint advances to `<greeting>`. Type ` Hello` and press Enter to run the example.

For your own executable script, put its usage comment on **line 2**:

```sh
#!/bin/sh
# ./deploy <environment> <version>
printf 'Deploying %s to %s\n' "$2" "$1"
```

Save it as `deploy`, run `chmod +x deploy`, and type `./deploy` in Zsh. The documented command's filename must match the executable's filename. The script can be written in any language; the second line must start with `#` and the first placeholder must start with `<`.

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

## Update and uninstall

Run the quick-install command again, or download a newer version and run `sh install.sh`. For a Git checkout, pull the desired version first.

To uninstall a quick installation:

```sh
curl -fsSL https://raw.githubusercontent.com/aaljoudi/ghost-args/main/install.sh | sh -s -- uninstall
exec zsh
```

Or run from a downloaded copy or checkout:

```sh
sh install.sh uninstall
exec zsh
```

Uninstall removes the managed source block and installed plugin file. Backups remain available for your own review. For a manual install, remove your `source` line instead. To remove a quick installation without network access, delete the `# >>> ghost-args >>>` through `# <<< ghost-args <<<` block from your `.zshrc`, delete the installed `script-arg-hints.zsh` file, and start a new Zsh session.

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

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests, [SECURITY.md](SECURITY.md) for security reporting, and [CHANGELOG.md](CHANGELOG.md) for releases.
