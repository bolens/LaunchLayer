#!/usr/bin/env bash
# Unit tests for lib/prefs/paths.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib prefs
}

@test "backup_prefs_path uses launchlayer config dir" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs
		backup_prefs_path
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp/launchlayer/backup.conf" ]]
	rm -rf "$tmp"
}

@test "tui_config_path uses launchlayer config dir" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs
		tui_config_path
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp/launchlayer/tui.conf" ]]
	rm -rf "$tmp"
}

@test "default_systemd_backup_dir expands under home" {
	local tmp
	tmp="$(mktemp -d)"
	run env HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs
		default_systemd_backup_dir
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp/launchlayer-backups" ]]
	rm -rf "$tmp"
}

@test "backup_prefs_example_path points at repo template" {
	run backup_prefs_example_path
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup.conf.example" ]]
	[[ -f "$output" ]]
}
