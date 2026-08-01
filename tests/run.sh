#!/usr/bin/env bash
set -Eeuo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
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
fake_sys=$tmp/sys
mkdir -p \
	"$fake_dev/input" \
	"$wrong_dev" \
	"$missing_dev" \
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
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$wrong_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-verify-access" --dev-root "$wrong_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-detect" --dev-root "$missing_dev" --sys-root "$fake_sys"
expect_failure env PATH="$test_path" "$repo/scripts/spacemouse-verify-access" --dev-root "$missing_dev" --sys-root "$fake_sys"
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

mapfile -d '' shell_sources < <(find "$repo/scripts" "$repo/tests" -type f -print0)
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
