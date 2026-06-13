#!/usr/bin/env bash
# Unit tests for scheduled backup pruning helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_make_backup_dir() {
	local dir=$1
	mkdir -p "$dir"
	touch -d '2020-01-01 00:00:00' "$dir/launchlayer-backup-20200101-000000.tar.gz"
	touch -d '2021-06-01 00:00:00' "$dir/launchlayer-backup-20210601-000000.tar.gz"
	touch -d '2024-06-01 00:00:00' "$dir/launchlayer-backup-20240601-000000.tar.gz"
	printf '%s\n' "$dir"
}

@test "prune_backup_archives dry-run lists oldest archives beyond keep" {
	local tmp dir
	tmp="$(mktemp -d)"
	dir="$(_make_backup_dir "$tmp/backups")"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		prune_backup_archives "'"$dir"'" 2 1 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"would remove:"* ]]
	[[ "$output" == *"20200101"* ]]
	[[ -f "$dir/launchlayer-backup-20200101-000000.tar.gz" ]]
	rm -rf "$tmp"
}

@test "prune_backup_archives removes oldest archives when keep exceeded" {
	local tmp dir
	tmp="$(mktemp -d)"
	dir="$(_make_backup_dir "$tmp/backups")"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		prune_backup_archives "'"$dir"'" 2 0 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Removed"* ]]
	[[ "$output" == *"20200101"* ]]
	[[ ! -f "$dir/launchlayer-backup-20200101-000000.tar.gz" ]]
	[[ -f "$dir/launchlayer-backup-20240601-000000.tar.gz" ]]
	rm -rf "$tmp"
}

@test "prune_backup_archives keep zero reports unlimited retention" {
	local tmp dir
	tmp="$(mktemp -d)"
	dir="$(_make_backup_dir "$tmp/backups")"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		prune_backup_archives "'"$dir"'" 0 0 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"unlimited retention"* ]]
	[[ "$output" == *"removed=0"* ]]
	[[ -f "$dir/launchlayer-backup-20200101-000000.tar.gz" ]]
	rm -rf "$tmp"
}

@test "prune_backup_archives json reports candidate files" {
	local tmp dir
	tmp="$(mktemp -d)"
	dir="$(_make_backup_dir "$tmp/backups")"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		prune_backup_archives "'"$dir"'" 1 1 1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"keep":1'* ]]
	[[ "$output" == *'"dry_run":true'* ]]
	[[ "$output" == *"20200101"* ]]
	[[ "$output" == *"20210601"* ]]
	rm -rf "$tmp"
}

@test "prune_backup_archives handles missing backup directory" {
	local tmp
	tmp="$(mktemp -d)"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect
		prune_backup_archives "'"$tmp/missing"'" 3 1 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"does not exist"* ]]
	[[ "$output" == *"removed=0"* ]]
	rm -rf "$tmp"
}

@test "run_scheduled_backup skips prune when auto_prune disabled" {
	local tmp xdg
	tmp="$(mktemp -d)"
	xdg="$(mktemp -d)"
	mkdir -p "$xdg/launchlayer"
	cat > "$xdg/launchlayer/backup.conf" <<EOF
backup_dir=$tmp/backups
keep=2
auto_prune=0
include_local=1
include_profiles=1
include_tui=0
EOF
	run env XDG_CONFIG_HOME="$xdg" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect prefs setup
		backup_config() { printf "backup-ok\n"; return 0; }
		prune_backup_archives() { echo "prune-called"; return 0; }
		run_scheduled_backup "'"$tmp/backups"'" 2 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup-ok"* ]]
	[[ "$output" == *"Skipping prune"* ]]
	[[ "$output" != *"prune-called"* ]]
	rm -rf "$tmp" "$xdg"
}

@test "run_scheduled_backup invokes prune when auto_prune enabled" {
	local tmp xdg
	tmp="$(mktemp -d)"
	xdg="$(mktemp -d)"
	mkdir -p "$xdg/launchlayer" "$tmp/backups"
	cat > "$xdg/launchlayer/backup.conf" <<EOF
backup_dir=$tmp/backups
keep=1
auto_prune=1
include_local=1
include_profiles=1
include_tui=0
EOF
	touch -d '2020-01-01 00:00:00' "$tmp/backups/launchlayer-backup-20200101-000000.tar.gz"
	touch -d '2024-06-01 00:00:00' "$tmp/backups/launchlayer-backup-20240601-000000.tar.gz"
	run env XDG_CONFIG_HOME="$xdg" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform cli inspect prefs setup
		backup_config() { printf "backup-ok\n"; return 0; }
		run_scheduled_backup "'"$tmp/backups"'" 1 0
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup-ok"* ]]
	[[ "$output" == *"Removed"* || "$output" == *"removed="* ]]
	rm -rf "$tmp" "$xdg"
}
