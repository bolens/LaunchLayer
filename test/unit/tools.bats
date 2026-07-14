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
		command_available() { [[ "$1" == custom-tool ]]; }
		launch_wrapper_available custom-tool && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == yes ]]
}

@test "resolve_dlss_swapper_bin maps DLSS_SWAPPER values" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		DLSS_SWAPPER=0; resolve_dlss_swapper_bin && echo on || echo off
		DLSS_SWAPPER=1; resolve_dlss_swapper_bin; echo
		DLSS_SWAPPER=dll; resolve_dlss_swapper_bin; echo
		DLSS_SWAPPER=yes; resolve_dlss_swapper_bin; echo
		DLSS_SWAPPER=DLL; resolve_dlss_swapper_bin; echo
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'off\ndlss-swapper\ndlss-swapper-dll\ndlss-swapper\ndlss-swapper-dll' ]]
}

@test "optional_tool_relevant hides dlss-swapper on non-nvidia" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		detect_gpu_vendor() { echo amd; }
		optional_tool_relevant dlss-swapper && echo yes || echo no
		detect_gpu_vendor() { echo nvidia; }
		optional_tool_relevant dlss-swapper && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'no\nyes' ]]
}

@test "optional_tool_installed dlss-swapper accepts either binary" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { [[ "$1" == dlss-swapper-dll ]]; }
		optional_tool_installed dlss-swapper && echo catalog-yes || echo catalog-no
		launch_wrapper_available dlss-swapper && echo primary-yes || echo primary-no
		launch_wrapper_available dlss-swapper-dll && echo dll-yes || echo dll-no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'catalog-yes\nprimary-no\ndll-yes' ]]
}

@test "tool_install_hint dlss-swapper is cachyos-aware" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		detect_package_manager() { echo pacman; }
		tool_install_hint dlss-swapper
		echo ---
		detect_package_manager() { echo apt; }
		tool_install_hint dlss-swapper
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cachyos-settings"* ]]
	[[ "$output" == *"dlss-swapper"* ]]
	# Non-pacman path includes the wiki URL for manual install guidance.
	[[ "$output" == *$'---\n'*wiki.cachyos.org* ]]
}

@test "optional_tool_installed dlss-updater accepts binary or flatpak" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { return 1; }
		flatpak() { return 1; }
		optional_tool_installed dlss-updater && echo no || echo missing
		command_available() { [[ "$1" == dlss-updater ]]; }
		optional_tool_installed dlss-updater && echo binary-yes || echo binary-no
		command_available() { [[ "$1" == flatpak ]]; }
		flatpak() { [[ "$1" == info && "$2" == io.github.recol.dlss-updater ]]; }
		optional_tool_installed dlss-updater && echo flatpak-yes || echo flatpak-no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == $'missing\nbinary-yes\nflatpak-yes' ]]
}

@test "tool_install_hint dlss-updater points at package or GitHub" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		detect_package_manager() { echo pacman; }
		tool_install_hint dlss-updater
		echo ---
		detect_package_manager() { echo apt; }
		tool_install_hint dlss-updater
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dlss-updater"* ]]
	[[ "$output" == *"GUI"* ]]
	[[ "$output" == *"github.com/Recol/DLSS-Updater"* ]]
}

@test "LAUNCHLAYER_OPTIONAL_TOOLS catalogs dlss-updater" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		printf "%s\n" "${LAUNCHLAYER_OPTIONAL_TOOLS[@]}" | grep -qx dlss-updater && echo ok
	'
	[[ $status -eq 0 ]]
	[[ "$output" == ok ]]
}

@test "warn_enabled_missing_tools reports DLSS_SWAPPER missing binary" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export DLSS_SWAPPER=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { return 1; }
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		detect_package_manager() { echo pacman; }
		detect_gpu_vendor() { echo nvidia; }
		detect_audio_server() { echo pulse; }
		has_systemd_user() { return 1; }
		# Keep unrelated feature warnings quiet.
		GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 NETWORK_TUNE=0
		PIPEWIRE_LOW_LATENCY=0 NVIDIA_POWER_MODE=0 GPU_POWER_CHECK=0 VRAM_HOGS=0
		DISABLE_CPU_AFFINITY=1 LAUNCH_WRAPPERS= LAUNCH_WRAPPERS_BEFORE=
		warn_enabled_missing_tools 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"DLSS_SWAPPER=1 but dlss-swapper is not installed"* ]]
	[[ "$output" == *"cachyos-settings"* ]]
}

@test "warn_enabled_missing_tools reports DLSS_SWAPPER=dll missing binary" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export DLSS_SWAPPER=dll
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform
		source "'"$CONFIG_DIR"'/lib/tools.sh"
		command_available() { [[ "$1" == dlss-swapper ]]; }
		optional_tool_installed() { return 1; }
		optional_tool_relevant() { return 0; }
		detect_package_manager() { echo pacman; }
		detect_gpu_vendor() { echo nvidia; }
		detect_audio_server() { echo pulse; }
		has_systemd_user() { return 1; }
		GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 NETWORK_TUNE=0
		PIPEWIRE_LOW_LATENCY=0 NVIDIA_POWER_MODE=0 GPU_POWER_CHECK=0 VRAM_HOGS=0
		DISABLE_CPU_AFFINITY=1 LAUNCH_WRAPPERS= LAUNCH_WRAPPERS_BEFORE=
		warn_enabled_missing_tools 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"DLSS_SWAPPER=dll but dlss-swapper-dll is not installed"* ]]
}

@test "collect_missing_optional_tools includes dlss-swapper when catalog lists it" {
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
	[[ "$output" == *dlss-swapper* ]]
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
