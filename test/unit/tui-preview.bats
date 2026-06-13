#!/usr/bin/env bash
# Unit tests for TUI preview helpers (non-interactive).
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_tui_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli load-modules
		launchlayer_source_tui
		'"$1"'
	'
}

@test "tui_render_game_preview prints include and toggle section for appid" {
	[[ -f "$CONFIG_DIR/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_DIR/examples/games" \
		bash -c '
			export CONFIG_DIR="'"$CONFIG_DIR"'"
			export NO_COLOR=1
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib load-modules
			launchlayer_load_post_main
			launchlayer_source_tui
			tui_render_game_preview 2357570
		'
	rm -rf "$fake_steam"
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"INCLUDE="* ]]
	[[ "$output" == *"Toggles"* ]]
}

@test "dispatch_tui_subcommand tui-game-preview delegates to preview renderer" {
	run _dispatch_tui_shell '
		tui_render_game_preview() { printf "preview:%s\n" "$1"; }
		dispatch_tui_subcommand --tui-game-preview 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"preview:42424242"* ]]
}

@test "dispatch_tui_subcommand tui-game-preview requires appid" {
	run _dispatch_tui_shell '
		dispatch_tui_subcommand --tui-game-preview 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "tui_render_game_preview_line parses picker row then renders preview" {
	[[ -f "$CONFIG_DIR/examples/games/2357570.env" ]] || skip "2357570.env missing"
	local fake_steam
	fake_steam="$(fake_steam_root 2357570 "Overwatch")"
	run env \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$CONFIG_DIR/examples/games" \
		bash -c '
			export CONFIG_DIR="'"$CONFIG_DIR"'"
			export NO_COLOR=1
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib load-modules
			launchlayer_load_post_main
			launchlayer_source_tui
			sample="2357570    yes   no    listed   unknown      Overwatch"
			line="$(tui_format_game_picker_row "$sample" | tui_strip_ansi)"
			tui_render_game_preview_line "$line" | head -n 2
		'
	rm -rf "$fake_steam"
	[[ $status -eq 0 ]]
	[[ "$output" == *"2357570"* ]]
	[[ "$output" == *"INCLUDE="* ]]
}

@test "tui_panel_preview_for_selection non-Status row renders panel output" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_panel_render() { echo panel-body; }
		tui_panel_preview_for_selection "Browse & configure game"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "panel-body" ]]
}

@test "dispatch_tui_subcommand tui-panel-preview Status shows status page" {
	run _dispatch_tui_shell '
		tui_render_status_page() { echo status-preview; }
		dispatch_tui_subcommand --tui-panel-preview Status
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"status-preview"* ]]
}

@test "tui_panel_preview_for_selection strips tab suffix before Status routing" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_render_status_page() { echo status-preview; }
		tui_panel_preview_for_selection $'"'"'Status\textra-column'"'"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"status-preview"* ]]
}

@test "dispatch_tui_subcommand tui-panel-preview routes tabbed Status selection" {
	run _dispatch_tui_shell '
		tui_render_status_page() { echo status-preview; }
		dispatch_tui_subcommand --tui-panel-preview $'"'"'Status\textra'"'"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"status-preview"* ]]
}
