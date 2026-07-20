#!/usr/bin/env bash
# Unit tests for lib/tui/pickers.sh layout and parsing helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
	source_lib load-modules
	launchlayer_source_tui
}

@test "tui_truncate_ellipsis shortens long strings with ellipsis suffix" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_truncate_ellipsis "SpongeBob SquarePants: The Cosmic Shake" 14
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "SpongeBob Squ…" ]]
	[[ "$output" != *"Cosmic Shake"* ]]
}

@test "tui_truncate_ellipsis leaves short strings unchanged" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_truncate_ellipsis "Overwatch" 20
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "Overwatch" ]]
}

@test "tui_sanitize_game_list_line strips ANSI and leading whitespace" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_sanitize_game_list_line $'"'"'  \033[32m2357570    yes   no    listed   unknown      Overwatch\033[0m'"'"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "2357570    yes   no    listed   unknown      Overwatch" ]]
}

@test "tui_parse_game_picker_line ignores recent marker column" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_parse_game_picker_line "* 2357570    yes   no    listed   unknown      Overwatch"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "2357570" ]]
}

@test "tui_game_picker_preview_pct honors LAUNCHLAYER_TUI_PREVIEW hidden layout" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export LAUNCHLAYER_TUI_PREVIEW=hidden
		unset TUI_GAME_PICKER_PREVIEW_PCT
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_game_picker_preview_pct
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "0" ]]
}

@test "tui_game_picker_list_width subtracts preview percentage from terminal width" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export COLUMNS=120
		export LAUNCHLAYER_TUI_PREVIEW=right:35%:wrap
		unset TUI_GAME_PICKER_PREVIEW_PCT
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_game_picker_list_width
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "75" ]]
}

@test "tui_parse_game_list_fields rejects malformed cache rows" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_parse_game_list_fields "not-an-appid yes no listed unknown Game"
	'
	[[ $status -ne 0 ]]
}

@test "tui_bulk_preset_run preview passes --dry-run to bulk_set_include_preset" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_bats_menu_stub_install
		_tui_menu_queue=("Preview (dry-run)")
		BULK_ARGS=()
		tui_run_paged() { BULK_ARGS=("$@"); return 0; }
		tui_bulk_preset_run standard 111 222
		printf "args:%s\n" "${BULK_ARGS[*]}"
		tui_bats_menu_stub_teardown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:bulk_set_include_preset standard --dry-run 111 222" ]]
}

@test "tui_bulk_preset_run apply confirms then calls bulk_set_include_preset" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules
		launchlayer_source_tui
		tui_bats_menu_stub_install
		_tui_menu_queue=("Apply")
		tui_confirm() { return 0; }
		BULK_ARGS=()
		tui_run_paged() { BULK_ARGS=("$@"); return 0; }
		tui_bulk_preset_run competitive 42424242
		printf "args:%s\n" "${BULK_ARGS[*]}"
		tui_bats_menu_stub_teardown
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:bulk_set_include_preset competitive 42424242" ]]
}
