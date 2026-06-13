#!/usr/bin/env bash
# Unit tests for lib/setup/sysctl.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "sysctl_required_value matches launchlayer default" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup platform
		sysctl_required_value
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "2147483642" ]]
}

@test "sysctl_status reports linux vm.max_map_count state" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_MAIN_SCRIPT=launchlayer
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup platform
		is_linux() { return 0; }
		sysctl_current_value() { echo 65530; }
		sysctl_status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"vm.max_map_count=65530"* ]]
	[[ "$output" == *"required >= 2147483642"* ]]
}

@test "sysctl_status is n/a on non-linux platforms" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup platform
		is_linux() { return 1; }
		detect_os_pretty_name() { echo "macOS"; }
		sysctl_status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"n/a"* ]]
}
