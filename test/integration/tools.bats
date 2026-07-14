#!/usr/bin/env bash
# Integration tests for optional tool hints and launch chain building.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

teardown() {
	bats_integration_teardown
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
		source_lib platform runtime
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		GAMEMODE=1 GAMESCOPE=1 MANGOHUD=1
		launch=()
		build_launch_chain
		echo "count:${#launch[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == count:0 ]]
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

@test "tool install hint for dlss-swapper on pacman" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		detect_package_manager() { echo pacman; }
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		tool_install_hint dlss-swapper
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cachyos-settings"* ]]
}

@test "warn_enabled_missing_tools reports DLSS_SWAPPER" {
	run bash -c '
		export CONFIG_DIR="'"$REPO_ROOT/"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$REPO_ROOT/lib/tools.sh"'"
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		detect_package_manager() { echo pacman; }
		detect_gpu_vendor() { echo nvidia; }
		detect_audio_server() { echo pulse; }
		has_systemd_user() { return 1; }
		GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 NETWORK_TUNE=0
		PIPEWIRE_LOW_LATENCY=0 NVIDIA_POWER_MODE=0 GPU_POWER_CHECK=0 VRAM_HOGS=0
		DISABLE_CPU_AFFINITY=1 LAUNCH_WRAPPERS= LAUNCH_WRAPPERS_BEFORE=
		DLSS_SWAPPER=1
		warn_enabled_missing_tools 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"DLSS_SWAPPER=1 but dlss-swapper is not installed"* ]]
}
