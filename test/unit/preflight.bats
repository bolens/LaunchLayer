#!/usr/bin/env bash
# Unit tests for lib/preflight.sh cache reporting helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "print_cache_dirs_text shows none for empty entries" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		shader_cache_entries=()
		compatdata_entries=()
		print_cache_dirs_text
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Shader cache:"* ]]
	[[ "$output" == *"(none)"* ]]
}

@test "print_cache_dirs_text formats byte sizes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		shader_cache_entries=("/tmp/shader|1073741824")
		compatdata_entries=()
		print_cache_dirs_text
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"/tmp/shader"* ]]
	[[ "$output" == *"1GB"* ]]
}
