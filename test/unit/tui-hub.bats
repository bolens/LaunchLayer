#!/usr/bin/env bash
# Unit tests for hub TUI parsing and recommendation helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib hub cli load-modules
	launchlayer_source_tui
}

@test "tui_hub_parse_recommendation_lines builds picker rows from JSON" {
	local response='{"results":[{"config_id":"cfg-test-1","similarity":92,"machine_label":"test-rig","gpu_vendor":"nvidia","note":"competitive preset","published_at":1704067200000}]}'
	run tui_hub_parse_recommendation_lines "$response"
	[[ $status -eq 0 ]]
	[[ "$output" == $'cfg-test-1\t92% match · test-rig · updated 2024-01-01 · competitive preset' ]]
}

@test "tui_hub_parse_recommendation_lines falls back to gpu_vendor without label" {
	local response='{"results":[{"config_id":"cfg-amd","similarity":80,"gpu_vendor":"amd","published_at":1704067200000}]}'
	run tui_hub_parse_recommendation_lines "$response"
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfg-amd"* ]]
	[[ "$output" == *"80% match · amd"* ]]
	[[ "$output" == *"updated 2024-01-01"* ]]
}

@test "tui_hub_parse_recommendation_lines returns empty for no results" {
	run tui_hub_parse_recommendation_lines '{"results":[]}'
	[[ $status -eq 0 ]]
	[[ -z "$output" ]]
}

@test "hub_jq_recommend_picker_filter matches tui_hub_parse output" {
	local response='{"results":[{"config_id":"cfg-test-1","similarity":92,"machine_label":"test-rig","note":"competitive preset","published_at":1704067200000}]}'
	run env HUB_JSON_RESPONSE="$response" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib hub
		printf "%s\n" "$HUB_JSON_RESPONSE" | jq -r "$(hub_jq_recommend_picker_filter)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfg-test-1"* ]]
	[[ "$output" == *"92% match · test-rig"* ]]
}
