# Nix-Citizen

The HIDRAW permission is independent of the Wine runner. Enable the NixOS
module, rebuild, and verify the native `/dev/hidraw*` ACL before opening the
launcher.

The profile finder checks only known candidate roots or paths supplied through
`--prefix` and `--game-root`. For a custom Nix-Citizen location, pass the exact
prefix explicitly. No Wine registry modification is required.

## Related projects and attribution

[nix-citizen](https://github.com/LovingMelody/nix-citizen) supplied the
NixOS-oriented package environment used for the documented reference,
including the `wine-astral` custom Wine build. It also packages
[LUG Helper](https://github.com/starcitizen-lug/lug-helper).

This SpaceMouse repository is maintained independently and provides only its
device-specific access, diagnostics, and profile path. It does not
automatically modify nix-citizen, LUG Helper, Wine, or launcher configuration.
No affiliation or endorsement is implied.
