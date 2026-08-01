#!/usr/bin/env bash
set -Eeuo pipefail

repo=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}

expected_rule='SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c63a", TAG+="uaccess"'
[[ $(<"$repo/udev/60-spacemouse-hidraw.rules") == "$expected_rule" ]] || fail 'scoped udev rule'
pass 'scoped udev rule is exact'

for script in "$repo"/scripts/*; do
  [[ -x $script ]] || fail "not executable: $script"
  "$script" --help >/dev/null
done
"$repo/scripts/spacemouse-detect" --dry-run >/dev/null
"$repo/scripts/spacemouse-verify-access" --dry-run >/dev/null
pass 'help and hardware dry-run paths'

root=$tmp/root
mkdir -p "$root"
"$repo/scripts/install-udev-rule" --root "$root" --dry-run --no-reload >/dev/null
[[ ! -e $root/etc/udev/rules.d/60-spacemouse-hidraw.rules ]] || fail 'udev dry-run modified root'
"$repo/scripts/install-udev-rule" --root "$root" --no-reload >/dev/null
cmp -s "$repo/udev/60-spacemouse-hidraw.rules" "$root/etc/udev/rules.d/60-spacemouse-hidraw.rules" || fail 'udev install'
printf 'old rule\n' >"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
"$repo/scripts/install-udev-rule" --root "$root" --no-reload >/dev/null
compgen -G "$root/etc/udev/rules.d/60-spacemouse-hidraw.rules.backup.*" >/dev/null || fail 'udev backup'
grep -qx 'old rule' "$root"/etc/udev/rules.d/60-spacemouse-hidraw.rules.backup.* || fail 'udev backup content'
"$repo/scripts/remove-udev-rule" --root "$root" --dry-run --no-reload >/dev/null
[[ -e $root/etc/udev/rules.d/60-spacemouse-hidraw.rules ]] || fail 'udev remove dry-run modified root'
"$repo/scripts/remove-udev-rule" --root "$root" --no-reload >/dev/null
[[ ! -e $root/etc/udev/rules.d/60-spacemouse-hidraw.rules ]] || fail 'udev remove'
compgen -G "$root/etc/udev/rules.d/60-spacemouse-hidraw.rules.removed.*" >/dev/null || fail 'udev removal backup'
pass 'udev install, backup, remove, and dry-run roundtrip'

symlink_root=$tmp/symlink-root
mkdir -p "$symlink_root/etc/udev/rules.d" "$tmp/outside"
ln -s "$tmp/outside/rule" "$symlink_root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
expect_failure "$repo/scripts/install-udev-rule" --root "$symlink_root" --no-reload
expect_failure "$repo/scripts/remove-udev-rule" --root "$symlink_root" --no-reload
pass 'udev symlink defenses'

xml_validator=${SPACEMOUSE_XMLLINT:-}
if [[ -z $xml_validator ]]; then
  xml_validator=$(command -v xmllint || true)
fi
[[ -x $xml_validator ]] || fail 'xmllint is required for profile tests'
export SPACEMOUSE_XMLLINT=$xml_validator
profile=$tmp/layout_test.xml
mappings=$tmp/mappings
mkdir -p "$mappings"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<ActionMaps profileName="test" />' >"$profile"
"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" --dry-run >/dev/null
[[ ! -e $mappings/layout_test.xml ]] || fail 'profile dry-run modified target'
"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" >/dev/null
cmp -s "$profile" "$mappings/layout_test.xml" || fail 'profile install'
printf 'old profile\n' >"$mappings/layout_test.xml"
"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" >/dev/null
compgen -G "$mappings/layout_test.xml.backup.*" >/dev/null || fail 'profile backup'
grep -qx 'old profile' "$mappings"/layout_test.xml.backup.* || fail 'profile backup content'
"$repo/scripts/star-citizen-remove-profile" --profile "$mappings/layout_test.xml" --dry-run >/dev/null
[[ -e $mappings/layout_test.xml ]] || fail 'profile remove dry-run modified target'
"$repo/scripts/star-citizen-remove-profile" --profile "$mappings/layout_test.xml" >/dev/null
[[ ! -e $mappings/layout_test.xml ]] || fail 'profile remove'
compgen -G "$mappings/layout_test.xml.removed.*" >/dev/null || fail 'profile removal backup'
ln -s "$tmp/outside/profile" "$mappings/layout_test.xml"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings"
expect_failure "$repo/scripts/star-citizen-remove-profile" --profile "$mappings/layout_test.xml"
pass 'profile install, backup, remove, dry-run, and symlink defenses'

prefix=$tmp/prefix
mkdir -p "$prefix/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user/client/0/controls/mappings"
finder_output=$("$repo/scripts/star-citizen-find-installation" --prefix "$prefix")
grep -q '^GAME_ROOT=' <<<"$finder_output" || fail 'bounded installation finder'
grep -q '^MAPPINGS_DIR=' <<<"$finder_output" || fail 'bounded mappings finder'
"$repo/scripts/star-citizen-find-installation" --prefix "$prefix" --dry-run >/dev/null
pass 'bounded installation finder'

if command -v shellcheck >/dev/null; then
  shellcheck "$repo"/scripts/* "$repo/tests/run.sh"
  pass 'shellcheck'
else
  printf 'SKIP: shellcheck not installed\n'
fi

if command -v shfmt >/dev/null; then
  shfmt -d "$repo"/scripts/* "$repo/tests/run.sh"
  pass 'shfmt check'
else
  printf 'SKIP: shfmt not installed\n'
fi

if command -v nix-instantiate >/dev/null; then
  nix-instantiate --parse "$repo/modules/nixos/spacemouse.nix" >/dev/null
  pass 'Nix syntax'
fi

if rg -l --hidden -g '!.git/**' -i '[h]y3|[h]y_v3|[h]unyuan' "$repo" | grep -q .; then
  fail 'forbidden retired-model source found'
fi
private_user='enrico''w79'
private_path_pattern="/home/$private_user|/home/[^/]+/Games/[^[:space:]]*/StarCitizen"
if rg -l --hidden -g '!.git/**' "$private_path_pattern" "$repo" | grep -q .; then
  fail 'private path found'
fi
if find "$repo/profiles" -type f -name '*.xml' -print -quit | grep -q .; then
  fail 'untested public profile found'
fi
if rg -l 'MODE="0666"|setfacl|GROUP=' "$repo/udev" "$repo/modules" "$repo/scripts" | grep -q .; then
  fail 'unsafe permission mechanism found'
fi
pass 'privacy, profile, retired-model, and unsafe-permission scans'

printf 'ALL_TESTS_PASSED=YES\n'
