#!/usr/bin/env bash

# shellcheck disable=SC2034
SPACEMOUSE_MAX_XML_BYTES=2097152

spacemouse_require_canonical_regular_file() {
	local path=$1
	local label=$2
	local max_bytes=${3:-0}
	local canonical size
	[[ $path == /* && -f $path && ! -L $path && -r $path ]] || {
		printf '%s must be an absolute readable regular non-symlink file.\n' "$label" >&2
		return 1
	}
	canonical=$(realpath -e -- "$path") || return 1
	[[ $canonical == "$path" ]] || {
		printf '%s must be canonical and contain no symlink traversal.\n' "$label" >&2
		return 1
	}
	if ((max_bytes > 0)); then
		size=$(stat -c '%s' -- "$path") || return 1
		((size <= max_bytes)) || {
			printf '%s exceeds the %d-byte limit.\n' "$label" "$max_bytes" >&2
			return 1
		}
	fi
}

spacemouse_require_single_link() {
	local path=$1
	local label=$2
	[[ $(stat -c '%h' -- "$path") -eq 1 ]] || {
		printf '%s must not be hard-linked.\n' "$label" >&2
		return 1
	}
}

spacemouse_validate_utf8_text() {
	local path=$1
	local max_bytes=$2
	python3 -c '
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
if len(data) > int(sys.argv[2]) or b"\0" in data:
    raise SystemExit(1)
data.decode("utf-8", "strict")
' "$path" "$max_bytes" >/dev/null 2>&1
}

spacemouse_test_failpoint() {
	local point=$1
	[[ ${SPACEMOUSE_TEST_MODE:-0} == 1 && ${SPACEMOUSE_FAILPOINT:-} == "$point" ]] || return 0
	case ${SPACEMOUSE_FAIL_SIGNAL:-} in
	INT | TERM | HUP)
		kill -s "$SPACEMOUSE_FAIL_SIGNAL" "$BASHPID"
		return 1
		;;
	'') ;;
	*)
		printf 'Unsupported injected signal.\n' >&2
		return 1
		;;
	esac
	printf 'Injected test failure at %s.\n' "$point" >&2
	return 1
}
