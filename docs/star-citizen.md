# Star Citizen

Star Citizen exports controller changes as a delta profile. Build defaults can
therefore provide Pitch, Yaw, Roll, and Forward/Backward even when only lateral
and vertical strafe are serialized explicitly.

For the tested device, Flight Strafe Up/Down requires device-specific
inversion. Shared movement bindings also worked for ground vehicles in the
tested LIVE build.

Use `star-citizen-find-installation` to print bounded candidates. Installation
requires an explicit profile file and mappings directory, creates a backup when
replacing a file, and uses an atomic rename. The repository does not alter
the game-wide action-map file, user configuration, a Wine registry, or a
runner.

The sanitized public profile remains blocked on a final manual import test.
