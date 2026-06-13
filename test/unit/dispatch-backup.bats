#!/usr/bin/env bash
# Unit tests for dispatch-config backup/import/restore routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_config_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli
		'"$1"'
	'
}

@test "dispatch_config_subcommand backup-config parses output and include flags" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		backup_config() { printf "backup:%s\n" "$*"; }
		dispatch_config_subcommand --backup-config --output /tmp/out --exclude-local --include-tui --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup:/tmp/out 0 1 1 1"* ]]
}

@test "dispatch_config_subcommand import-config yes replace clears dry-run" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		import_config() { printf "import:%s\n" "$*"; }
		dispatch_config_subcommand --import-config /tmp/bundle.tar.gz --yes --replace --exclude-local --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"import:/tmp/bundle.tar.gz 0 replace 1 0 1 0 1"* ]]
}

@test "dispatch_config_subcommand import-config defaults to dry-run without yes" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		import_config() { printf "import:%s\n" "$*"; }
		dispatch_config_subcommand --import-config /tmp/bundle.tar.gz --merge
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"import:/tmp/bundle.tar.gz 1 merge 0 1 1 0 0"* ]]
}

@test "dispatch_config_subcommand restore-backup list routes to list_backups" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		list_backups() { printf "list:%s\n" "$*"; }
		dispatch_config_subcommand --restore-backup --list --dir /tmp/backups --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"list:/tmp/backups 1"* ]]
}

@test "dispatch_config_subcommand restore-backup parses appid and apply flags" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		restore_backup() { printf "restore:%s\n" "$*"; }
		dispatch_config_subcommand --restore-backup /tmp/latest.tar.gz --dir /tmp/backups --yes --merge --appid 42424242 --include-tui --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"restore:/tmp/latest.tar.gz /tmp/backups 0 merge 1 1 1 1 1 42424242"* ]]
}

@test "dispatch_config_subcommand prune-backups fills defaults and passes keep" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		default_backup_dir() { echo /tmp/backups; }
		default_backup_keep() { echo 5; }
		prune_backup_archives() { printf "prune:%s\n" "$*"; }
		dispatch_config_subcommand --prune-backups --keep 3 --dry-run --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"prune:/tmp/backups 3 1 1"* ]]
}

@test "dispatch_config_subcommand run-scheduled-backup passes dir keep and json" {
	run _dispatch_config_shell '
		source_lib platform config inspect prefs
		default_backup_dir() { echo /tmp/backups; }
		default_backup_keep() { echo 7; }
		run_scheduled_backup() { printf "scheduled:%s\n" "$*"; }
		dispatch_config_subcommand --run-scheduled-backup --dir /data/backups --keep 2 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"scheduled:/data/backups 2 1"* ]]
}
