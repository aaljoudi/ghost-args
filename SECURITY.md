# Security

Ghost Args reads usage metadata from local executable files. It does not execute those files to obtain hints, evaluate command substitutions, collect telemetry, or send command lines over the network. The installer is the only component that may download code.

Do not include credentials, private commands, or personal paths in public issues. Report suspected vulnerabilities privately through the repository's GitHub **Security → Report a vulnerability** feature when enabled. If private reporting is unavailable, open an issue requesting a private contact without disclosing exploit details.

Only install code from a source you trust. Inspect the installer before running it if you prefer. Startup files can execute arbitrary shell code, so keep their backups until you have verified installation.
