#!/usr/bin/env bash
# Unit tests for dispatch-tui non-interactive subcommands.
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

@test "dispatch_tui_subcommand tui-help routes topic to overlay helper" {
	run _dispatch_tui_shell '
		tui_show_help_overlay() { printf "help:%s\n" "$1"; }
		dispatch_tui_subcommand --tui-help game
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"help:game"* ]]
}

@test "dispatch_tui_subcommand tui-panel renders panel output" {
	run _dispatch_tui_shell '
		tui_panel_render() { echo panel-rendered; }
		dispatch_tui_subcommand --tui-panel
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"panel-rendered"* ]]
}

@test "dispatch_tui_subcommand tui-status-page renders status dashboard" {
	run _dispatch_tui_shell '
		tui_render_status_page() { echo status-page; }
		dispatch_tui_subcommand --tui-status-page
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"status-page"* ]]
}

@test "dispatch_tui_subcommand tui-quick-toggles-reload requires appid" {
	run _dispatch_tui_shell '
		dispatch_tui_subcommand --tui-quick-toggles-reload 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}

@test "dispatch_tui_subcommand tui-quick-toggles-reload delegates appid" {
	run _dispatch_tui_shell '
		tui_quick_toggles_reload() { printf "reload:%s\n" "$1"; }
		dispatch_tui_subcommand --tui-quick-toggles-reload 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"reload:42424242"* ]]
}

@test "dispatch_tui_subcommand tui-games-menu-header delegates to header helper" {
	run _dispatch_tui_shell '
		tui_games_menu_header() { echo games-header; }
		dispatch_tui_subcommand --tui-games-menu-header
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"games-header"* ]]
}

@test "dispatch_tui_subcommand tui-game-preview-line requires picker row" {
	run _dispatch_tui_shell '
		dispatch_tui_subcommand --tui-game-preview-line 2>&1
	'
	[[ $status -eq 1 ]]
	[[ "$output" == *"Usage:"* ]]
}
