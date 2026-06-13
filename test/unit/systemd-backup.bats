#!/usr/bin/env bash
# Unit tests for backup systemd timer helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "systemd_backup_timer_brief_state reports not_installed" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		tmp="$(mktemp -d)"
		export XDG_CONFIG_HOME="$tmp" HOME="$tmp"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup
		systemd_backup_timer_brief_state
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "not_installed" ]]
}

@test "systemd_backup_units_installed_p is false without unit files" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		tmp="$(mktemp -d)"
		export XDG_CONFIG_HOME="$tmp" HOME="$tmp"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup
		systemd_backup_units_installed_p && echo yes || echo no
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "no" ]]
}
