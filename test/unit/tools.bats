#!/usr/bin/env bash
# Unit tests for lib/tools.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "optional_tool_relevant skips nvidia tools on non-nvidia GPUs" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		detect_gpu_vendor() { echo amd; }
		optional_tool_relevant nvidia-smi && echo relevant || echo skipped
	'
	[[ $status -eq 0 ]]
	[[ "$output" == skipped ]]
}

@test "optional_tool_relevant skips pw-metadata when not on pipewire" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		detect_audio_server() { echo pulse; }
		optional_tool_relevant pw-metadata && echo relevant || echo skipped
	'
	[[ $status -eq 0 ]]
	[[ "$output" == skipped ]]
}

@test "launch_wrapper_available game-performance requires game-performance binary" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { [[ "$1" == cpupower ]]; }
		optional_tool_installed game-performance && echo perf-installed || echo perf-missing
		launch_wrapper_available game-performance && echo wrapper-yes || echo wrapper-no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"perf-installed"* ]]
	[[ "$output" == *"wrapper-no"* ]]
}

@test "launch_wrapper_available gamemoderun matches optional_tool_installed" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_installed() { [[ "$1" == gamemoderun ]]; }
		launch_wrapper_available gamemoderun && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]
}

@test "launch_wrapper_available uses command_available for custom wrappers" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { [[ "$1" == dlss-swapper ]]; }
		launch_wrapper_available dlss-swapper && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]
}

@test "append_launch_wrappers uses launch_wrapper_available for known tools" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCH_WRAPPERS_BEFORE="gamemoderun"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		optional_tool_installed() { [[ "$1" == gamemoderun ]]; }
		launch=()
		append_launch_wrappers
		printf "%s\n" "${launch[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == gamemoderun ]]
}

@test "optional_tool_installed accepts cpupower as game-performance fallback" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { [[ "$1" == cpupower ]]; }
		optional_tool_installed game-performance && echo installed || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == installed ]]
}

@test "format_install_command renders pacman install line" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		format_install_command pacman gamemode
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "sudo pacman -S gamemode" ]]
}

@test "collect_missing_optional_tools lists absent relevant tools" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_relevant() { return 0; }
		optional_tool_installed() { return 1; }
		collect_missing_optional_tools
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *gamemoderun* ]]
}

@test "require_tool_or_skip warns and returns 1 when tool missing" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_installed() { return 1; }
		detect_package_manager() { echo pacman; }
		require_tool_or_skip ethtool "NETWORK_TUNE=1 skipped" 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"NETWORK_TUNE=1 skipped"* ]]
}

@test "warn_if_feature_enabled_needs_tool reports missing gamescope" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMESCOPE=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_installed() { return 1; }
		detect_package_manager() { echo apt; }
		warn_if_feature_enabled_needs_tool GAMESCOPE gamescope "GAMESCOPE=1 but gamescope is not installed" 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMESCOPE=1 but gamescope is not installed"* ]]
	[[ "$output" == *"apt"* ]]
}

@test "command_required_or_fail includes install hint" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { return 1; }
		detect_package_manager() { echo dnf; }
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		command_required_or_fail jq "JSON output" 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"JSON output: jq is required"* ]]
	[[ "$output" == *"dnf"* ]]
}
