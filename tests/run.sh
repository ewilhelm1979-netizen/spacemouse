#!/usr/bin/env bash
set -Eeuo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
tmp=$(realpath -e -- "$tmp")
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

mapfile -d '' executable_scripts < <(find "$repo/scripts" -maxdepth 1 -type f -print0)
for script in "${executable_scripts[@]}"; do
	[[ -x $script ]] || fail "not executable: $script"
	"$script" --help >/dev/null
done
"$repo/scripts/spacemouse-detect" --dry-run >/dev/null
"$repo/scripts/spacemouse-verify-access" --dry-run >/dev/null
pass 'help and hardware dry-run paths'

fake_dev=$tmp/dev
wrong_dev=$tmp/dev-wrong-product
missing_dev=$tmp/dev-missing-ancestor
deep_dev=$tmp/dev-deep-ancestor
fake_sys=$tmp/sys
mkdir -p \
	"$fake_dev/input" \
	"$wrong_dev" \
	"$missing_dev" \
	"$deep_dev" \
	"$fake_sys/devices/pci0000:00/usb1/1-1/1-1:1.0/hidraw/hidraw0" \
	"$fake_sys/devices/pci0000:00/usb1/1-1/1-1:1.0/input/input0/event0" \
	"$fake_sys/devices/pci0000:00/usb1/1-1/1-1:1.0/input/input0/js0" \
	"$fake_sys/devices/pci0000:00/usb1/1-1/1-1:1.1/hidraw/hidraw3" \
	"$fake_sys/devices/pci0000:00/usb1/1-2/1-2:1.0/hidraw/hidraw1" \
	"$fake_sys/devices/platform/no-usb/hidraw/hidraw2"
printf '256F\n' >"$fake_sys/devices/pci0000:00/usb1/1-1/idVendor"
printf 'C63A\n' >"$fake_sys/devices/pci0000:00/usb1/1-1/idProduct"
printf '256f\n' >"$fake_sys/devices/pci0000:00/usb1/1-2/idVendor"
printf 'dead\n' >"$fake_sys/devices/pci0000:00/usb1/1-2/idProduct"
touch "$fake_dev/hidraw0" "$fake_dev/input/event0" "$fake_dev/input/js0"
touch "$wrong_dev/hidraw1" "$missing_dev/hidraw2"
deep_path=$fake_sys/devices/pci0000:00/usb1/1-9
printf -v deep_suffix '/level-%s' {1..33}
deep_path+=$deep_suffix
mkdir -p "$deep_path/hidraw/hidraw4"
printf '256f\n' >"$fake_sys/devices/pci0000:00/usb1/1-9/idVendor"
printf 'c63a\n' >"$fake_sys/devices/pci0000:00/usb1/1-9/idProduct"
touch "$deep_dev/hidraw4"
test_path=$repo/tests/fixtures:$PATH
fixture_properties=$(PATH=$test_path udevadm info --query=property --name "$fake_dev/hidraw0")
if grep -Eq '^ID_(VENDOR|MODEL)_ID=' <<<"$fixture_properties"; then
	fail 'udev fixture unexpectedly exposes USB ID properties'
fi
detect_output=$(PATH=$test_path "$repo/scripts/spacemouse-detect" --dev-root "$fake_dev" --sys-root "$fake_sys")
grep -qx 'MATCHING_NODES=3' <<<"$detect_output" || fail 'USB ancestor detect count'
grep -qx 'MATCHING_HIDRAW_NODES=1' <<<"$detect_output" || fail 'USB ancestor hidraw count'
verify_output=$(PATH=$test_path "$repo/scripts/spacemouse-verify-access" --dev-root "$fake_dev" --sys-root "$fake_sys")
grep -qx 'CURRENT_USER_RW=YES' <<<"$verify_output" || fail 'USB ancestor access verification'
grep -qx 'CURRENT_USER_READ=YES' <<<"$verify_output" || fail 'effective read access reporting'
grep -qx 'CURRENT_USER_WRITE=YES' <<<"$verify_output" || fail 'effective write access reporting'
grep -Eq '^MODE=[0-7]{3,4} OWNER=[^:]+:[^[:space:]]+$' <<<"$verify_output" || fail 'mode, owner, and group reporting'
if command -v getfacl >/dev/null; then
	grep -q '^user::' <<<"$verify_output" || fail 'ACL reporting'
fi
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$wrong_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-verify-access" --dev-root "$wrong_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$missing_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-verify-access" --dev-root "$missing_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$deep_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$fake_dev" --sys-root "$fake_sys" --vendor 0000
chmod 0400 "$fake_dev/hidraw0"
access_output=
if access_output=$(PATH=$test_path "$repo/scripts/spacemouse-verify-access" --dev-root "$fake_dev" --sys-root "$fake_sys" 2>&1); then
	fail 'read-only HIDRAW fixture unexpectedly passed read/write access verification'
fi
grep -qx 'CURRENT_USER_READ=YES' <<<"$access_output" || fail 'read-only fixture lost readable status'
grep -qx 'CURRENT_USER_WRITE=NO' <<<"$access_output" || fail 'read-only fixture did not report denied write access'
chmod 0600 "$fake_dev/hidraw0"
touch "$fake_dev/hidraw3"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-verify-access" --dev-root "$fake_dev" --sys-root "$fake_sys"
pass 'bounded USB ancestor detection without USB ID properties'

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
"$repo/scripts/remove-udev-rule" --root "$root" --no-reload >/dev/null
pass 'udev install, backup, remove, and dry-run roundtrip'

symlink_root=$tmp/symlink-root
mkdir -p "$symlink_root/etc/udev/rules.d" "$tmp/outside"
ln -s "$tmp/outside/rule" "$symlink_root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
expect_failure "$repo/scripts/install-udev-rule" --root "$symlink_root" --no-reload
expect_failure "$repo/scripts/remove-udev-rule" --root "$symlink_root" --no-reload
directory_symlink_root=$tmp/directory-symlink-root
mkdir -p "$directory_symlink_root/etc/udev" "$directory_symlink_root/real-rules"
ln -s "$directory_symlink_root/real-rules" "$directory_symlink_root/etc/udev/rules.d"
expect_failure "$repo/scripts/install-udev-rule" --root "$directory_symlink_root" --no-reload
special_root=$tmp/special-root
mkdir -p "$special_root/etc/udev/rules.d"
mkfifo "$special_root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
expect_failure "$repo/scripts/install-udev-rule" --root "$special_root" --no-reload
expect_failure "$repo/scripts/remove-udev-rule" --root "$special_root" --no-reload
expect_failure "$repo/scripts/install-udev-rule" --root relative --no-reload
expect_failure "$repo/scripts/install-udev-rule" --root "$root/../root" --no-reload
if ((EUID != 0)); then
	expect_failure "$repo/scripts/install-udev-rule" --root / --no-reload
fi
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
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
	'<ActionMaps profileName="test"><CustomisationUIHeader label="test" /></ActionMaps>' >"$profile"
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
"$repo/scripts/star-citizen-remove-profile" --mappings-dir "$mappings" --name layout_test.xml >/dev/null
ln -s "$tmp/outside/profile" "$mappings/layout_test.xml"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings"
expect_failure "$repo/scripts/star-citizen-remove-profile" --profile "$mappings/layout_test.xml"
rm -- "$mappings/layout_test.xml"
pass 'profile install, backup, remove, dry-run, and symlink defenses'

prefix=$tmp/prefix
mkdir -p "$prefix/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user/client/0/controls/mappings"
finder_output=$("$repo/scripts/star-citizen-find-installation" --prefix "$prefix")
grep -q '^GAME_ROOT=' <<<"$finder_output" || fail 'bounded installation finder'
grep -q '^MAPPINGS_DIR=' <<<"$finder_output" || fail 'bounded mappings finder'
"$repo/scripts/star-citizen-find-installation" --prefix "$prefix" --dry-run >/dev/null
explicit_game=$tmp/explicit-game
mkdir -p "$explicit_game/LIVE/user/client/0/controls/mappings"
duplicate_output=$("$repo/scripts/star-citizen-find-installation" \
	--game-root "$explicit_game" --game-root "$explicit_game")
[[ $(grep -c '^GAME_ROOT=' <<<"$duplicate_output") -eq 1 ]] || fail 'finder did not deduplicate explicit candidates'

finder_home=$tmp/finder-home
wine_prefix=$tmp/wine-prefix
lutris_prefix=$tmp/lutris-prefix
umu_prefix=$tmp/umu-prefix
steam_compat=$tmp/steam-compat
mkdir -p "$finder_home"
known_prefixes=(
	"$finder_home/Games/rsi-launcher"
	"$finder_home/Games/nix-citizen"
	"$finder_home/Games/star-citizen"
	"$finder_home/.wine"
	"$finder_home/.local/share/lug-helper/rsi-launcher"
	"$wine_prefix"
	"$lutris_prefix"
	"$umu_prefix"
	"$steam_compat/pfx"
)
for known_prefix in "${known_prefixes[@]}"; do
	mkdir -p "$known_prefix/drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/user/client/0/controls/mappings"
done
known_output=$(env HOME="$finder_home" WINEPREFIX="$wine_prefix" LUTRIS_PREFIX="$lutris_prefix" \
	UMU_PREFIX="$umu_prefix" STEAM_COMPAT_DATA_PATH="$steam_compat" \
	"$repo/scripts/star-citizen-find-installation")
for known_prefix in "${known_prefixes[@]}"; do
	grep -Fqx "GAME_ROOT=$known_prefix/drive_c/Program Files/Roberts Space Industries/StarCitizen" \
		<<<"$known_output" || fail "known finder candidate missing: $known_prefix"
done
inaccessible=$tmp/inaccessible-prefix
mkdir -p "$inaccessible"
chmod 000 "$inaccessible"
if [[ ! -r $inaccessible ]]; then
	expect_failure "$repo/scripts/star-citizen-find-installation" --prefix "$inaccessible"
fi
chmod 700 "$inaccessible"
if rg -n 'find[[:space:]].*(\$HOME|/)[[:space:]]' "$repo/scripts/star-citizen-find-installation" >/dev/null; then
	fail 'installation finder contains a broad home or root scan'
fi
pass 'bounded installation finder'

printf '%s\n' "$expected_rule" >"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
"$repo/scripts/install-udev-rule" --root "$root" --no-reload >/dev/null
valid_rule_backup=
while IFS= read -r candidate_backup; do
	[[ $(<"$candidate_backup") == "$expected_rule" ]] && valid_rule_backup=$candidate_backup
done < <(find "$root/etc/udev/rules.d" -maxdepth 1 -type f \
	-name '60-spacemouse-hidraw.rules.backup.*' -print | sort)
[[ -n $valid_rule_backup ]] || fail 'valid Udev backup was not created'
printf 'changed\n' >"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
"$repo/scripts/install-udev-rule" --root "$root" --restore-backup "$valid_rule_backup" --no-reload >/dev/null
[[ $(<"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules") == "$expected_rule" ]] || fail 'Udev restore from backup'

printf 'original rule\n' >"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
for point in before-validation after-validation after-backup during-candidate-write before-rename after-rename; do
	expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT="$point" \
		"$repo/scripts/install-udev-rule" --root "$root" --no-reload
	[[ $(<"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules") == 'original rule' ]] ||
		fail "Udev failure at $point did not preserve or restore the original"
	if find "$root/etc/udev/rules.d" -maxdepth 1 -name '*.tmp.*' -print -quit | grep -q .; then
		fail "Udev failure at $point left a temporary file"
	fi
done
for signal in INT TERM HUP; do
	expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=after-rename \
		SPACEMOUSE_FAIL_SIGNAL="$signal" "$repo/scripts/install-udev-rule" --root "$root" --no-reload
	[[ $(<"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules") == 'original rule' ]] ||
		fail "Udev $signal interruption changed the original"
done

expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=before-rename \
	SPACEMOUSE_CLEANUP_FAILPOINT=during-cleanup \
	"$repo/scripts/install-udev-rule" --root "$root" --no-reload
[[ $(<"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules") == 'original rule' ]] ||
	fail 'Udev cleanup failure changed the original'
udev_backups_before=$(find "$root/etc/udev/rules.d" -maxdepth 1 -name '*.backup.*' | wc -l)
expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=after-rename \
	SPACEMOUSE_CLEANUP_FAILPOINT=during-rollback \
	"$repo/scripts/install-udev-rule" --root "$root" --no-reload
udev_backups_after=$(find "$root/etc/udev/rules.d" -maxdepth 1 -name '*.backup.*' | wc -l)
((udev_backups_after > udev_backups_before)) || fail 'Udev rollback failure lost recovery backup'
printf 'original rule\n' >"$root/etc/udev/rules.d/60-spacemouse-hidraw.rules"

hardlink_root=$tmp/hardlink-root
mkdir -p "$hardlink_root/etc/udev/rules.d"
printf 'outside\n' >"$hardlink_root/outside"
ln "$hardlink_root/outside" "$hardlink_root/etc/udev/rules.d/60-spacemouse-hidraw.rules"
expect_failure "$repo/scripts/install-udev-rule" --root "$hardlink_root" --no-reload
expect_failure "$repo/scripts/remove-udev-rule" --root "$hardlink_root" --no-reload
pass 'Udev restore, hardlink, failure-injection, and signal rollback defenses'

entity_profile=$tmp/layout_entity.xml
printf '%s\n' '<!DOCTYPE ActionMaps [<!ENTITY local SYSTEM "file:///etc/passwd">]>' \
	'<ActionMaps profileName="entity"><CustomisationUIHeader label="entity" />&local;</ActionMaps>' \
	>"$entity_profile"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$entity_profile" --mappings-dir "$mappings"
oversized_profile=$tmp/layout_oversized.xml
python3 - "$oversized_profile" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text(
    '<ActionMaps profileName="large"><CustomisationUIHeader label="large" />' +
    ('x' * 2100000) + '</ActionMaps>', encoding='utf-8')
PY
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$oversized_profile" --mappings-dir "$mappings"
malformed_profile=$tmp/layout_malformed.xml
printf '%s\n' '<ActionMaps profileName="broken"><CustomisationUIHeader label="broken"></ActionMaps>' >"$malformed_profile"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$malformed_profile" --mappings-dir "$mappings"
inconsistent_profile=$tmp/layout_inconsistent.xml
printf '%s\n' '<ActionMaps profileName="one"><CustomisationUIHeader label="two" /></ActionMaps>' >"$inconsistent_profile"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$inconsistent_profile" --mappings-dir "$mappings"
invalid_utf8_profile=$tmp/layout_invalid_utf8.xml
printf '\xff\0' >"$invalid_utf8_profile"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$invalid_utf8_profile" --mappings-dir "$mappings"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" \
	--name '../layout_escape.xml'
mapping_link=$tmp/mappings-link
ln -s "$mappings" "$mapping_link"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mapping_link"
mkfifo "$mappings/layout_special.xml"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" \
	--name layout_special.xml
expect_failure "$repo/scripts/star-citizen-remove-profile" --profile "$mappings/layout_special.xml"

printf 'original profile\n' >"$mappings/layout_test.xml"
for point in before-validation after-validation after-backup during-candidate-write before-rename after-rename; do
	expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT="$point" \
		"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings"
	[[ $(<"$mappings/layout_test.xml") == 'original profile' ]] ||
		fail "profile failure at $point did not preserve or restore the original"
	if find "$mappings" -maxdepth 1 -name '*.tmp.*' -print -quit | grep -q .; then
		fail "profile failure at $point left a temporary file"
	fi
done
for signal in INT TERM HUP; do
	expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=after-rename \
		SPACEMOUSE_FAIL_SIGNAL="$signal" "$repo/scripts/star-citizen-install-profile" \
		--profile "$profile" --mappings-dir "$mappings"
	[[ $(<"$mappings/layout_test.xml") == 'original profile' ]] ||
		fail "profile $signal interruption changed the original"
done

expect_failure env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=before-rename \
	SPACEMOUSE_CLEANUP_FAILPOINT=during-cleanup \
	"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings"
[[ $(<"$mappings/layout_test.xml") == 'original profile' ]] ||
	fail 'profile cleanup failure changed the original'
profile_rollback_output=
if profile_rollback_output=$(env SPACEMOUSE_TEST_MODE=1 SPACEMOUSE_FAILPOINT=after-rename \
	SPACEMOUSE_CLEANUP_FAILPOINT=during-rollback \
	"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" 2>&1); then
	fail 'profile rollback failure injection unexpectedly succeeded'
fi
grep -q 'Injected rollback failure' <<<"$profile_rollback_output" ||
	fail "profile rollback failure injection did not reach rollback: $profile_rollback_output"
grep -lqx 'original profile' "$mappings"/layout_test.xml.backup.* >/dev/null ||
	fail 'profile rollback failure lost the recoverable original backup'
printf 'original profile\n' >"$mappings/layout_test.xml"

hard_profile=$mappings/layout_hard.xml
printf 'outside profile\n' >"$tmp/outside-profile"
ln "$tmp/outside-profile" "$hard_profile"
expect_failure "$repo/scripts/star-citizen-install-profile" --profile "$profile" \
	--mappings-dir "$mappings" --name layout_hard.xml
expect_failure "$repo/scripts/star-citizen-remove-profile" --profile "$hard_profile"

cp -- "$profile" "$mappings/layout_restore.xml"
"$repo/scripts/star-citizen-install-profile" --profile "$profile" --mappings-dir "$mappings" \
	--name layout_restore.xml >/dev/null
valid_profile_backup=$(find "$mappings" -maxdepth 1 -type f -name 'layout_restore.xml.backup.*' -print | sort | tail -n 1)
[[ -n $valid_profile_backup ]] || fail 'valid profile backup was not created'
printf 'changed\n' >"$mappings/layout_restore.xml"
"$repo/scripts/star-citizen-install-profile" --restore-backup "$valid_profile_backup" \
	--mappings-dir "$mappings" --name layout_restore.xml >/dev/null
cmp -s "$profile" "$mappings/layout_restore.xml" || fail 'profile restore from backup'
pass 'profile XXE, size, hardlink, restore, failure-injection, and signal defenses'

noncanonical_game=$tmp/game-root
mkdir -p "$noncanonical_game"
expect_failure "$repo/scripts/star-citizen-find-installation" --game-root "$tmp/./game-root"
ln -s "$prefix" "$tmp/prefix-link"
expect_failure "$repo/scripts/star-citizen-find-installation" --prefix "$tmp/prefix-link"
pass 'installation finder canonical-path and symlink rejection'

python3 "$repo/tests/property_fuzz.py"

mapfile -d '' shell_sources < <(find "$repo/scripts" "$repo/tests" -type f ! -name '*.py' -print0)
bash -n "${shell_sources[@]}"
pass 'Bash syntax'

if command -v shellcheck >/dev/null; then
	shellcheck -x "${shell_sources[@]}"
	pass 'shellcheck'
else
	printf 'SKIP: shellcheck not installed\n'
fi

if command -v shfmt >/dev/null; then
	shfmt -d "${shell_sources[@]}"
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
expected_profile_name=layout_spacemouse_linux_usb_v1_exported.xml
expected_profile="$repo/profiles/star-citizen/$expected_profile_name"
expected_profile_hash=f76f84c085702a0aca2a0ae174f9ac2fc8d4221dbf2f6d051e9bd4820ec4c5db
mapfile -d '' public_profiles < <(find "$repo/profiles" -type f -name '*.xml' -print0)
[[ ${#public_profiles[@]} -eq 1 ]] || fail 'unexpected number of public profiles'
[[ ${public_profiles[0]} == "$expected_profile" ]] || fail 'unexpected public profile'
read -r actual_profile_hash _ < <(sha256sum "$expected_profile")
[[ $actual_profile_hash == "$expected_profile_hash" ]] || fail 'public profile checksum'
[[ $(<"$repo/profiles/star-citizen/SHA256SUMS") == "$expected_profile_hash  $expected_profile_name" ]] || fail 'SHA256SUMS content'
(cd "$repo/profiles/star-citizen" && sha256sum -c SHA256SUMS >/dev/null) || fail 'SHA256SUMS verification'
"$xml_validator" --noout "$expected_profile"
[[ $("$xml_validator" --xpath 'string(/ActionMaps/@profileName)' "$expected_profile") == spacemouse_linux_usb_v1 ]] || fail 'public profile name'
[[ $("$xml_validator" --xpath 'string(/ActionMaps/CustomisationUIHeader/@label)' "$expected_profile") == spacemouse_linux_usb_v1 ]] || fail 'public profile label'
if rg -ni '<![[:space:]]*(DOCTYPE|ENTITY)' "$expected_profile" >/dev/null; then
	fail 'public profile contains a document type or entity declaration'
fi
profile_delta=$(
	python3 - "$expected_profile" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
for action_map in root.findall('actionmap'):
    for action in action_map.findall('action'):
        for rebind in action.findall('rebind'):
            print(f"{action_map.get('name')}:{action.get('name')}={rebind.get('input')}")
PY
)
expected_delta=$(printf '%s\n' \
	'spaceship_movement:v_roll_left=js1_x' \
	'spaceship_movement:v_roll_right=js1_x' \
	'spaceship_movement:v_strafe_down=js1_ ' \
	'spaceship_movement:v_strafe_lateral=js1_x' \
	'spaceship_movement:v_strafe_left=js1_ ' \
	'spaceship_movement:v_strafe_right=js1_ ' \
	'spaceship_movement:v_strafe_up=js1_ ' \
	'spaceship_movement:v_strafe_vertical=js1_z')
[[ $profile_delta == "$expected_delta" ]] || fail 'public profile delta semantics changed'
if grep -Eiq '<rebind[^>]+input="(kb|mouse|js[2-9])|notification|weapon|fire' "$expected_profile"; then
	fail 'public profile contains a forbidden or foreign-controller rebind'
fi
[[ $("$xml_validator" --xpath 'string(/ActionMaps/options[@type="joystick"]/flight_move_strafe_vertical/@invert)' "$expected_profile") == 1 ]] ||
	fail 'public profile vertical inversion'
if rg -l 'MODE="0666"|setfacl|GROUP=' "$repo/udev" "$repo/modules" "$repo/scripts" | grep -q .; then
	fail 'unsafe permission mechanism found'
fi
if rg -n -- '--profile[[:space:]]+(\./)?profiles/' "$repo/README.md" "$repo/docs" "$repo/profiles" >/dev/null; then
	fail 'relative documented profile path found'
fi
for doc in "$repo/README.md" "$repo/docs/star-citizen.md" "$repo/profiles/star-citizen/README.md"; do
	rg -F -- '--profile "$PWD/profiles/star-citizen/layout_spacemouse_linux_usb_v1_exported.xml' "$doc" >/dev/null ||
		fail "absolute profile example missing: $doc"
done

read_markdown_section() {
	local file=$1
	local heading=$2
	local line
	local in_section=0
	local found=0

	while IFS= read -r line; do
		if ((in_section)) && [[ $line == '## '* ]]; then
			break
		fi
		if [[ $line == "$heading" ]]; then
			in_section=1
			found=1
		fi
		if ((in_section)); then
			printf '%s\n' "$line"
		fi
	done <"$file"

	((found))
}

markdown_heading_is_visible() {
	local file=$1
	local heading=$2
	local line
	local lower
	local in_comment=0
	local in_details=0
	local found=0

	while IFS= read -r line; do
		lower=${line,,}
		[[ $lower == *'<!--'* ]] && in_comment=1
		[[ $lower == *'<details'* ]] && in_details=1
		if [[ $line == "$heading" ]]; then
			((in_comment == 0 && in_details == 0)) || return 1
			found=1
		fi
		[[ $lower == *'-->'* ]] && in_comment=0
		[[ $lower == *'</details>'* ]] && in_details=0
	done <"$file"

	((found))
}

readme=$repo/README.md
contributing=$repo/CONTRIBUTING.md
disclosure_heading='## AI-assisted development'
expected_disclosure=$(printf '%s\n' \
	"$disclosure_heading" \
	'' \
	'This project was developed with substantial assistance from OpenAI Codex.' \
	'The human maintainer remains responsible for architecture, implementation' \
	'review, security decisions, testing, licensing, provenance, and releases.')
[[ $(grep -Fxc "$disclosure_heading" "$readme") -eq 1 ]] || fail 'AI disclosure heading'
if ! disclosure=$(read_markdown_section "$readme" "$disclosure_heading"); then
	fail 'AI disclosure section missing'
fi
[[ $disclosure == "$expected_disclosure" ]] || fail 'AI disclosure wording changed'
markdown_heading_is_visible "$readme" "$disclosure_heading" || fail 'AI disclosure is hidden'
[[ $disclosure == *'OpenAI Codex'* ]] || fail 'OpenAI Codex disclosure'
[[ $disclosure == *'The human maintainer remains responsible'* ]] || fail 'human maintainer responsibility'
for responsibility in architecture security testing licensing provenance releases; do
	[[ $disclosure == *"$responsibility"* ]] || fail "missing disclosure responsibility: $responsibility"
done
pass 'visible AI assistance disclosure and human responsibility policy'

[[ -f $contributing ]] || fail 'CONTRIBUTING.md missing'
grep -Fq 'English is the mandatory language for all public repository content.' "$contributing" ||
	fail 'mandatory English repository policy'
grep -Fq 'Substantial AI assistance must be' "$contributing" || fail 'substantial AI disclosure policy'
grep -Fq 'disclosed in the contribution, issue, or pull request.' "$contributing" ||
	fail 'AI disclosure destination policy'
grep -Fq 'The human contributor or maintainer remains responsible for correctness,' "$contributing" ||
	fail 'human contribution responsibility policy'
pass 'English repository language and contribution responsibility policy'

pass 'privacy, tested-profile, documentation, retired-model, and unsafe-permission scans'

printf 'ALL_TESTS_PASSED=YES\n'
