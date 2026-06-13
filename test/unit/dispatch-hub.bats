#!/usr/bin/env bash
# Unit tests for lib/commands/dispatch-hub.sh routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
	HUB_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$HUB_TMP"
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
}

teardown() {
	stop_hub_mock_server
	[[ -n "${HUB_TMP:-}" ]] && rm -rf "$HUB_TMP"
}

@test "dispatch_hub_subcommand hub-update requires appid or config id" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs platform hardware cli tools
		dispatch_hub_subcommand --hub-update 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_hub_subcommand hub-recommend delegates limit and json flags" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs platform hardware cli tools
		REC_ARGS=()
		hub_recommend_configs() { REC_ARGS=("$@"); echo "recommend:${*}"; }
		dispatch_hub_subcommand --hub-recommend 42424242 --limit 3 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"recommend:42424242 --limit 3 --json"* ]]
}

@test "dispatch_hub_subcommand hub-prefs show reports configured url" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs
		dispatch_hub_subcommand --hub-prefs show
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"hub_url"* || "$output" == *"$HUB_MOCK_URL"* ]]
}

@test "dispatch_hub_subcommand hub-fingerprint json emits fingerprint field" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs platform hardware
		dispatch_hub_subcommand --hub-fingerprint --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"fingerprint"'* ]]
}
