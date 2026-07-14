#!/usr/bin/env bash
# Unit tests for hub apply via dispatch routers against mock hub.
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

@test "dispatch_hub_subcommand hub-apply dry-run fetches mock config without writing" {
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform cli tools config inspect
			dispatch_hub_subcommand --hub-apply cfgtest00001 --dry-run
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Would write"* ]]
	[[ "$output" == *"GAMEMODE=1"* ]]
	[[ ! -f "'"$CONFIG_TMP"'/games/42424242.env" ]]
}

@test "handle_subcommand routes hub-apply dry-run json through hub dispatch" {
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands cli hub prefs platform tools config inspect
			handle_subcommand --hub-apply cfgtest00001 --dry-run --json
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	[[ "$output" == *"42424242"* ]]
}

@test "dispatch_hub_subcommand hub-apply rejects invalid config id" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_TMP"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs platform cli tools config inspect
		dispatch_hub_subcommand --hub-apply cfg-test-1 --dry-run 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Invalid hub config ID"* ]]
}

@test "dispatch_hub_subcommand hub-apply strips untrusted remote exec keys" {
	mkdir -p "$CONFIG_TMP/launch.d/presets"
	printf 'GAMEMODE=0\n' > "$CONFIG_TMP/launch.d/presets/standard.env"
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$CONFIG_TMP" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform cli tools config inspect
			dispatch_hub_subcommand --hub-apply cfgunsafe01 --dry-run 2>&1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Stripped untrusted hub keys"* ]]
	[[ "$output" == *"PRE_LAUNCH_CMD"* ]]
	[[ "$output" == *"Would write"* ]]
	[[ "$output" == *"GAMEMODE=1"* ]]
	[[ "$output" != *"curl evil.example"* ]]
	[[ "$output" != *"OVERRIDE_PROTON=/tmp"* ]]
}

@test "dispatch_hub_subcommand hub-prefs set requires key and value" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_TMP"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs
		dispatch_hub_subcommand --hub-prefs set hub_url 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}
