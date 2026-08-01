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

The immutable tested export contains exactly eight `spaceship_movement`
entries: Roll Left/Right and lateral strafe use `js1_x`; vertical strafe uses
`js1_z`; and the four single-direction strafe entries contain the exported
`js1_ ` clearing token. These whitespace-suffixed clearing tokens are preserved
because changing them would change the manually tested artifact and its
published SHA-256. There are no keyboard, mouse, notification, weapon, fire,
or foreign-controller rebinds. Generic XML validators may deliberately flag
such clearing tokens for manual review.

No guarantee is made for other Star Citizen builds, devices, connection modes,
or VID:PID pairs. Bluetooth and Universal Receiver operation remain unverified.

## Installation

Preview the explicit target first:

```console
mappings_dir=$(mktemp -d)
nix develop --command scripts/star-citizen-install-profile \
  --profile "$PWD/profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml" \
  --mappings-dir "$mappings_dir" \
  --dry-run
rmdir "$mappings_dir"
```

This copy-safe preview uses an empty temporary target. For a real installation,
set `mappings_dir` to the canonical existing game mappings directory and repeat
without `--dry-run` only after verifying both paths. The installer backs
up an existing same-name target and replaces it transactionally. It rejects
DTD/entity declarations, oversized or malformed XML, inconsistent internal
profile names, symlinked paths, and hard-linked targets. A validated backup can
be restored only by supplying its reviewed canonical path, mappings directory,
and exact `layout_*.xml` target name to `--restore-backup`, `--mappings-dir`,
and `--name`; preview the restore first with `--dry-run`.

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
