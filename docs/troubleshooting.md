# Troubleshooting

1. Run `spacemouse-detect`; confirm one device with VID:PID `256f:c63a`.
2. Run `spacemouse-verify-access`; the current user needs read and write access
   to the matching HIDRAW node.
3. Inspect `udevadm info --query=property --name /dev/hidrawN` and confirm the
   `uaccess` tag.
4. Reconnect the USB device or reboot after installing a new rule.
5. Confirm the profile is imported in Star Citizen and assigned to the intended
   joystick instance.

Do not solve access failures with a world-writable HIDRAW rule. Multiple device
instances, drift, or cross-axis input should be diagnosed before changing
bindings.
