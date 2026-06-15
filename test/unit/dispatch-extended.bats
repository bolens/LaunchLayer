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
	local tmp home xdg backup_dir
	tmp="$(temp_config_dir)"
	home="$(mktemp -d)"
	xdg="$(mktemp -d)"
	backup_dir="$home/custom-backups"
	mkdir -p "$xdg/launchlayer"
	printf '%s\n' "backup_dir=$backup_dir" "keep=7" > "$xdg/launchlayer/backup.conf"
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" HOME="$home" XDG_CONFIG_HOME="$xdg" bash -c '
		unset LAUNCHLAYER_BACKUP_DIR LAUNCHLAYER_BACKUP_KEEP
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands platform config inspect tools prefs cli
		dispatch_config_subcommand --export-config --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"file_count"'* ]]
	[[ "$output" == *"$backup_dir"* ]]
	[[ "$output" == *launchlayer-export-* ]]
	ls "$backup_dir"/launchlayer-export-*.tar.gz >/dev/null
	rm -rf "$tmp" "$home" "$xdg"
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
