#!/usr/bin/env bash
# Unit tests for lib/runtime/summary.sh effective-config reporting.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "for_each_effective_setting invokes callback only for set summary keys" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMEMODE=1
		export VRAM_HOGS=1
		unset MANGOHUD NETWORK_TUNE
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime keys config
		declare -gA config_key_sources=([GAMEMODE]=launch.d/default.env [VRAM_HOGS]=games/42424242.env)
		_count_cb() { printf "key:%s val:%s src:%s\n" "$1" "$2" "$3"; }
		for_each_effective_setting _count_cb
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"key:GAMEMODE val:1"* ]]
	[[ "$output" == *"key:VRAM_HOGS val:1"* ]]
	[[ "$output" != *"key:MANGOHUD"* ]]
	[[ "$output" != *"key:NETWORK_TUNE"* ]]
}

@test "print_effective_config_summary prints key value and source path" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMEMODE=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime keys config
		declare -gA config_key_sources=([GAMEMODE]=launch.d/default.env)
		print_effective_config_summary
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Effective settings:"* ]]
	[[ "$output" == *"GAMEMODE=1"* ]]
	[[ "$output" == *"default.env"* ]]
}
