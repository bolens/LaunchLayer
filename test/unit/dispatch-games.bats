#!/usr/bin/env bash
# Unit tests for dispatch-config games and paths routing.
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

@test "dispatch_config_subcommand list-games parses configured json and grep" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam games
		list_games() { printf "list:%s\n" "$*"; }
		dispatch_config_subcommand --list-games --configured --json --grep "Test Game"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"list:1 1 Test Game"* ]]
}

@test "dispatch_config_subcommand paths routes query and json flag" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam
		show_paths() { printf "paths:%s\n" "$*"; }
		dispatch_config_subcommand --paths 42424242 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"paths:42424242 1"* ]]
}

@test "dispatch_config_subcommand show-config routes query and json flag" {
	run _dispatch_config_shell '
		source_lib platform config inspect
		show_config() { printf "show:%s\n" "$*"; }
		dispatch_config_subcommand --show-config Overwatch --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"show:Overwatch 1"* ]]
}

@test "dispatch_config_subcommand init-appid parses preset and force" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam games
		init_appid_config() { printf "init:%s\n" "$*"; }
		dispatch_config_subcommand --init-appid 42424242 competitive --force
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"init:42424242 competitive 1"* ]]
}

@test "dispatch_config_subcommand bulk-set-include requires preset" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam games
		dispatch_config_subcommand --bulk-set-include --dry-run 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_config_subcommand bulk-set-include delegates dry-run appid list" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam games
		bulk_set_include_preset() { printf "bulk:%s\n" "$*"; }
		dispatch_config_subcommand --bulk-set-include competitive 42424242 --dry-run --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"bulk:competitive 42424242 --dry-run --json"* ]]
}

@test "dispatch_config_subcommand detect-defaults passes json flag" {
	run _dispatch_config_shell '
		source_lib platform config detected-defaults
		show_detected_defaults() { printf "defaults:%s\n" "$1"; }
		dispatch_config_subcommand --detect-defaults --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"defaults:1"* ]]
}
