# Nix-Citizen

The HIDRAW permission is independent of the Wine runner. Enable the NixOS
module, rebuild, and verify the native `/dev/hidraw*` ACL before opening the
launcher.

The profile finder checks only known candidate roots or paths supplied through
`--prefix` and `--game-root`. For a custom Nix-Citizen location, pass the exact
prefix explicitly. No Wine registry modification is required.
