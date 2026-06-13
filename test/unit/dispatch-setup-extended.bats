#!/usr/bin/env bash
# Unit tests for dispatch-setup backup-timer, prefs, and completions routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_setup_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli
		'"$1"'
	'
}

@test "dispatch_setup_subcommand backup-timer status delegates to systemd_backup_status" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands setup prefs
		systemd_backup_status() { echo timer-status; }
		dispatch_setup_subcommand --backup-timer status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"timer-status"* ]]
	rm -rf "$tmp"
}

@test "dispatch_setup_subcommand backup-timer install passes dir keep and no-enable" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands setup prefs
		save_backup_prefs() { :; }
		backup_prefs_apply_env() { :; }
		install_systemd_backup_units() { printf "install:%s\n" "$1"; }
		dispatch_setup_subcommand --backup-timer install --dir /tmp/backups --keep 4 --no-enable
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"install:0"* ]]
	rm -rf "$tmp"
}

@test "dispatch_setup_subcommand backup-timer rejects unknown action" {
	run _dispatch_setup_shell '
		source_lib setup prefs
		dispatch_setup_subcommand --backup-timer not-an-action 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_setup_subcommand tui-prefs show routes json flag" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs setup
		show_tui_prefs() { printf "tui-prefs:%s\n" "$1"; }
		dispatch_setup_subcommand --tui-prefs show --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"tui-prefs:1"* ]]
	rm -rf "$tmp"
}

@test "dispatch_setup_subcommand tui-prefs set requires key and value" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs setup
		dispatch_setup_subcommand --tui-prefs set game_filter 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
	rm -rf "$tmp"
}

@test "dispatch_setup_subcommand completions print requires shell" {
	run _dispatch_setup_shell '
		source_lib completions setup
		dispatch_setup_subcommand --completions print 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_setup_subcommand completions status accepts json flag" {
	run _dispatch_setup_shell '
		source_lib completions setup
		completions_show_status() { printf "status:%s\n" "$1"; }
		dispatch_setup_subcommand --completions status --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"status:1"* ]]
}
