# Universal Linux and NixOS SpaceMouse support

Linux/NixOS HIDRAW access and the included Star Citizen v1 profile were
manually tested with the USB device `256f:c63a` in the reference environment
documented below.

This project provides a small, auditable integration for using a 3Dconnexion
SpaceMouse with Star Citizen on Linux. It does not require `spacenavd`,
`uinput`, a proprietary driver, registry changes, or world-writable HIDRAW
devices.

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

### Generic Linux

Preview every change first:

```console
./scripts/spacemouse-detect
./scripts/spacemouse-verify-access
sudo ./scripts/install-udev-rule --dry-run
sudo ./scripts/install-udev-rule
```

Installing the tested profile always requires explicit source and target paths:

```console
./scripts/star-citizen-find-installation
./scripts/star-citizen-install-profile \
  --profile profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml \
  --mappings-dir /explicit/path/to/controls/mappings \
  --dry-run
```

Repeat the installation command without `--dry-run` after verifying both
paths. The profile imports as `spacemouse_linux_usb_v1`; see its
[validation and inversion notes](profiles/star-citizen/README.md).

## Documentation

- [NixOS](docs/nixos.md)
- [Generic Linux](docs/generic-linux.md)
- [Nix-Citizen](docs/nix-citizen.md)
- [Star Citizen](docs/star-citizen.md)
- [Security model](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Support matrix](docs/support-matrix.md)

## Development

```console
tests/run.sh
nix flake check --no-write-lock-file
```

The repository is licensed under GPL-3.0; the existing `LICENSE` file is
unchanged.
