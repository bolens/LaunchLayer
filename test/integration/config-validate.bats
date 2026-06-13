#!/usr/bin/env bash
# Integration tests for config validation and show-config.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

@test "validate-config all passes" {
	run "$SCRIPT" --validate-config all
	[[ $status -eq 0 ]]
	[[ "$output" == *"Validation passed"* ]]
}

@test "show-config for Overwatch" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --show-config 2357570
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"Launch chain"* ]]
	rm -rf "$fake_steam"
}

@test "dry-run includes config layers" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" \
		LAUNCHLAYER_PROFILES= "$SCRIPT" --dry-run /bin/echo test AppId=2357570
	rm -rf "$fake_steam"
	[[ $status -eq 0 ]] || {
		printf '# dry-run exit=%s output:\n%s\n' "$status" "$output" >&2
		return 1
	}
	[[ "$output" == *"Config layers"* ]]
}

@test "dry-run verbose includes debug layers" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" \
		LAUNCHLAYER_PROFILES= "$SCRIPT" --verbose --dry-run /bin/echo test AppId=2357570
	rm -rf "$fake_steam"
	[[ $status -eq 0 ]] || {
		printf '# dry-run exit=%s output:\n%s\n' "$status" "$output" >&2
		return 1
	}
	[[ "$output" == *"Config layers"* ]]
}

@test "show-config json for Overwatch" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --show-config 2357570 --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$fake_steam"
}

@test "validate-config json runs" {
	run "$SCRIPT" --validate-config all --json
	[[ $status -eq 0 ]]
	[[ "$output" == *'"issue_count"'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
}

@test "validate-config accepts game name" {
	[[ -f "$REPO_ROOT/examples/games/2357570.env" ]] || skip "2357570.env missing"
	run env LAUNCHLAYER_GAMES_DIR="$REPO_ROOT/examples/games" "$SCRIPT" --validate-config overwatch
	[[ $status -eq 0 ]]
}

@test "validate-config flags bad preset in temp dir" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/launch.d/presets" "$tmp/games"
	echo 'GAMEMODE=1' > "$tmp/launch.d/default.env"
	echo 'NOT_A_REAL_KEY=1' > "$tmp/launch.d/presets/bad.env"
	run env LAUNCHLAYER_CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" "$SCRIPT" --validate-config all
	[[ $status -ne 0 ]]
	[[ "$output" == *"unknown key"* || "$output" == *"Validation failed"* ]]
	rm -rf "$tmp"
}
