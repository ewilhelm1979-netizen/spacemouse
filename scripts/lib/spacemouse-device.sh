#!/usr/bin/env bash

# Read-only helpers shared by SpaceMouse detection and access verification.

spacemouse_canonical_root() {
	local root=$1
	local canonical

	[[ $root == /* && -d $root && ! -L $root ]] || return 1
	canonical=$(realpath -e -- "$root") || return 1
	[[ $canonical == "$root" ]] || return 1
	printf '%s\n' "$canonical"
}

spacemouse_node_is_safe() {
	local node=$1
	local dev_root=$2
	local canonical

	[[ $node == "$dev_root"/* && -e $node && ! -L $node ]] || return 1
	canonical=$(realpath -e -- "$node") || return 1
	[[ $canonical == "$node" && $canonical == "$dev_root"/* ]] || return 1

	if [[ $dev_root == /dev ]]; then
		[[ -c $node ]]
	else
		[[ -f $node ]]
	fi
}

spacemouse_usb_ancestor_matches() {
	local node=$1
	local vendor=${2,,}
	local product=${3,,}
	local sys_root=$4
	local udev_path
	local current
	local parent
	local found_vendor
	local found_product
	local depth

	udev_path=$(udevadm info --query=path --name "$node" 2>/dev/null) || return 1
	[[ $udev_path == /* && $udev_path != *$'\n'* ]] || return 1
	current=$(realpath -e -- "$sys_root$udev_path") || return 1
	[[ $current == "$sys_root"/* ]] || return 1

	for ((depth = 0; depth < 32; depth++)); do
		if [[ -f $current/idVendor && -r $current/idVendor &&
			-f $current/idProduct && -r $current/idProduct ]]; then
			found_vendor=$(tr -d '[:space:]' <"$current/idVendor")
			found_product=$(tr -d '[:space:]' <"$current/idProduct")
			found_vendor=${found_vendor,,}
			found_product=${found_product,,}
			if [[ $found_vendor == "$vendor" && $found_product == "$product" ]]; then
				return 0
			fi
		fi

		[[ $current != "$sys_root" ]] || break
		parent=$(dirname -- "$current")
		[[ $parent != "$current" && ($parent == "$sys_root" || $parent == "$sys_root"/*) ]] || break
		current=$parent
	done

	return 1
}
