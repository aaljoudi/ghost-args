# Publishing a release

Before making the repository public:

1. Author: Abdulrahman Aljoudi (`aaljoudi`). License: MIT. Repository: `https://github.com/aaljoudi/ghost-args`. The first release supports Zsh only.
2. Run the three commands in CONTRIBUTING.md and review the complete upload, including hidden files. Never upload startup files or test output containing private paths.
3. Review `git status` and `git diff --cached`, commit the release files, and push `main` to `origin`. This working directory initially had no Git repository or history to audit. Confirm the remote is `git@github.com:aaljoudi/ghost-args.git` (or the equivalent HTTPS URL) before pushing.
4. Enable GitHub private vulnerability reporting in repository settings.
5. Confirm the Linux and macOS CI jobs pass on GitHub.
6. Tag the reviewed commit `v0.1.0` and create a GitHub release using CHANGELOG.md. GitHub automatically provides source ZIP and tar archives; no compiled binary is required.
7. Run the public installation command in a disposable account or home directory after the repository becomes accessible, then run the README demo and uninstall.

The remote download cannot be verified against GitHub until the repository exists and the tested files have been pushed. Keep release URLs pinned to a reviewed tag when sharing a reproducible installer.
