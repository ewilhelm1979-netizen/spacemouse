# NixOS

Import `nixosModules.default` from the flake and set
`hardware.spacemouse.enable = true`. The default device list contains only the
tested USB pair `256f:c63a`.

Set `hardware.spacemouse.diagnosticTools = true` only when the optional USB,
evdev, joystick, and repository diagnostic tools are wanted. This makes both
`spacemouse-detect` and `spacemouse-verify-access` available in `PATH`, alongside
`lsusb`, `evtest`, and `jstest-gtk`. The module installs a udev package named
`60-spacemouse-hidraw.rules`; it does not install or start a daemon.

After rebuilding, log out and back in or reboot so the active graphical session
receives the `uaccess` ACL. Verify with `spacemouse-verify-access`.

Rollback: disable the option or remove the module import, rebuild NixOS, and
reboot. No group or persistent ACL cleanup is needed.
