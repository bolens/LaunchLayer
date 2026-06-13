#!/usr/bin/env bash
# Unit tests for lib/hub/client.sh payload builders.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib hub cli
}

@test "hub_settings_json_for_publish strips source fields" {
	local raw='[{"key":"GAMEMODE","value":"1","source":"default.env"}]'
	run hub_settings_json_for_publish "$raw"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"key":"GAMEMODE"'* ]]
	[[ "$output" == *'"value":"1"'* ]]
	[[ "$output" != *source* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d[0]=={"key":"GAMEMODE","value":"1"}' "$output"
}

@test "hub_recommend_payload includes fingerprint hash and limit" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux"],"display_tier":"1440p","refresh_tier":"mid75_120","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run hub_recommend_payload "$fp" 2357570 5
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	[[ "$output" == *'"limit":5'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["limit"]==5 and d["appid"]=="2357570"' "$output"
}

@test "hub_format_published_at formats unix milliseconds" {
	run hub_format_published_at 1704067200000
	[[ $status -eq 0 ]]
	[[ "$output" == "2024-01-01" ]]
}

@test "hub_format_recommend_response_cli includes updated date" {
	local response='{"results":[{"config_id":"cfg1","similarity":88,"machine_label":"battlestation","gpu_vendor":"nvidia","note":"stable","published_at":1704067200000}]}'
	run hub_format_recommend_response_cli "$response"
	[[ $status -eq 0 ]]
	[[ "$output" == *"88%"* ]]
	[[ "$output" == *"updated 2024-01-01"* ]]
	[[ "$output" == *"id=cfg1"* ]]
}

@test "hub_curl_json fails when hub url is unset" {
	local tmp
	tmp="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$tmp" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib prefs hub
		hub_curl_json GET /api/health 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Hub URL is not configured"* ]]
	rm -rf "$tmp"
}

@test "hub_publish_payload includes config_id when updating" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux"],"display_tier":"1440p","refresh_tier":"mid75_120","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run hub_publish_payload "$fp" 42424242 "Test Game" "GAMEMODE=1" "note" "cfg-existing"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id":"cfg-existing"'* || "$output" == *'"config_id": "cfg-existing"'* ]]
}

@test "hub_my_config_payload includes fingerprint hash and appid" {
	local fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","profiles":[],"display_tier":"1440p","vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run hub_my_config_payload "$fp" 42424242
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["appid"]=="42424242" and d["fingerprint_hash"]' "$output"
}

@test "hub_publish_payload includes app metadata" {
	local tmp games fp
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games" "$tmp/launch.d/presets"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'MANGOHUD=0' > "$tmp/launch.d/presets/standard.env"
	cat > "$games/42424242.env" <<'EOF'
# Test Game (Steam AppID 42424242)
INCLUDE=presets/standard.env
GAMEMODE=1
EOF
	fp='{"gpu_vendor":"nvidia","os_family":"arch","session_type":"wayland","desktop":"kde","profiles":["arch-linux"],"display_tier":"1440p","refresh_tier":"mid75_120","has_x3d":false,"vrr":false,"wsl2":false,"flatpak_steam":false,"steam_deck":false,"immutable":false,"container":false}'
	run env \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		LAUNCHLAYER_TEST_FP="$fp" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib hub cli config steam platform
			hub_publish_payload "$LAUNCHLAYER_TEST_FP" 42424242 "Test Game" "$(cat "'"$games"'/42424242.env")" "note"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid":"42424242"'* || "$output" == *'"appid": "42424242"'* ]]
	[[ "$output" == *'"note"'* ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["appid"]=="42424242"' "$output"
	rm -rf "$tmp"
}
