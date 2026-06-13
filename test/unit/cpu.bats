#!/usr/bin/env bash
# Unit tests for lib/hardware/cpu.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "format_taskset_cpus collapses contiguous ranges" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hardware
		format_taskset_cpus 0 1 2 3 8 9
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "0-3,8-9" ]]
}

@test "format_taskset_cpus keeps singleton cpus" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hardware
		format_taskset_cpus 2 4 6
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "2,4,6" ]]
}

@test "format_taskset_cpus falls back when cpu list empty" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hardware
		default_online_cpus() { echo 0-7; }
		format_taskset_cpus
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "0-7" ]]
}
