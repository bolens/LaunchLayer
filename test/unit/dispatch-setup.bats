#!/usr/bin/env bash
# Unit tests for lib/commands/dispatch-setup.sh routing.
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

@test "dispatch_setup_subcommand doctor routes json flag to show_doctor" {
	run _dispatch_setup_shell '
		source_lib platform config inspect setup
		DOCTOR_JSON=""
		show_doctor() { DOCTOR_JSON="$1"; echo "doctor:$1"; }
		dispatch_setup_subcommand --doctor --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "doctor:1" ]]
}

@test "dispatch_setup_subcommand sysctl status routes to handle_sysctl_subcommand" {
	run _dispatch_setup_shell '
		source_lib platform setup
		SYSCTL_CMD=""
		handle_sysctl_subcommand() { SYSCTL_CMD="$1"; echo "sysctl:$1"; }
		dispatch_setup_subcommand --sysctl status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "sysctl:status" ]]
}

@test "dispatch_setup_subcommand setup print-launch-option skips completions" {
	local tmp
	tmp="$(mktemp -d)"
	run env HOME="$tmp" XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_MAIN_SCRIPT="'"$CONFIG_DIR"'/launchlayer"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands setup completions
		completions_enable() { echo "completions-called"; }
		dispatch_setup_subcommand --setup --print-launch-option
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Add to Steam Launch Options"* ]]
	[[ "$output" == *"%command%"* ]]
	[[ "$output" != *"completions-called"* ]]
	rm -rf "$tmp"
}

@test "dispatch_setup_subcommand install-systemd delegates to install_systemd_user_units" {
	local tmp
	tmp="$(mktemp -d)"
	run env HOME="$tmp" XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands setup
		install_systemd_user_units() { echo systemd-installed; }
		dispatch_setup_subcommand --install-systemd
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "systemd-installed" ]]
	rm -rf "$tmp"
}
