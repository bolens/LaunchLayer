#!/usr/bin/env bash
# Unit tests for lib/keys.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "known_config_key accepts INCLUDE and core keys" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys
		known_config_key INCLUDE && known_config_key GAMEMODE && known_config_key MANGOHUD
		echo all-known
	'
	[[ $status -eq 0 ]]
	[[ "$output" == all-known ]]
}

@test "known_config_key accepts proton and wine prefixes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys
		known_config_key PROTON_USE_WINED3D && known_config_key WINEPREFIX && known_config_key __GL_SYNC_TO_VBLANK
		echo all-known
	'
	[[ $status -eq 0 ]]
	[[ "$output" == all-known ]]
}

@test "known_config_key rejects unknown keys" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys
		known_config_key TOTALLY_FAKE_KEY && echo known || echo unknown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == unknown ]]
}
