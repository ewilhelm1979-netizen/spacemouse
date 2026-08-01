# Universal Linux and NixOS SpaceMouse support

> **Work in progress:** Linux/NixOS HIDRAW access is implemented and tested for
> USB `256f:c63a`. The sanitized Star Citizen profile is intentionally withheld
> until its final manual import test is complete.

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

Installing a future tested profile always requires explicit source and target
paths:

```console
./scripts/star-citizen-find-installation
./scripts/star-citizen-install-profile \
  --profile /path/to/tested-layout.xml \
  --mappings-dir /explicit/path/to/controls/mappings \
  --dry-run
```

No profile XML is included in this branch. See [the tracking issue](https://github.com/ewilhelm1979-netizen/spacemouse/issues/1).

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
