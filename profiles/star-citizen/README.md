# Tested Star Citizen profile

`layout_spacemouse_linux_usb_v1_exported.xml` imports as
`spacemouse_linux_usb_v1`.

- SHA-256: `f76f84c085702a0aca2a0ae174f9ac2fc8d4221dbf2f6d051e9bd4820ec4c5db`
- hardware: 3Dconnexion SpaceMouse Wireless BT over USB (`256f:c63a`)
- Star Citizen LIVE: `4.9.188.23497`
- launcher environment: Nix-Citizen
- runner: Astral Wine 11.12
- all six physical axes tested
- shared flight and ground-vehicle movement bindings tested
- vertical movement uses `invert=1`
- no notification keyboard rebinds
- no drift, cross-axis input, or unexpected actions in the tested build

This is a delta export: Pitch, Yaw, Roll, and Forward/Backward can continue to
come from build defaults even when they are not serialized as explicit profile
changes. The tested lateral and vertical strafe axes are serialized explicitly.

No guarantee is made for other Star Citizen builds, devices, connection modes,
or VID:PID pairs. Bluetooth and Universal Receiver operation remain unverified.

## Installation

Preview the explicit target first:

```console
scripts/star-citizen-install-profile \
  --profile profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml \
  --mappings-dir /explicit/path/to/controls/mappings \
  --dry-run
```

Repeat without `--dry-run` only after verifying the paths. The installer backs
up an existing same-name target and replaces it atomically.

After import, visibly verify this device-specific setting:

```text
Controls
→ Joystick/HOTAS for the SpaceMouse
→ Inversion Settings
→ Flight
→ Flight Movement
→ Flight Strafe (Up/Down) = Yes
```

The profile contains `invert=1`, but the visible setting should still be
checked after import. Do not publish the game's global action-map file.
