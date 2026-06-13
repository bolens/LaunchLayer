#!/usr/bin/env bash
# Integration tests for hub TUI/CLI hooks against the local mock server.
load '../helpers.bash'

setup() {
	bats_integration_setup
	HUB_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$HUB_TMP"
	export HOME="$HUB_TMP"
	CONFIG_TMP="$(temp_config_dir)"
	export LAUNCHLAYER_CONFIG_DIR="$CONFIG_TMP"
	export LAUNCHLAYER_GAMES_DIR="$CONFIG_TMP/games"
	mkdir -p "$LAUNCHLAYER_GAMES_DIR"
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
}

teardown() {
	stop_hub_mock_server
	[[ -n "${HUB_TMP:-}" ]] && rm -rf "$HUB_TMP"
	[[ -n "${CONFIG_TMP:-}" ]] && rm -rf "$CONFIG_TMP"
	bats_integration_teardown
}

@test "tui_hub_parse_recommendation_lines matches hub-recommend json" {
	run env \
		HOME="$HUB_TMP" \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		CONFIG_DIR="$CONFIG_TMP" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib load-modules prefs hub
			launchlayer_source_tui
			response="$(hub_recommend_payload "{}" 42424242 1)"
			response='"'"'{"results":[{"config_id":"cfg-test-1","similarity":92,"machine_label":"test-rig","note":"ok","published_at":1704067200000}]}'"'"'
			tui_hub_parse_recommendation_lines "$response"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfg-test-1"* ]]
}

@test "hub-delete via CLI succeeds against mock with token" {
	run env \
		HOME="$HUB_TMP" \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		LAUNCHLAYER_CONFIG_DIR="$CONFIG_TMP" \
		"$SCRIPT" --hub-delete cfgdelete001 --yes --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"deleted_config_id"'* ]]
	[[ "$output" == *"cfgdelete001"* ]]
}

@test "hub-search returns mock machines json via CLI" {
	run env \
		HOME="$HUB_TMP" \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		LAUNCHLAYER_CONFIG_DIR="$CONFIG_TMP" \
		"$SCRIPT" --hub-search --limit 3 --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"similar-box"'* ]]
}
