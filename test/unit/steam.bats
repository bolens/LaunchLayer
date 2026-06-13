#!/usr/bin/env bash
# Unit tests for lib/steam.sh helpers.
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
		(( ${#roots[@]} == 2 ))
	'
	[[ $status -eq 0 ]]
	rm -rf "$tmp"
}
