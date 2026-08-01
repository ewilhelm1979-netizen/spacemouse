# Generic Linux

Run `scripts/install-udev-rule --dry-run` before installation. The installer
accepts `--root` for controlled image or test roots, rejects symlink targets,
backs up an existing rule, and replaces it atomically. On the real root it
reloads udev rules but does not trigger every device.

Reconnect the SpaceMouse or restart the session after installation, then run
`scripts/spacemouse-detect` and `scripts/spacemouse-verify-access`.

Removal follows the same safety model:

```console
sudo scripts/remove-udev-rule --dry-run
sudo scripts/remove-udev-rule
```

The remover preserves a timestamped copy before deleting the active rule.
