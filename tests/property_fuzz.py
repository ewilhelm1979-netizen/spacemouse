#!/usr/bin/env python3
import os
import pathlib
import random
import subprocess
import tempfile


SEED = 20260801
random.seed(SEED)
root = pathlib.Path(__file__).resolve().parent.parent


def run(*args: str, expected: int = 0, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    result = subprocess.run(args, text=True, capture_output=True, env=merged, check=False)
    if result.returncode != expected:
        raise AssertionError(
            f"expected {expected}, got {result.returncode}: {args!r}\n"
            f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
        )
    return result


scripts = [
    "install-udev-rule",
    "remove-udev-rule",
    "spacemouse-detect",
    "spacemouse-verify-access",
    "star-citizen-find-installation",
    "star-citizen-install-profile",
    "star-citizen-remove-profile",
]
alphabet = "abcXYZ019 _-;*?[]{}'\"\\\tΩ"
for script in scripts:
    path = root / "scripts" / script
    for _ in range(8):
        option = "--unknown-" + "".join(random.choice(alphabet) for _ in range(12))
        run(str(path), option, expected=2)

with tempfile.TemporaryDirectory() as raw_temp:
    temp = pathlib.Path(raw_temp).resolve()
    mappings = temp / "mappings"
    mappings.mkdir()
    profile = temp / "layout_property.xml"
    profile.write_text(
        '<ActionMaps profileName="property"><CustomisationUIHeader label="property" />'
        '<actionmap name="spaceship_movement"><action name="v_roll_left">'
        '<rebind input="js1_x" /></action></actionmap></ActionMaps>',
        encoding="utf-8",
    )

    invalid_names = [
        "", "layout_.xml", "../layout_escape.xml", "layout_ name.xml",
        "layout_$(touch PROPERTY_EXECUTED).xml", "layout_Ω.xml", "layout_x.xml/extra",
    ]
    for name in invalid_names:
        expected = 2
        run(
            str(root / "scripts/star-citizen-install-profile"),
            "--profile", str(profile), "--mappings-dir", str(mappings),
            "--name", name, "--dry-run", expected=expected,
        )
    if pathlib.Path("PROPERTY_EXECUTED").exists():
        raise AssertionError("profile-name data was executed")

    for index in range(32):
        name = "layout_property-" + "".join(random.choice("abc012.-_") for _ in range(16)) + ".xml"
        run(
            str(root / "scripts/star-citizen-install-profile"),
            "--profile", str(profile), "--mappings-dir", str(mappings),
            "--name", name, "--dry-run",
        )

    for value in ["", "0", "fffff", "xyz1", "12 3", "１２３４", "$(id)", "25\n6f"]:
        run(str(root / "scripts/spacemouse-detect"), "--vendor", value, "--dry-run", expected=2)
        run(str(root / "scripts/spacemouse-verify-access"), "--product", value, "--dry-run", expected=2)

    for unsafe_root in [
        "relative", f"{temp}/.", str(temp / "missing"), f"{temp}/../{temp.name}"
    ]:
        run(
            str(root / "scripts/install-udev-rule"),
            "--root", unsafe_root, "--no-reload", expected=3,
        )

print(f"PASS: deterministic CLI, identifier, path, and XML installation properties (seed {SEED})")
