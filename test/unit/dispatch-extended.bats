#!/usr/bin/env bash
# Unit tests for additional dispatch router branches.
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

@test "dispatch_setup_subcommand routes backup-prefs show" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs setup
		dispatch_setup_subcommand --backup-prefs show
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup_dir"* || "$output" == *"keep"* ]]
	rm -rf "$tmp"
}

@test "dispatch_hub_subcommand hub-apply requires config id" {
	run _dispatch_shell '
		source_lib hub prefs
		dispatch_hub_subcommand --hub-apply 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_launch_subcommand launch-stats emits json" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands platform config inspect runtime launch
			dispatch_launch_subcommand --launch-stats --json
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* || "$output" == *"[]"* || "$output" == *'"stats"'* ]]
	rm -rf "$tmp"
}

@test "dispatch_config_subcommand export-config writes archive with default output" {
	local tmp out
	tmp="$(temp_config_dir)"
	out="$tmp/launch.d/../launchlayer-export-"*.tar.gz
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands platform config inspect tools
		dispatch_config_subcommand --export-config --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"file_count"'* ]]
	rm -rf "$tmp"
}

@test "dispatch_tui_subcommand quick toggles flip requires appid and line" {
	run _dispatch_shell '
		source_lib load-modules
		launchlayer_source_tui
		dispatch_tui_subcommand --tui-quick-toggles-flip 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "handle_subcommand routes hub fingerprint verb" {
	run _dispatch_shell '
		source_lib platform hardware prefs hub
		handle_subcommand --hub-fingerprint --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"fingerprint"'* ]]
}
