# NixOS

Import `nixosModules.default` from the flake and set
`hardware.spacemouse.enable = true`. The default device list contains only the
tested USB pair `256f:c63a`.

Both `spacemouse-detect` and `spacemouse-verify-access` are installed whenever
the module is enabled. Set `hardware.spacemouse.diagnosticTools = true` only
when the additional `lsusb`, `evtest`, and `jstest-gtk` utilities are wanted.
The module installs a udev package named
`60-spacemouse-hidraw.rules`; it does not install or start a daemon.

After rebuilding, log out and back in or reboot so the active graphical session
receives the `uaccess` ACL. Verify with `spacemouse-verify-access`.

Rollback: disable the option or remove the module import, rebuild NixOS, and
reboot. No group or persistent ACL cleanup is needed.

See [Hardware and detection](hardware-and-detection.md) for the tested USB
identity, dynamic Linux node types, and the boundaries between native, Wine,
and gameplay evidence.
