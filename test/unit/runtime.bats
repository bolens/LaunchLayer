#!/usr/bin/env bash
# Unit tests for lib/runtime.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "print_config_layers lists relative paths" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime keys config
		config_layers=("'$CONFIG_DIR'/launch.d/default.env" "'$CONFIG_DIR'/launch.d/presets/standard.env")
		print_config_layers
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Config layers:"* ]]
	[[ "$output" == *"default.env"* ]]
	[[ "$output" == *"presets/standard.env"* ]]
}

@test "run_pre_launch_cmd is no-op when unset" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		unset PRE_LAUNCH_CMD
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime
		run_pre_launch_cmd
	'
	[[ $status -eq 0 ]]
}

@test "run_pre_launch_cmd executes hook" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export PRE_LAUNCH_CMD="echo prelaunch-marker"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib runtime
		run_pre_launch_cmd
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"prelaunch-marker"* ]]
}

@test "printf_cache_path_bytes_json formats cache entries" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli platform
		entries=("/cache/shader|1073741824")
		printf_cache_path_bytes_json entries
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"/cache/shader"'* ]]
	[[ "$output" == *'"bytes":1073741824'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}
