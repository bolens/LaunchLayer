#!/usr/bin/env bash
# Unit tests for hub config history and historical apply.
load '../helpers.bash'

setup() {
	bats_unit_setup
	HUB_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$HUB_TMP"
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" "" minimal
	CONFIG_TMP="$(temp_config_dir)"
	export LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games"
	mkdir -p "$LAUNCHLAYER_GAMES_DIR"
}

teardown() {
	stop_hub_mock_server
	[[ -n "${HUB_TMP:-}" ]] && rm -rf "$HUB_TMP"
	[[ -n "${CONFIG_TMP:-}" ]] && rm -rf "$CONFIG_TMP"
}

@test "dispatch_hub_subcommand hub-history lists config history in human format" {
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform cli tools config inspect
			dispatch_hub_subcommand --hub-history cfgtest00001
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"History for config"* ]]
	[[ "$output" == *"preset=standard"* ]]
	[[ "$output" == *"note=v1 note"* ]]
	[[ "$output" == *"id=hist00000001"* ]]
}

@test "dispatch_hub_subcommand hub-history prints config history in json format" {
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform cli tools config inspect
			dispatch_hub_subcommand --hub-history cfgtest00001 --json
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"history_id"'* ]]
	[[ "$output" == *'"note"'* ]]
	[[ "$output" == *"v1 note"* ]]
}

@test "dispatch_hub_subcommand hub-apply --history dry-run fetches historical version" {
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform cli tools config inspect
			dispatch_hub_subcommand --hub-apply hist00000001 --history --dry-run
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Would write"* ]]
	[[ "$output" == *"GAMEMODE=1"* ]]
	[[ "$output" == *"DEBUG=1"* ]]
	[[ ! -f "'"$CONFIG_TMP"'/games/42424242.env" ]]
}
