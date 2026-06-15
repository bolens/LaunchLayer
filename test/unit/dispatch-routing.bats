#!/usr/bin/env bash
# Unit tests for handle_subcommand top-level routing to config verbs.
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

@test "handle_subcommand routes list-games to dispatch_config_subcommand" {
	run _dispatch_shell '
		source_lib platform config inspect steam games
		list_games() { echo "listed:$*"; }
		handle_subcommand --list-games --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"listed:0 1"* ]]
}

@test "handle_subcommand routes paths to show_paths" {
	run _dispatch_shell '
		source_lib platform config inspect steam
		show_paths() { echo "paths:$*"; }
		handle_subcommand --paths 42424242 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"paths:42424242 1"* ]]
}

@test "handle_subcommand routes prune-backups with parsed keep" {
	run _dispatch_shell '
		source_lib platform config inspect prefs
		default_backup_dir() { echo /tmp/backups; }
		default_backup_keep() { echo 4; }
		prune_backup_archives() { echo "prune:$*"; }
		handle_subcommand --prune-backups --keep 2 --dry-run
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"prune:/tmp/backups 2 1 0"* ]]
}

@test "handle_subcommand routes backup-config through config dispatch" {
	run _dispatch_shell '
		source_lib platform config inspect prefs
		backup_config() { echo "backup:$*"; }
		handle_subcommand --backup-config --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"backup:"* ]]
}

@test "handle_subcommand prune-backups reads backup.conf when --dir omitted" {
	local home xdg backup_dir
	home="$(mktemp -d)"
	xdg="$(mktemp -d)"
	backup_dir="$home/conf-backups"
	mkdir -p "$xdg/launchlayer"
	printf '%s\n' "backup_dir=$backup_dir" "keep=6" > "$xdg/launchlayer/backup.conf"
	run env HOME="$home" XDG_CONFIG_HOME="$xdg" bash -c '
		unset LAUNCHLAYER_BACKUP_DIR LAUNCHLAYER_BACKUP_KEEP
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli platform config inspect prefs
		prune_backup_archives() { printf "prune:%s\n" "$*"; }
		handle_subcommand --prune-backups --keep 2 --dry-run
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"prune:$backup_dir 2 1 0"* ]]
	rm -rf "$home" "$xdg"
}

@test "handle_subcommand routes hub-search through hub dispatch" {
	run _dispatch_shell '
		source_lib hub prefs platform hardware cli tools
		hub_search_machines() { echo "search:$*"; }
		handle_subcommand --hub-search --limit 2 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"search:--limit 2 --json"* ]]
}
