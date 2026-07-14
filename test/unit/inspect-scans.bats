#!/usr/bin/env bash
# Unit tests for lib/inspect/validation.sh scan and bulk validation helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
	SCAN_TMP="$(temp_config_dir)"
	export CONFIG_DIR="$SCAN_TMP"
	export LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games"
	mkdir -p "$LAUNCHLAYER_GAMES_DIR"
	FAKE_STEAM="$(fake_steam_root 42424242 "Scan Game")"
	export STEAM_ROOT="$FAKE_STEAM"
}

teardown() {
	[[ -n "${FAKE_STEAM:-}" ]] && rm -rf "$FAKE_STEAM"
	[[ -n "${SCAN_TMP:-}" ]] && rm -rf "$SCAN_TMP"
}

@test "validate_config all reports issues across default presets and games" {
	echo 'UNKNOWN_SCAN_KEY=1' > "$SCAN_TMP/launch.d/default.env"
	echo 'BAD_GAME_KEY=1' > "$SCAN_TMP/games/42424242.env"
	run env \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			validate_config all 0 2>&1
		'
	[[ $status -ne 0 ]]
	[[ "$output" == *"unknown key: UNKNOWN_SCAN_KEY"* ]]
	[[ "$output" == *"unknown key: BAD_GAME_KEY"* ]]
}

@test "validate_config single appid targets one per-game env" {
	echo 'GAMEMODE=1' > "$SCAN_TMP/games/42424242.env"
	echo 'BAD_GAME_KEY=1' > "$SCAN_TMP/games/9999999.env"
	run env \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			validate_config 42424242 0 2>&1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Validation passed"* ]]
	[[ "$output" != *"BAD_GAME_KEY"* ]]
}

@test "scan_anticheat lists filesystem markers for installed games" {
	local game_dir="$FAKE_STEAM/steamapps/common/TestGame42424242"
	mkdir -p "$game_dir/EasyAntiCheat"
	run env \
		CONFIG_DIR="$SCAN_TMP" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			scan_anticheat 0
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"=== Anticheat scan ==="* ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" == *"yes"* ]]
}

@test "scan_detections hints DLSS_SWAPPER when nvngx present without config" {
	local game_dir="$FAKE_STEAM/steamapps/common/TestGame42424242"
	mkdir -p "$game_dir/bin"
	touch "$game_dir/bin/nvngx_dlss.dll"
	run env \
		HOME="$SCAN_TMP" \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			scan_detections
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"=== Detection audit ==="* ]]
	[[ "$output" == *"dlss present: 42424242"* ]]
	[[ "$output" == *"consider DLSS_SWAPPER=1"* ]]
}

@test "scan_detections skips DLSS hint when DLSS_SWAPPER is configured" {
	local game_dir="$FAKE_STEAM/steamapps/common/TestGame42424242"
	mkdir -p "$game_dir/bin"
	touch "$game_dir/bin/nvngx_dlss.dll"
	printf '%s\n' 'DLSS_SWAPPER=1' > "$SCAN_TMP/games/42424242.env"
	run env \
		HOME="$SCAN_TMP" \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			scan_detections
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"=== Detection audit ==="* ]]
	[[ "$output" != *"dlss present"* ]]
}

@test "scan_detections skips DLSS hint when LAUNCH_WRAPPERS includes dlss-swapper" {
	local game_dir="$FAKE_STEAM/steamapps/common/TestGame42424242"
	mkdir -p "$game_dir/bin"
	touch "$game_dir/bin/nvngx_dlss.dll"
	printf '%s\n' 'LAUNCH_WRAPPERS=dlss-swapper' > "$SCAN_TMP/games/42424242.env"
	run env \
		HOME="$SCAN_TMP" \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			scan_detections
		'
	[[ $status -eq 0 ]]
	[[ "$output" != *"dlss present"* ]]
}

@test "scan_detections skips DLSS hint when PROTON_DLSS_UPGRADE=1 is configured" {
	local game_dir="$FAKE_STEAM/steamapps/common/TestGame42424242"
	mkdir -p "$game_dir/bin"
	touch "$game_dir/bin/nvngx_dlss.dll"
	printf '%s\n' 'PROTON_DLSS_UPGRADE=1' > "$SCAN_TMP/games/42424242.env"
	run env \
		HOME="$SCAN_TMP" \
		CONFIG_DIR="$SCAN_TMP" \
		LAUNCHLAYER_GAMES_DIR="$SCAN_TMP/games" \
		STEAM_ROOT="$FAKE_STEAM" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform steam keys config inspect
			scan_detections
		'
	[[ $status -eq 0 ]]
	[[ "$output" != *"dlss present"* ]]
}
