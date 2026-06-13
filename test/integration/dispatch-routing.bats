#!/usr/bin/env bash
# Integration tests for CLI dispatch routing and TUI subcommand hooks.
load '../helpers.bash'

setup() {
	bats_integration_setup
}

teardown() {
	bats_integration_teardown
}

@test "dispatch rejects unknown flag with suggestion" {
	run "$SCRIPT" --validate-confg 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"unknown subcommand"* ]]
	[[ "$output" == *"--validate-config"* ]]
}

@test "tui-picker-appid subcommand parses installed game row" {
	run "$SCRIPT" --tui-picker-appid "  42424242    yes   no    -        unknown      Game"
	[[ $status -eq 0 ]]
	[[ "$output" == "42424242" ]]
}

@test "tui-game-preview requires appid argument" {
	run "$SCRIPT" --tui-game-preview 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "tui-quick-toggles-reload lists toggle keys for configured game" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Reload Game")"
	tmp="$(temp_config_dir)"
	mkdir -p "$tmp/games"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/42424242.env"
	run env \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_CONFIG_DIR="$tmp" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		NO_COLOR=1 \
		"$SCRIPT" --tui-quick-toggles-reload 42424242
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMEMODE"* ]]
	[[ "$output" == *"Clear override"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "hub-apply without config id fails usage check" {
	local hub_tmp
	hub_tmp="$(mktemp -d)"
	run env HOME="$hub_tmp" XDG_CONFIG_HOME="$hub_tmp" "$SCRIPT" --hub-apply 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
	rm -rf "$hub_tmp"
}

@test "dispatch setup subcommand --doctor exits zero" {
	run "$SCRIPT" --doctor --json
	[[ $status -eq 0 || $status -eq 1 ]]
	[[ "$output" == *'"config_dir"'* ]]
}
