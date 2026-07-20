#!/usr/bin/env bash
# Unit tests for per-game TUI toggle and config helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
	TUI_TMP="$(temp_config_dir)"
	export CONFIG_DIR="$TUI_TMP"
	export LAUNCHLAYER_GAMES_DIR="$TUI_TMP/games"
	mkdir -p "$LAUNCHLAYER_GAMES_DIR"
	FAKE_STEAM="$(fake_steam_root 42424242 "Toggle Game")"
	export STEAM_ROOT="$FAKE_STEAM"
	export LAUNCHLAYER_PROFILES=
}

teardown() {
	[[ -n "${FAKE_STEAM:-}" ]] && rm -rf "$FAKE_STEAM"
	[[ -n "${TUI_TMP:-}" ]] && rm -rf "$TUI_TMP"
}

_tui_game_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_GAMES_DIR="'"$LAUNCHLAYER_GAMES_DIR"'"
		export STEAM_ROOT="'"$STEAM_ROOT"'"
		export LAUNCHLAYER_PROFILES=
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_load_post_main
		launchlayer_source_tui
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		default_online_cpus() { echo 0-3; }
		'"$1"'
	'
}

@test "tui_env_upsert inserts and replaces keys in per-game env" {
	run _tui_game_shell '
		file="'"$LAUNCHLAYER_GAMES_DIR"'/42424242.env"
		printf "%s\n" "GAMEMODE=1" > "$file"
		tui_env_upsert "$file" "MANGOHUD" "1"
		tui_env_upsert "$file" "GAMEMODE" "0"
		sort "$file"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMEMODE=0"* ]]
	[[ "$output" == *"MANGOHUD=1"* ]]
	[[ "$output" != *"GAMEMODE=1"* ]]
}

@test "tui_format_toggle_option labels inherited vs override" {
	run _tui_game_shell '
		appid=42424242
		tui_ensure_appid_env "$appid"
		prepare_launch_context "$appid"
		inherited="$(tui_format_toggle_option "$appid" GAMEMODE | tui_strip_ansi)"
		tui_env_upsert "$(tui_appid_env_path "$appid")" "GAMEMODE" "0"
		prepare_launch_context "$appid"
		override="$(tui_format_toggle_option "$appid" GAMEMODE | tui_strip_ansi)"
		printf "inherited:%s\n" "$inherited"
		printf "override:%s\n" "$override"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"inherited:"*"(inherited)"* ]]
	[[ "$output" == *"override:"*"(override)"* ]]
}

@test "tui_toggle_key_from_option extracts config key from menu row" {
	run _tui_game_shell 'tui_toggle_key_from_option "GAMEMODE=1  (override)"'
	[[ $status -eq 0 ]]
	[[ "$output" == "GAMEMODE" ]]

	run _tui_game_shell 'tui_toggle_key_from_option "MANGOHUD=○  (inherited)"'
	[[ $status -eq 0 ]]
	[[ "$output" == "MANGOHUD" ]]
}

@test "tui_toggle_game_key flips effective boolean in per-game env" {
	run _tui_game_shell '
		appid=42424242
		tui_ensure_appid_env "$appid"
		prepare_launch_context "$appid"
		before="$GAMEMODE"
		tui_toggle_game_key "$appid" GAMEMODE
		prepare_launch_context "$appid"
		printf "before:%s after:%s file:%s\n" "$before" "$GAMEMODE" "$(grep ^GAMEMODE= "$(tui_appid_env_path "$appid")")"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"before:1"* ]]
	[[ "$output" == *"after:0"* ]]
	[[ "$output" == *"file:GAMEMODE=0"* ]]
}

@test "tui_quick_toggles_reload lists toggle keys and footer actions" {
	run _tui_game_shell '
		appid=42424242
		tui_ensure_appid_env "$appid"
		tui_quick_toggles_reload "$appid"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GAMEMODE"* ]]
	[[ "$output" == *"MANGOHUD"* ]]
	[[ "$output" == *"DLSS_SWAPPER"* ]]
	[[ "$output" == *"Clear override (inherit from layers)"* ]]
	[[ "$output" == *"Clear ALL overrides"* ]]
	[[ "$output" == *"Back"* ]]
}

@test "tui_quick_toggles_flip toggles selected key from menu row" {
	run _tui_game_shell '
		appid=42424242
		tui_ensure_appid_env "$appid"
		prepare_launch_context "$appid"
		row="$(tui_format_toggle_option "$appid" MANGOHUD | tui_strip_ansi)"
		tui_quick_toggles_flip "$appid" "$row"
		grep ^MANGOHUD= "$(tui_appid_env_path "$appid")" || exit 1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"MANGOHUD=1"* ]]
}

@test "tui_toggle_game_key enables DLSS_SWAPPER override" {
	run _tui_game_shell '
		appid=42424242
		tui_ensure_appid_env "$appid"
		prepare_launch_context "$appid"
		printf "before:%s\n" "${DLSS_SWAPPER:-unset}"
		tui_toggle_game_key "$appid" DLSS_SWAPPER
		prepare_launch_context "$appid"
		printf "after:%s file:%s\n" "$DLSS_SWAPPER" "$(grep ^DLSS_SWAPPER= "$(tui_appid_env_path "$appid")")"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"before:0"* ]]
	[[ "$output" == *"after:1"* ]]
	[[ "$output" == *"file:DLSS_SWAPPER=1"* ]]
}

@test "tui_suggest_config_menu preview delegates to suggest_config" {
	run _tui_game_shell '
		tui_bats_menu_stub_install
		_tui_menu_queue=("Preview suggestions")
		SUGGEST_ARGS=()
		tui_run_paged() { SUGGEST_ARGS=("$@"); return 0; }
		tui_suggest_config_menu 42424242
		printf "args:%s\n" "${SUGGEST_ARGS[*]}"
		tui_bats_menu_stub_teardown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:suggest_config 42424242 0" ]]
}

@test "tui_suggest_config_menu apply confirms then calls suggest_config" {
	run _tui_game_shell '
		tui_bats_menu_stub_install
		_tui_menu_queue=("Apply allowlisted knobs")
		tui_confirm() { return 0; }
		SUGGEST_ARGS=()
		tui_run_capture() { shift; SUGGEST_ARGS=("$@"); return 0; }
		tui_suggest_config_menu 42424242
		printf "args:%s\n" "${SUGGEST_ARGS[*]}"
		tui_bats_menu_stub_teardown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:suggest_config 42424242 1" ]]
}

@test "tui_game_actions runtime status delegates to show_status with appid" {
	run _tui_game_shell '
		tui_bats_menu_stub_install
		_tui_menu_queue=("[View] Runtime status" "Back to games menu")
		tui_crumb_enter() { :; }
		tui_crumb_leave() { :; }
		tui_game_validation_label() { echo "config ok"; }
		STATUS_ARGS=()
		tui_run_paged() { STATUS_ARGS=("$@"); return 0; }
		tui_game_actions 42424242
		printf "args:%s\n" "${STATUS_ARGS[*]}"
		tui_bats_menu_stub_teardown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:show_status 42424242"* ]]
}
