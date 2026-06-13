#!/usr/bin/env bash
# Unit tests for lib/platform/profiles.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "detect_os_profile maps arch family" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		detect_os_family() { echo arch; }
		detect_os_profile
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "arch-linux" ]]
}

@test "profile_list_contains finds profile in list" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		profile_list_contains "arch-linux nvidia-desktop" nvidia-desktop && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]

	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		profile_list_contains "arch-linux" nvidia-desktop && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == no ]]
}

@test "detect_default_profiles honors LAUNCHLAYER_PROFILES override" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_PROFILES=custom-profile,other-profile
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		detect_default_profiles
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "custom-profile other-profile" ]]
}

@test "detect_default_profile returns first auto profile" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_PROFILES=alpha beta
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		detect_default_profile
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "alpha" ]]
}
