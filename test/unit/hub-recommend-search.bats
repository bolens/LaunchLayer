#!/usr/bin/env bash
# Unit tests for hub recommend/search CLI helpers and dispatch routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
	HUB_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$HUB_TMP"
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" "" minimal
}

teardown() {
	stop_hub_mock_server
	[[ -n "${HUB_TMP:-}" ]] && rm -rf "$HUB_TMP"
}

@test "hub_recommend_configs requires appid argument" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs platform hardware cli tools config hub
		hub_recommend_configs 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "hub_recommend_configs returns mock json results" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs platform hardware cli tools config hub
		hub_recommend_configs 42424242 --limit 3 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id"'* ]]
	[[ "$output" == *"cfgtest00001"* ]]
}

@test "hub_recommend_configs cli mode prints formatted rows" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs platform hardware cli tools config hub
		hub_recommend_configs 42424242 --limit 3
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Hub recommendations"* ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" == *"cfgtest00001"* || "$output" == *"92"* ]]
}

@test "hub_search_machines returns mock similar machines json" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands prefs platform hardware cli tools config hub
		hub_search_machines --limit 5 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"similar-box"'* ]]
	[[ "$output" == *'"similarity"'* ]]
}

@test "dispatch_hub_subcommand hub-search delegates limit flag" {
	run env XDG_CONFIG_HOME="$HUB_TMP" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands hub prefs platform hardware cli tools
		SEARCH_ARGS=()
		hub_search_machines() { SEARCH_ARGS=("$@"); echo "search:${*}"; }
		dispatch_hub_subcommand --hub-search --limit 7 --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"search:--limit 7 --json"* ]]
}

@test "hub_format_recommend_response_cli formats config_id and similarity" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hub cli
		response='"'"'{"results":[{"config_id":"cfgtest00001","similarity":92,"machine_label":"mock-box","published_at":1704067200000,"note":"stable"}]}'"'"'
		hub_format_recommend_response_cli "$response"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfgtest00001"* ]]
	[[ "$output" == *"92"* ]]
	[[ "$output" == *"mock-box"* ]]
}
