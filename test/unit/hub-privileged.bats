#!/usr/bin/env bash
# Unit tests for privileged hub client auth (publish/delete) against a local mock server.
load '../helpers.bash'

setup() {
	bats_unit_setup
	export XDG_CONFIG_HOME
	XDG_CONFIG_HOME="$(mktemp -d)"
	export XDG_CONFIG_HOME
	SCRIPT="$(launchlayer_script)"
	export SCRIPT
	source_lib commands prefs platform hardware cli tools hub
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
	[[ -z "$output" ]]
	[[ ! "$output" == *"requires publish_token"* ]]
}

@test "hub_delete_payload emits config_id and fingerprint_hash JSON" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux"],"display_tier":"1440p","refresh_tier":"mid75_120","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run hub_delete_payload "cfg-abc-123" "$fp"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id"'* ]]
	[[ "$output" == *'"fingerprint_hash"'* ]]
	[[ "$output" == *"cfg-abc-123"* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["config_id"]=="cfg-abc-123"; assert len(d["fingerprint_hash"])==64' "$output"
}

@test "hub_curl_json rejects privileged delete without local token" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","profiles":[],"display_tier":"1440p","vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfg-1 "$fp")" 1
	[[ $status -eq 1 ]]
	[[ "$output" == *"requires publish_token"* ]]
}

@test "hub_curl_json privileged delete succeeds with matching token" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","profiles":[],"display_tier":"1440p","vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfg-ok "$fp")" 1
	[[ $status -eq 0 ]]
	[[ "$output" == *'"deleted_config_id"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["deleted_config_id"]=="cfg-ok"' "$output"
}

@test "hub_curl_json privileged delete returns 401 message for wrong token" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","profiles":[],"display_tier":"1440p","vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" wrong-token minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfg-1 "$fp")" 1
	[[ $status -eq 1 ]]
	[[ "$output" == *"unauthorized"* || "$output" == *"401"* ]]
}

@test "hub_curl_json privileged delete surfaces 404 from hub" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","profiles":[],"display_tier":"1440p","vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_curl_json POST /api/delete "$(hub_delete_payload cfgnotfound1 "$fp")" 1
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
	run hub_delete_config cfgdelete001 --yes --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"deleted_config_id"'* ]]
	[[ "$output" == *"cfgdelete001"* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["deleted_config_id"]=="cfgdelete001"' "$output"
}

@test "hub_delete_config fails without token when auth enforced" {
	run hub_delete_config cfgdelete001 --yes --json
	[[ $status -eq 1 ]]
	[[ "$output" == *"requires publish_token"* ]]
}

@test "hub_validate_local_env_file rejects unknown keys before publish" {
	source_lib inspect
	local cfg
	cfg="$(mktemp)"
	printf 'NOT_A_REAL_LAUNCHLAYER_KEY=1\n' > "$cfg"
	run hub_validate_local_env_file "$cfg" "test config"
	rm -f "$cfg"
	[[ $status -eq 1 ]]
	[[ "$output" == *"failed validation"* ]]
}

@test "hub_publish_config rejects invalid local env before upload" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	printf 'NOT_A_REAL_LAUNCHLAYER_KEY=1\n' > "$games/42424242.env"
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands prefs platform hardware cli tools config inspect hub
			hub_publish_config 42424242
		'
	rm -rf "$tmp"
	[[ $status -eq 1 ]]
	[[ "$output" == *"failed validation"* ]]
}

@test "launchlayer hub-publish rejects invalid local env before upload" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	printf 'NOT_A_REAL_LAUNCHLAYER_KEY=1\n' > "$games/42424242.env"
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		HOME="$XDG_CONFIG_HOME" \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		"$SCRIPT" --hub-publish 42424242
	rm -rf "$tmp"
	[[ $status -eq 1 ]]
	[[ "$output" == *"failed validation"* ]]
}

@test "hub_publish_result_message distinguishes create vs update" {
	run hub_publish_result_message "Test Game" 42424242 '{"config_id":"cfgtest00001","updated":false}'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Published new hub config"* ]]
	[[ "$output" == *"cfgtest00001"* ]]

	run hub_publish_result_message "Test Game" 42424242 '{"config_id":"cfgtest00001","updated":true}'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Updated hub config"* ]]
	[[ "$output" == *"cfgtest00001"* ]]
}

@test "hub_delete_config rejects invalid config id before request" {
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run hub_delete_config cfg-test-1 --yes --json
	[[ $status -eq 1 ]]
	[[ "$output" == *"Invalid hub config ID"* ]]
}

@test "hub_publish_config rejects untrusted PRE_LAUNCH_CMD before upload" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	cat > "$games/42424242.env" <<'EOF'
INCLUDE=presets/standard.env
GAMEMODE=1
PRE_LAUNCH_CMD=echo should-not-publish
EOF
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands prefs platform hardware cli tools config inspect hub
			hub_publish_config 42424242 --json 2>&1
		'
	rm -rf "$tmp"
	[[ $status -eq 1 ]]
	[[ "$output" == *"Cannot publish"* ]]
	[[ "$output" == *"PRE_LAUNCH_CMD"* ]]
}

@test "hub_update_config rejects invalid local env before upload" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	printf 'NOT_A_REAL_LAUNCHLAYER_KEY=1\n' > "$games/42424242.env"
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands prefs platform hardware cli tools config inspect hub
			hub_update_config 42424242 --json
		'
	rm -rf "$tmp"
	[[ $status -eq 1 ]]
	[[ "$output" == *"failed validation"* ]]
}

@test "hub_update_config updates existing config via mock hub" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	cat > "$games/42424242.env" <<'EOF'
INCLUDE=presets/standard.env
GAMEMODE=1
MANGOHUD=1
EOF
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands prefs platform hardware cli tools config inspect hub
			hub_update_config 42424242 --json
		'
	rm -rf "$tmp"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"updated":true'* || "$output" == *'"updated": true'* ]]
	[[ "$output" == *"cfgtest00001"* ]]
}

@test "launchlayer hub-update updates existing config via mock hub" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	printf 'GAMEMODE=1\n' > "$tmp/launch.d/default.env"
	printf 'MANGOHUD=0\n' > "$tmp/launch.d/presets/standard.env"
	cat > "$games/42424242.env" <<'EOF'
INCLUDE=presets/standard.env
GAMEMODE=1
MANGOHUD=1
EOF
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
	run env \
		HOME="$XDG_CONFIG_HOME" \
		XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		"$SCRIPT" --hub-update 42424242 --json
	rm -rf "$tmp"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"updated":true'* || "$output" == *'"updated": true'* ]]
	[[ "$output" == *"cfgtest00001"* ]]
}
