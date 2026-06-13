#!/usr/bin/env bash
# Unit tests for lib/steam/ helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "manifest_field extracts quoted values" {
	local tmp manifest
	tmp="$(mktemp -d)"
	manifest="$tmp/appmanifest_42424242.acf"
	cat > "$manifest" <<'EOF'
"AppState"
{
	"appid"		"42424242"
	"name"		"Test Game"
	"installdir"		"TestGame"
}
EOF
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		manifest_field "'"$manifest"'" name
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "Test Game" ]]
	rm -rf "$tmp"
}

@test "find_app_manifest locates fake steam game" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Test Game")"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		find_app_manifest 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"appmanifest_42424242.acf" ]]
	rm -rf "$fake_steam"
}

@test "get_game_name resolves installed appid" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Test Game")"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		get_game_name 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "Test Game" ]]
	rm -rf "$fake_steam"
}

@test "resolve_appid_query accepts numeric appid" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Test Game")"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		resolve_appid_query 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "42424242" ]]
	rm -rf "$fake_steam"
}

@test "resolve_appid_query fails for missing appid" {
	run env STEAM_ROOT=/tmp/no-steam-$$ bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		resolve_appid_query 99999999 2>&1
		ec=$?
		exit "$ec"
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"not found"* ]]
}

@test "steam_add_library_root deduplicates paths" {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/a" "$tmp/b"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		roots=()
		steam_add_library_root "'"$tmp"'/a" roots
		steam_add_library_root "'"$tmp"'/a" roots
		steam_add_library_root "'"$tmp"'/b" roots
		printf "%s\n" "${roots[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$(echo "$output" | wc -l)" -eq 2 ]]
	[[ "$output" == *"$tmp/a"* ]]
	[[ "$output" == *"$tmp/b"* ]]
	rm -rf "$tmp"
}

@test "detect_native_game honors FORCE_NATIVE without install dir" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export FORCE_NATIVE=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_native_game 99999999 0 && echo native || echo proton
	'
	[[ $status -eq 0 ]]
	[[ "$output" == native ]]
}

@test "detect_native_game honors FORCE_PROTON over FORCE_NATIVE" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export FORCE_PROTON=1 FORCE_NATIVE=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_native_game 99999999 0 && echo native || echo proton
	'
	[[ $status -eq 0 ]]
	[[ "$output" == proton ]]
}

@test "detect_native_game detects launcher.sh in install dir" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Native Game" NativeGame)"
	mkdir -p "$fake_steam/steamapps/common/NativeGame"
	printf '#!/bin/sh\n' > "$fake_steam/steamapps/common/NativeGame/launcher.sh"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_native_game 42424242 1 && echo native || echo proton
	'
	[[ $status -eq 0 ]]
	[[ "$output" == native ]]
	rm -rf "$fake_steam"
}

@test "detect_anticheat_in_list matches anticheat-appids.txt" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_anticheat_in_list 2357570 && echo listed || echo not-listed
	'
	[[ $status -eq 0 ]]
	[[ "$output" == listed ]]

	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_anticheat_in_list 42424242 && echo listed || echo not-listed
	'
	[[ $status -eq 0 ]]
	[[ "$output" == not-listed ]]
}

@test "detect_anticheat_filesystem finds EasyAntiCheat markers" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "EAC Game" EacGame)"
	mkdir -p "$fake_steam/steamapps/common/EacGame/EasyAntiCheat"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_anticheat_filesystem 42424242
	'
	[[ $status -eq 0 ]]
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_anticheat_type 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "eac" ]]
	rm -rf "$fake_steam"
}

@test "suggest_preset_for_appid picks native competitive standard" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "EAC Game" EacGame)"
	mkdir -p "$fake_steam/steamapps/common/EacGame/EasyAntiCheat"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		suggest_preset_for_appid 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "competitive" ]]
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		suggest_preset_for_appid 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "standard" ]]
	rm -rf "$fake_steam"
}

@test "resolve_game_flags populates launch globals" {
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		steam_app_id=2357570
		resolve_game_flags
		echo "anticheat:$is_anticheat name:$steam_game_name"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "anticheat:1 name:Overwatch" ]]
	rm -rf "$fake_steam"
}

@test "detect_dlss_present finds nvngx libraries" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "DLSS Game" DlssGame)"
	mkdir -p "$fake_steam/steamapps/common/DlssGame/bin"
	touch "$fake_steam/steamapps/common/DlssGame/bin/nvngx_dlss.dll"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_dlss_present 42424242 && echo dlss || echo no-dlss
	'
	[[ $status -eq 0 ]]
	[[ "$output" == dlss ]]
	rm -rf "$fake_steam"
}

@test "detect_dlss_present returns false without nvngx libraries" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Plain Game" PlainGame)"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_dlss_present 42424242 && echo dlss || echo no-dlss
	'
	[[ $status -eq 0 ]]
	[[ "$output" == no-dlss ]]
	rm -rf "$fake_steam"
}

@test "is_skippable_steam_package ignores runtimes and proton tools" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		is_skippable_steam_package "Steam Linux Runtime 3.0 (soldier)" && echo skip || echo game
	'
	[[ $status -eq 0 ]]
	[[ "$output" == skip ]]

	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		is_skippable_steam_package "Overwatch" && echo skip || echo game
	'
	[[ $status -eq 0 ]]
	[[ "$output" == game ]]
}

@test "game_name_matches_grep is case insensitive" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		game_name_matches_grep "Counter-Strike 2" strike && echo match || echo miss
	'
	[[ $status -eq 0 ]]
	[[ "$output" == match ]]

	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam
		game_name_matches_grep "Counter-Strike 2" zelda && echo match || echo miss
	'
	[[ $status -eq 0 ]]
	[[ "$output" == miss ]]
}

@test "detect_anticheat_filesystem finds BattlEye markers" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "BE Game" BeGame)"
	mkdir -p "$fake_steam/steamapps/common/BeGame/BattlEye"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib steam config
		detect_anticheat_type 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "battleye" ]]
	rm -rf "$fake_steam"
}
