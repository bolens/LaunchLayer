#!/usr/bin/env bash
# Unit tests for lib/platform helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "bytes_to_gb rounds up partial gigabytes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		bytes_to_gb $(( 600 * 1024 * 1024 ))
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "1" ]]
}

@test "timestamp_iso returns parseable timestamp" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		timestamp_iso
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "detect_uname_kernel returns lowercase kernel name" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		detect_uname_kernel
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^(linux|darwin|freebsd|openbsd|netbsd)$ ]]
}

@test "realpath_portable resolves existing path" {
	local tmp
	tmp="$(mktemp -d)"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		realpath_portable "'"$tmp"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp" ]]
	rm -rf "$tmp"
}

@test "nproc_portable returns positive cpu count" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		nproc_portable
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^[0-9]+$ ]]
	(( output > 0 ))
}

@test "is_linux matches current kernel family" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		kernel=$(detect_uname_kernel)
		if [[ "$kernel" == linux ]]; then
			is_linux && echo linux-yes || echo linux-no
		else
			is_linux && echo linux-yes || echo linux-no
		fi
	'
	[[ $status -eq 0 ]]
	kernel="$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"; source_lib platform; detect_uname_kernel')"
	if [[ "$kernel" == linux ]]; then
		[[ "$output" == linux-yes ]]
	else
		[[ "$output" == linux-no ]]
	fi
}

@test "resolve_proton_path resolves explicit proton paths" {
	local tmp
	tmp="$(mktemp -d)/proton"
	touch "$tmp"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		resolve_proton_path "'"$tmp"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp" ]]
	rm -rf "$(dirname "$tmp")"
}

