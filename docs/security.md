# Security model

The rule grants access through logind's active-session `uaccess` mechanism and
matches only explicit VID:PID pairs. It does not make every HIDRAW device
world-writable, alter supplementary groups, or persist an ACL manually.

The scripts use canonical explicit paths, reject symlink and hard-linked
targets, create backups before destructive changes, and install rules and
profiles transactionally with signal cleanup and rollback. XML input is
bounded to 2 MiB, must be NUL-free UTF-8, and may not contain DTD or entity
declarations. Detection is limited to
`/sys/class`, `/dev`, environment-provided paths, and a small list of known game
locations. There is no whole-home or root filesystem scan.

No credentials, account identifiers, serial numbers, private paths, Wine
registry changes, telemetry, or proprietary drivers are required.
