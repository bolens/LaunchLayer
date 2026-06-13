#!/usr/bin/env bash
# Unit tests for additional dispatch-config environment and edit routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_config_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli
		'"$1"'
	'
}

@test "dispatch_config_subcommand detect-environment passes json flag" {
	run _dispatch_config_shell '
		source_lib platform config detected-defaults environment
		show_detect_environment() { printf "detect:%s\n" "$1"; }
		dispatch_config_subcommand --detect-environment --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"detect:--json"* || "$output" == *"detect:"* ]]
}

@test "dispatch_config_subcommand edit-appid requires query" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam
		dispatch_config_subcommand --edit-appid 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_config_subcommand edit-appid invokes editor on resolved path" {
	local fake_steam tmp editor
	fake_steam="$(fake_steam_root 42424242 "Edit Game")"
	tmp="$(temp_config_dir)"
	editor="$tmp/fake-editor"
	cat > "$editor" <<'EOF'
#!/bin/sh
printf 'edit:%s\n' "$1"
EOF
	chmod +x "$editor"
	mkdir -p "$tmp/games"
	printf 'INCLUDE=presets/standard.env\n' > "$tmp/games/42424242.env"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		EDITOR="$editor" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands platform config inspect steam
			dispatch_config_subcommand --edit-appid 42424242
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"edit:"* ]]
	[[ "$output" == *"42424242.env"* ]]
	rm -rf "$fake_steam" "$tmp"
}

@test "handle_subcommand routes detect-environment through config dispatch" {
	run _dispatch_config_shell '
		source_lib platform config detected-defaults environment
		show_detect_environment() { echo detect-called; }
		handle_subcommand --detect-environment
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"detect-called"* ]]
}

@test "handle_subcommand routes edit-appid through config dispatch" {
	run _dispatch_config_shell '
		source_lib platform config inspect steam games
		edit_appid_config() { printf "edit:%s\n" "$1"; }
		handle_subcommand --edit-appid 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"edit:42424242"* ]]
}
