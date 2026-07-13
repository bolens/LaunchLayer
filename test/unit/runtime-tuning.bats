#!/usr/bin/env bash
# Unit tests for lib/runtime/tuning.sh network and audio helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "apply_network_tuning is no-op when NETWORK_TUNE is disabled" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NETWORK_TUNE=0
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime tools platform
		sudo() { echo unexpected-sudo; return 0; }
		apply_network_tuning
		echo done
	'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected-sudo"* ]]
}

@test "apply_network_tuning warns when passwordless sudo is unavailable" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NETWORK_TUNE=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime tools platform
		require_tool_or_skip() { return 0; }
		command_available() { return 0; }
		detect_default_nic() { echo eth0; }
		sudo() { return 1; }
		apply_network_tuning 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"NETWORK_TUNE=1 skipped: sudo requires a password"* ]]
}

@test "restore_pipewire_low_latency resets pipewire quantum via pw-metadata" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export PIPEWIRE_LOW_LATENCY=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime tools platform
		detect_audio_server() { echo pipewire; }
		optional_tool_installed() { [[ "$1" == pw-metadata ]]; }
		pw-metadata() { printf "pw-metadata %s\n" "$*"; return 0; }
		restore_pipewire_low_latency
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"pw-metadata -n settings 0 clock.force-quantum 0"* ]]
}

@test "find_malloc_library detects library under MALLOC_LIBRARY_SEARCH_ROOT" {
	local tmp
	tmp="$(mktemp -d)"
	touch "$tmp/libjemalloc.so"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export MALLOC_LIBRARY_SEARCH_ROOT="'"$tmp"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime platform tools
		find_malloc_library jemalloc
	'
	local st=$status out=$output
	rm -rf "$tmp"
	[[ $st -eq 0 ]]
	[[ "$out" == "$tmp/libjemalloc.so" ]]
}

@test "detect_hdr_support returns 0 by default when tools absent" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime platform tools
		command_available() { return 1; }
		detect_hdr_support
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "0" ]]
}

@test "apply_override_proton rewrites proton path in argv" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/GE-Proton"
	touch "$tmp/GE-Proton/proton"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export OVERRIDE_PROTON="'"$tmp"'/GE-Proton/proton"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		warn() { :; }
		debug() { :; }
		args=("/old/steam/proton" "run" "game.exe")
		apply_override_proton args
		printf "%s\n" "${args[@]}"
	'
	local st=$status out=$output
	rm -rf "$tmp"
	[[ $st -eq 0 ]]
	[[ "$out" == *"$tmp/GE-Proton/proton"* ]]
	[[ "$out" != *"/old/steam/proton"* ]]
}

@test "resolve_block_device_name maps nvme partition via lsblk PKNAME" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/block/nvme0n1"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_SYSFS_BLOCK="'"$tmp"'/block"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime platform tools
		lsblk() {
			[[ "$1" == "-ndo" && "$2" == "PKNAME" ]] || return 1
			echo "nvme0n1"
		}
		# Device path need not exist for basename; skip readlink-f failure by using a real tempfile
		dev="$(mktemp)"
		# Force basename path: create a fake node name via symlink
		ln -sf /dev/null "'"$tmp"'/nvme0n1p2"
		resolve_block_device_name "'"$tmp"'/nvme0n1p2"
		rm -f "$dev"
	'
	local st=$status out=$output
	rm -rf "$tmp"
	[[ $st -eq 0 ]]
	[[ "$out" == "nvme0n1" ]]
}

@test "resolve_block_device_name keeps whole-disk nvme names" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/block/nvme0n1"
	touch "$tmp/nvme0n1"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_SYSFS_BLOCK="'"$tmp"'/block"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime platform tools
		lsblk() { return 1; }
		resolve_block_device_name "'"$tmp"'/nvme0n1"
	'
	local st=$status out=$output
	rm -rf "$tmp"
	[[ $st -eq 0 ]]
	[[ "$out" == "nvme0n1" ]]
}
