# Star Citizen

Star Citizen exports controller changes as a delta profile. Build defaults can
therefore provide Pitch, Yaw, Roll, and Forward/Backward even when only lateral
and vertical strafe are serialized explicitly.

For the tested device, Flight Strafe Up/Down requires device-specific
inversion. Shared movement bindings also worked for ground vehicles in the
tested LIVE build.

Use `star-citizen-find-installation` to print bounded candidates. Installation
requires an explicit profile file and mappings directory, creates a backup when
replacing a file, and uses transactional same-directory publication with
rollback after failures or signals. The repository does not alter
the game-wide action-map file, user configuration, a Wine registry, or a
runner.

The included `spacemouse_linux_usb_v1` profile was manually imported and tested
with all six axes, correct vertical direction, shared ground-vehicle movement,
and no drift, cross-axis input, notification keyboard rebinds, or unexpected
actions.

Preview installation with an explicit mappings directory:

```console
mappings_dir=$(mktemp -d)
nix develop --command scripts/star-citizen-install-profile \
  --profile "$PWD/profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml" \
  --mappings-dir "$mappings_dir" \
  --dry-run
rmdir "$mappings_dir"
```

The temporary directory makes this preview safe to copy. For a real install,
replace `mappings_dir` with the reviewed canonical existing mappings directory.

After import, select the SpaceMouse under `Controls`, open `Inversion Settings
→ Flight → Flight Movement`, and verify `Flight Strafe (Up/Down) = Yes`. The
profile contains `invert=1`, but the visible setting should still be checked.

See [Hardware and detection](hardware-and-detection.md) for the distinction
between native detection, Wine visibility, binding verification, and the
historical manual gameplay result.
