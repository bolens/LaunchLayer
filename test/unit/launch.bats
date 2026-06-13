#!/usr/bin/env bash
# Unit tests for lib/launch.sh orchestration helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "detect_steam_app_id reads SteamAppId env" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export SteamAppId=42424242
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		detect_steam_app_id
		echo "appid:$steam_app_id"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "appid:42424242" ]]
}

@test "detect_steam_app_id parses AppId launch argv" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		detect_steam_app_id /path/steam -applaunch 12345
		echo "appid:$steam_app_id"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "appid:12345" ]]
}

@test "load_config_file follows INCLUDE chain" {
	local tmp
	tmp="$(temp_config_dir)"
	echo 'GAMEMODE=0' > "$tmp/launch.d/presets/base.env"
	echo 'INCLUDE=presets/base.env' > "$tmp/launch.d/local.env"
	echo 'MANGOHUD=1' >> "$tmp/launch.d/local.env"
	run env CONFIG_DIR="$tmp" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		load_config_file "'"$tmp"'/launch.d/local.env" 0
		printf "gamemode:%s mangohud:%s layers:%s\n" "$GAMEMODE" "$MANGOHUD" "${#config_layers[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "gamemode:0 mangohud:1 layers:2" ]]
	rm -rf "$tmp"
}

@test "load_launch_config auto-selects native preset" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Native Game" NativeGame)"
	tmp="$(temp_config_dir)"
	echo 'GAMEMODE=0' > "$tmp/launch.d/presets/native.env"
	mkdir -p "$fake_steam/steamapps/common/NativeGame"
	printf '#!/bin/sh\n' > "$fake_steam/steamapps/common/NativeGame/launcher.sh"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_PROFILES= \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib keys config steam
			steam_app_id=42424242
			load_launch_config
			printf "gamemode:%s\n" "$GAMEMODE"
			printf "%s\n" "${config_layers[@]}"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"gamemode:1"* ]]
	[[ "$output" == *"presets/native.env"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "prepare_launch_context loads config and builds chain" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Chain Game")"
	tmp="$(temp_config_dir)"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_PROFILES= \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform keys config steam hardware runtime detected-defaults gpu preflight vram launch
			optional_tool_installed() { return 1; }
			command_available() { return 1; }
			default_online_cpus() { echo 0-3; }
			prepare_launch_context 42424242
			echo "appid:$steam_app_id name:$steam_game_name layers:${#config_layers[@]}"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"appid:42424242"* ]]
	[[ "$output" == *"name:Chain Game"* ]]
	[[ "$output" == *"layers:"* ]]
	rm -rf "$fake_steam" "$tmp"
}
