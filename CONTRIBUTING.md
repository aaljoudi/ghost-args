# Contributing

Bug reports and pull requests are welcome. Include your OS, Zsh version (`zsh --version`), a minimal example script, what you typed, and the expected hint. Remove personal paths, command history, credentials, and private script content before posting.

## Development

Clone the repository and run:

```sh
zsh tests/run-tests.zsh
sh tests/install-tests.sh
python3 tests/interactive-tests.py
```

The runtime requires Zsh; Python 3 is only used for the interactive terminal test. Installation tests use disposable home directories and do not modify your real startup files.

Keep redraw hooks lightweight. Never evaluate the typed command, expand shell substitutions, execute inspected scripts, or render control characters from usage comments. Preserve unrelated startup configuration and normal history suggestions for commands without usage hints.

For changes to parsing or installation, add regression coverage. CI runs on Linux and macOS. Update the README and changelog when user-visible behavior changes.

For autosuggestions compatibility, check out `zsh-users/zsh-autosuggestions` at `v0.7.1`, then run the interactive test with `--autosuggestions /path/to/zsh-autosuggestions.zsh`. Repeat with `--plugin-first` to cover both load orders. These tests check idle display state after asynchronous responses, history matches, and arrow-key acceptance.
