#!/usr/bin/env bash
# Unit tests for --backup-prefs and --hub-prefs subcommand handlers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "handle_backup_prefs set keep persists to backup.conf" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand set keep 14
		load_backup_prefs
		echo "keep:$BACKUP_PREFS_KEEP"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Set keep=14"* ]]
	[[ "$output" == *"keep:14"* ]]
	grep -q '^keep=14$' "$tmp/launchlayer/backup.conf"
	rm -rf "$tmp"
}

@test "handle_backup_prefs set auto_prune rejects invalid values" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand set auto_prune maybe 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"auto_prune must be 0 or 1"* ]]
	rm -rf "$tmp"
}

@test "handle_backup_prefs set-schedule daily updates calendar expression" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand set-schedule daily 04:30
		load_backup_prefs
		echo "calendar:$BACKUP_PREFS_ON_CALENDAR"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Updated schedule:"* ]]
	[[ "$output" == *"calendar:*-*-* 04:30:00"* ]]
	rm -rf "$tmp"
}

@test "handle_backup_prefs set-schedule interval configures active timer" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand set-schedule interval 6h 10min
		load_backup_prefs
		echo "type:$BACKUP_PREFS_TIMER_TYPE active:$BACKUP_PREFS_ON_UNIT_ACTIVE_SEC boot:$BACKUP_PREFS_ON_BOOT_SEC"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"type:interval"* ]]
	[[ "$output" == *"active:6h"* ]]
	[[ "$output" == *"boot:10min"* ]]
	rm -rf "$tmp"
}

@test "handle_backup_prefs show --json includes prune policy fields" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand show --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"keep"'* ]]
	[[ "$output" == *'"auto_prune"'* ]]
	[[ "$output" == *'"prune_policy"'* ]]
	rm -rf "$tmp"
}

@test "handle_backup_prefs reset restores template defaults" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib setup prefs cli
		handle_backup_prefs_subcommand set keep 99
		handle_backup_prefs_subcommand reset
		load_backup_prefs
		echo "keep:$BACKUP_PREFS_KEEP"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Reset backup preferences"* ]]
	[[ "$output" != *"keep:99"* ]]
	rm -rf "$tmp"
}

@test "handle_hub_prefs reset restores example hub defaults" {
	local tmp example
	tmp="$(mktemp -d)"
	example="$tmp/share/launchlayer/templates/hub.conf.example"
	mkdir -p "$(dirname "$example")" "$tmp/launchlayer"
	cat > "$example" <<'EOF'
hub_url=
publish_token=
machine_label=workstation
fingerprint_level=standard
EOF
	run env \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		XDG_CONFIG_HOME="$tmp" \
		HOME="$tmp" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib prefs hub cli
			handle_hub_prefs_subcommand set machine_label custom-box
			handle_hub_prefs_subcommand reset
			load_hub_prefs
			echo "label:$HUB_PREFS_MACHINE_LABEL"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Reset hub preferences"* ]]
	[[ "${output##*$'\n'}" == *"label:workstation"* ]]
	rm -rf "$tmp"
}

@test "handle_hub_prefs set machine_label persists to hub.conf" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub cli
		handle_hub_prefs_subcommand set machine_label arcade-rig
		load_hub_prefs
		echo "label:$HUB_PREFS_MACHINE_LABEL"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Set machine_label=arcade-rig"* ]]
	[[ "$output" == *"label:arcade-rig"* ]]
	rm -rf "$tmp"
}
