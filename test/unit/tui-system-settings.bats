#!/usr/bin/env bash
# Unit tests for lib/tui/menus-system-settings.sh cache report helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_tui_system_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		export TUI_CACHE_MIN_GB=7
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules inspect preflight steam
		launchlayer_source_tui
		tui_bats_menu_stub_install
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_cache_report passes min_gb mode and grep pattern to cache_report" {
	run _tui_system_shell '
		CACHE_ARGS=()
		cache_report() { CACHE_ARGS=("$@"); echo "called"; return 0; }
		tui_cache_report 9 shader "Overwatch"
		printf "args:%s\n" "${CACHE_ARGS[*]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:9 shader Overwatch 0"* ]]
}

@test "tui_cache_report_menu shader only delegates shader mode" {
	run _tui_system_shell '
		_test_shader_menu() {
			_tui_menu_queue=("Shader cache only")
			PAGED_ARGS=()
			tui_run_paged() { PAGED_ARGS=("$@"); return 0; }
			tui_cache_report_menu
			printf "args:%s\n" "${PAGED_ARGS[*]}"
		}
		_test_shader_menu
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:tui_cache_report 7 shader"* ]]
}
