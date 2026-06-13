#!/usr/bin/env bash
# Unit tests for privileged hub client auth (publish/delete) against a local mock server.
load '../helpers.bash'

setup() {
	bats_unit_setup
	export XDG_CONFIG_HOME
	XDG_CONFIG_HOME="$(mktemp -d)"
	export XDG_CONFIG_HOME
	source_lib commands prefs platform cli tools
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" "" minimal
}

teardown() {
	stop_hub_mock_server
	[[ -n "${XDG_CONFIG_HOME:-}" ]] && rm -rf "$XDG_CONFIG_HOME"
}

@test "hub_fetch_publish_auth_required detects enforced auth from /api/auth" {
	run hub_fetch_publish_auth_required
	[[ $status -eq 0 ]]
	[[ "$output" == "1" ]]
}

@test "hub_fetch_publish_auth_required is false when hub is open" {
	stop_hub_mock_server
	start_hub_mock_server test-secret 1
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" "" minimal
	run hub_fetch_publish_auth_required
	[[ $status -eq 0 ]]
	[[ "$output" == "0" ]]
}

@test "hub_require_privileged_auth fails without publish_token when auth enforced" {
	run hub_require_privileged_auth
	[[ $status -eq 1 ]]
	[[ "$output" == *"requires publish_token"* ]]
}

@test "hub_require_privileged_auth passes when publish_token is configured" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_require_privileged_auth
	[[ $status -eq 0 ]]
}

@test "hub_delete_payload emits config_id JSON" {
	run hub_delete_payload "cfg-abc-123"
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["config_id"]=="cfg-abc-123"' "$output"
}

@test "hub_curl_json rejects privileged delete without local token" {
	run hub_curl_json POST /api/delete '{"config_id":"cfg-1"}' 1
	[[ $status -eq 1 ]]
	[[ "$output" == *"requires publish_token"* ]]
}

@test "hub_curl_json privileged delete succeeds with matching token" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfg-ok)" 1
	[[ $status -eq 0 ]]
	[[ "$output" == *'"deleted_config_id"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["deleted_config_id"]=="cfg-ok"' "$output"
}

@test "hub_curl_json privileged delete returns 401 message for wrong token" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" wrong-token minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfg-1)" 1
	[[ $status -eq 1 ]]
	[[ "$output" == *"unauthorized"* || "$output" == *"401"* ]]
}

@test "hub_curl_json privileged delete surfaces 404 from hub" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload missing)" 1
	[[ $status -eq 1 ]]
	[[ "$output" == *"404"* || "$output" == *"Config not found"* ]]
}

@test "hub_curl_json recommend works without publish token" {
	run hub_curl_json POST /api/recommend '{"fingerprint":{},"limit":1}' 0
	[[ $status -eq 0 ]]
	[[ "$output" == *'"results"'* ]]
}

@test "hub_curl_json privileged publish succeeds with token" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_curl_json POST /api/publish '{"fingerprint":{},"appid":"1"}' 1
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id"'* ]]
}

@test "hub_delete_config deletes via mock hub with --yes --json" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_delete_config cfg-cli --yes --json
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["deleted_config_id"]=="cfg-cli"' "$output"
}

@test "hub_delete_config fails without token when auth enforced" {
	run hub_delete_config cfg-cli --yes --json
	[[ $status -eq 1 ]]
	[[ "$output" == *"requires publish_token"* ]]
}
