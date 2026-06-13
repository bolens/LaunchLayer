#!/usr/bin/env bash
# Unit tests for lib/commands/dispatch*.sh routers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli
		'"$1"'
	'
}

@test "handle_subcommand routes --help and --version" {
	run _dispatch_shell '
		handle_subcommand --help | head -1
		echo "---"
		handle_subcommand --version | head -1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"LaunchLayer"* ]]
	[[ "$output" == *"---"* ]]
}

@test "handle_subcommand returns failure for unknown verb" {
	run _dispatch_shell 'handle_subcommand --totally-unknown-flag'
	[[ $status -eq 1 ]]
}

@test "dispatch_tui_subcommand parses picker appid rows" {
	run _dispatch_shell '
		source_lib load-modules
		launchlayer_source_tui
		dispatch_tui_subcommand --tui-picker-appid "  42424242    yes   no    -        unknown      Game"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "42424242" ]]
}

@test "dispatch_tui_subcommand rejects missing preview appid" {
	run _dispatch_shell '
		source_lib load-modules
		launchlayer_source_tui
		dispatch_tui_subcommand --tui-game-preview 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_launch_subcommand pause-vram-hogs increments ref count" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands vram
			pause_vram_hogs() { set_vram_ref_count $(($(get_vram_ref_count) + 1)); }
			dispatch_launch_subcommand --pause-vram-hogs
			get_vram_ref_count
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Paused VRAM-heavy services"* ]]
	[[ "$output" == *"1"* ]]
	rm -rf "$tmp"
}

@test "dispatch_config_subcommand rejects unknown preset on init-appid" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Dispatch Game")"
	tmp="$(temp_config_dir)"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands platform steam keys config
			init_appid_config 42424242 not-a-preset 0 2>&1
		'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Unknown preset"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "dispatch_hub_subcommand returns failure for unknown hub verb" {
	run _dispatch_shell 'dispatch_hub_subcommand --hub-not-a-real-verb'
	[[ $status -eq 1 ]]
}
