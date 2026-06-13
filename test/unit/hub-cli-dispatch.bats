#!/usr/bin/env bash
# Unit tests for hub publish/update via dispatch routers against mock hub.
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

_hub_fixture() {
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
	printf '%s\n' "$tmp" "$games"
}

@test "dispatch_hub_subcommand hub-publish uploads valid game config" {
	local paths tmp games
	paths=($(_hub_fixture))
	tmp="${paths[0]}"
	games="${paths[1]}"
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform hardware cli tools config inspect
			dispatch_hub_subcommand --hub-publish 42424242 --json
		'
	rm -rf "$tmp"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id"'* ]]
}

@test "dispatch_hub_subcommand hub-update updates existing mock config" {
	local paths tmp games
	paths=($(_hub_fixture))
	tmp="${paths[0]}"
	games="${paths[1]}"
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands hub prefs platform hardware cli tools config inspect
			dispatch_hub_subcommand --hub-update 42424242 --json
		'
	rm -rf "$tmp"
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfgtest00001"* || "$output" == *'"updated"'* ]]
}

@test "handle_subcommand routes hub-publish through hub dispatch" {
	local paths tmp games
	paths=($(_hub_fixture))
	tmp="${paths[0]}"
	games="${paths[1]}"
	run env \
		XDG_CONFIG_HOME="$HUB_TMP" \
		CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands cli hub prefs platform hardware tools config inspect
			handle_subcommand --hub-publish 42424242 --json
		'
	rm -rf "$tmp"
	[[ $status -eq 0 ]]
	[[ "$output" == *'"config_id"'* ]]
}
