#!/usr/bin/env bash
# Unit tests for bulk_set_include_preset scope collection and hub prefs routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "bulk_set_include_preset all-configured dry-run json collects configured appids" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Bulk A")"
	seed_fake_steam_game "$fake_steam" 52525252 "Bulk B"
	tmp="$(temp_config_dir)"
	mkdir -p "$tmp/games"
	printf 'INCLUDE=presets/standard.env\n' > "$tmp/games/42424242.env"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands platform config inspect steam games cli
			cli_scan_progress_begin() { :; }
			cli_scan_progress_end() { :; }
			bulk_set_include_preset competitive --all-configured --dry-run --json
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"preset":"competitive"'* || "$output" == *'"preset": "competitive"'* ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" != *"52525252"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "bulk_set_include_preset grep dry-run matches game names" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Overwatch Bulk")"
	seed_fake_steam_game "$fake_steam" 52525252 "Other Game"
	tmp="$(temp_config_dir)"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands platform config inspect steam games cli
			cli_scan_progress_begin() { :; }
			cli_scan_progress_end() { :; }
			bulk_set_include_preset standard --grep Overwatch --dry-run --json
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" != *"52525252"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "bulk_set_include_preset rejects empty scope without targets" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands platform config inspect steam games cli
		bulk_set_include_preset competitive --dry-run 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Specify --all-configured"* ]]
}

@test "dispatch_config_subcommand bulk-set-include all-installed delegates flags" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli platform config inspect steam games
		bulk_set_include_preset() { printf "bulk:%s\n" "$*"; }
		dispatch_config_subcommand --bulk-set-include lightweight --all-installed --dry-run
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"bulk:lightweight --all-installed --dry-run"* ]]
}

@test "handle_subcommand routes backup-timer status through setup dispatch" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli setup prefs
		systemd_backup_status() { echo routed-timer-status; }
		handle_subcommand --backup-timer status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"routed-timer-status"* ]]
	rm -rf "$tmp"
}
