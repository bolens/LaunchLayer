#!/usr/bin/env bash
# Integration tests for optional tool hints and launch chain building.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

@test "warn_enabled_missing_tools reports gamescope" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		optional_tool_installed() { [[ "$1" != gamescope ]]; }
		detect_package_manager() { echo pacman; }
		GAMESCOPE=1
		warn_enabled_missing_tools 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMESCOPE=1 but gamescope is not installed"* ]]
	[[ "$output" == *"pacman"* ]]
}

@test "build_launch_chain skips missing wrappers safely" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		source "'"$REPO_ROOT/lib/runtime.sh"'"
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		GAMEMODE=1 GAMESCOPE=1 MANGOHUD=1
		launch=()
		build_launch_chain
		(( ${#launch[@]} == 0 ))
	'
	[[ $status -eq 0 ]]
}

@test "tool install hint for gamemoderun" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		detect_package_manager() { echo pacman; }
		optional_tool_installed() { return 1; }
		tool_install_hint gamemoderun
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"pacman"* ]]
	[[ "$output" == *"gamemode"* ]]
}
