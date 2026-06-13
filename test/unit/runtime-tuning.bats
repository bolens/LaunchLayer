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
