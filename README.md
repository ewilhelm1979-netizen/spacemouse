# SpaceMouse support for Linux and NixOS

Linux/NixOS HIDRAW access and the included Star Citizen v1 profile were
manually tested with the USB device `256f:c63a` in the reference environment
documented below.

This project provides a small, auditable integration for using a 3Dconnexion
SpaceMouse with Star Citizen on Linux. It does not require `spacenavd`,
`uinput`, a proprietary driver, registry changes, or world-writable HIDRAW
devices.

## AI-assisted development

This project was developed with substantial assistance from OpenAI Codex.
The human maintainer remains responsible for architecture, implementation
review, security decisions, testing, licensing, provenance, and releases.

## Tested reference

- 3Dconnexion SpaceMouse Wireless BT over USB (`256f:c63a`)
- NixOS 26.05 and Nix-Citizen
- Astral Wine 11.12
- Star Citizen LIVE 4.9.188.23497
- six axes, including the required vertical inversion
- no drift, cross-axis input, or unexpected actions
- shared flight and ground-vehicle movement bindings

Bluetooth, Universal Receiver operation, and other product IDs remain
unverified. Add another device only after confirming its exact VID:PID pair.

## Related Star Citizen Linux projects

The documented reference environment was tested on NixOS with
[nix-citizen](https://github.com/LovingMelody/nix-citizen) and the
`wine-astral` package supplied through that project.

[LUG Helper](https://github.com/starcitizen-lug/lug-helper) is the official
installer maintained by the Star Citizen Linux Users Group and community. It
covers broader installation, Wine-runner management, system preparation,
maintenance, and general troubleshooting workflows.

This repository complements that ecosystem with a narrowly scoped SpaceMouse
implementation: device-specific HIDRAW access, Linux and NixOS diagnostics,
and the tested Star Citizen controller profile.

These references are provided for attribution and technical context. This
repository is maintained independently; no affiliation or endorsement by the
LUG Helper or nix-citizen maintainers is implied.

## Hardware and detection

The tested reference is a 3Dconnexion SpaceMouse Wireless BT connected over
USB as `256f:c63a`. Linux exposes it as a six-axis, two-button controller, and
it is visible through the Wine controller interface. Native detection, Wine
visibility, binding verification, and gameplay verification are separate
layers: success at one layer does not establish success at a later layer.

![AI-assisted documentation image of the tested 3Dconnexion SpaceMouse Wireless BT](docs/images/spacemouse.png)

![AI-assisted documentation rendering of Linux and Wine detecting the SpaceMouse as a six-axis, two-button controller](docs/images/setup.png)

These visuals were prepared with AI assistance for documentation. They are
illustrative and are not the raw private audit evidence.

Successful Star Citizen gameplay was established by the separately documented
manual test. The 2026-08 live read-only audit independently confirmed current
USB-ancestor detection and effective HIDRAW read/write access without
consuming device events. Bluetooth, Universal Receiver operation, other
SpaceMouse models, other Linux distributions and Wine runners, and future Star
Citizen builds remain unverified unless separately documented.

## Quick start

### NixOS

```nix
{
  inputs.spacemouse.url = "github:ewilhelm1979-netizen/spacemouse";

  outputs = { nixpkgs, spacemouse, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      modules = [
        spacemouse.nixosModules.default
        { hardware.spacemouse.enable = true; }
      ];
    };
  };
}
```

Enabling the module installs the two read-only discovery/access commands.
`hardware.spacemouse.diagnosticTools` adds optional USB, evdev, and joystick
utilities; it is not required for the repository commands.

### Generic Linux

Preview every change first:

```console
./scripts/spacemouse-detect
./scripts/spacemouse-verify-access
sudo ./scripts/install-udev-rule --dry-run
sudo ./scripts/install-udev-rule
```

The generic scripts require Bash, GNU core utilities, Udev tools, Python 3,
libxml2 (`xmllint`), and ACL tools as applicable. The flake package supplies
these dependencies on supported Nix systems.

Installing the tested profile always requires explicit source and target paths:

```console
./scripts/star-citizen-find-installation --dry-run
mappings_dir=$(mktemp -d)
nix develop --command ./scripts/star-citizen-install-profile \
  --profile "$PWD/profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml" \
  --mappings-dir "$mappings_dir" \
  --dry-run
rmdir "$mappings_dir"
```

The temporary directory makes the preview block safe to copy verbatim. For a
real installation, set `mappings_dir` to the canonical existing mappings
directory reported and reviewed by the user, then repeat without `--dry-run`.
The profile imports as `spacemouse_linux_usb_v1`; see its
[validation and inversion notes](profiles/star-citizen/README.md).

## Documentation

- [NixOS](docs/nixos.md)
- [Generic Linux](docs/generic-linux.md)
- [Hardware and detection](docs/hardware-and-detection.md)
- [Nix-Citizen](docs/nix-citizen.md)
- [Star Citizen](docs/star-citizen.md)
- [Security model](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Support matrix](docs/support-matrix.md)

## Acknowledgements

The original idea to try a SpaceMouse with Star Citizen came from
[Nerdorbit](https://www.youtube.com/@nerdorbitlp) and his
[SpaceMouse demonstration](https://www.youtube.com/watch?v=aBZHOwq837k).

The video shows how smoothly a compact SpaceMouse can control movement with
six degrees of freedom (6DoF): three translations—left and right along the X
axis, forward and backward along the Y axis, and up and down along the Z
axis—and three rotations: pitch, yaw, and roll.

A SpaceMouse provides all six movement dimensions from one compact device
while using relatively little desk space. Thank you to Nerdorbit for sharing
the idea and demonstration that started this experiment.

- [Nerdorbit Discord community](https://discord.gg/fkF3buGnA)
- [Nerdorbit YouTube channel](https://www.youtube.com/@nerdorbitlp)
- [SpaceMouse demonstration video](https://www.youtube.com/watch?v=aBZHOwq837k)

The implementation, NixOS integration, security design, tests, documentation,
and repository maintenance were completed independently. This acknowledgement
does not imply review, endorsement, affiliation, or responsibility for the
implementation.

## Development

```console
tests/run.sh
nix flake check --no-write-lock-file
nix build .#packages.x86_64-linux.default
nix run .#default -- --help
```

The repository is licensed under GPL-3.0; the existing `LICENSE` file is
unchanged.
