# Security model

The rule grants access through logind's active-session `uaccess` mechanism and
matches only explicit VID:PID pairs. It does not make every HIDRAW device
world-writable, alter supplementary groups, or persist an ACL manually.

The scripts use explicit paths, reject symlink targets, create backups before
destructive changes, and install profiles atomically. Detection is limited to
`/sys/class`, `/dev`, environment-provided paths, and a small list of known game
locations. There is no whole-home or root filesystem scan.

No credentials, account identifiers, serial numbers, private paths, Wine
registry changes, telemetry, or proprietary drivers are required.
