#!/usr/bin/env bash
# Unit tests for lib/tui/menus-config.sh delegate flows (non-interactive).
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_tui_config_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules inspect setup config
		launchlayer_source_tui
		tui_bats_menu_stub_install
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_anticheat_menu scan delegates to scan_anticheat without list update" {
	run _tui_config_shell '
		_test_anticheat_scan() {
			_tui_menu_queue=("Scan anticheat (filesystem vs list)")
			SCAN_ARGS=()
			tui_run_paged() { SCAN_ARGS=("$@"); return 0; }
			tui_anticheat_menu
			printf "args:%s\n" "${SCAN_ARGS[*]}"
		}
		_test_anticheat_scan
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:scan_anticheat 0" ]]
}

@test "tui_write_local_config_menu preview delegates to write_local_config dry-run" {
	run _tui_config_shell '
		_test_write_preview() {
			_tui_menu_queue=("Preview detected defaults")
			WRITE_ARGS=()
			tui_run_paged() { WRITE_ARGS=("$@"); return 0; }
			tui_write_local_config_menu
			printf "args:%s\n" "${WRITE_ARGS[*]}"
		}
		_test_write_preview
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:write_local_config 0 1" ]]
}

@test "tui_init_unconfigured_menu preview delegates to init_unconfigured dry-run" {
	run _tui_config_shell '
		_test_init_preview() {
			_tui_menu_queue=("Preview (dry-run, suggested presets)")
			INIT_ARGS=()
			tui_run_paged() { INIT_ARGS=("$@"); return 0; }
			tui_init_unconfigured_menu
			printf "args:%s\n" "${INIT_ARGS[*]}"
		}
		_test_init_preview
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:init_unconfigured  1 0" ]]
}

@test "tui_prune_uninstalled_menu preview delegates to prune dry-run" {
	run _tui_config_shell '
		_test_prune_preview() {
			_tui_menu_queue=("Preview (dry-run)")
			PRUNE_ARGS=()
			tui_run_paged() { PRUNE_ARGS=("$@"); return 0; }
			tui_prune_uninstalled_menu
			printf "args:%s\n" "${PRUNE_ARGS[*]}"
		}
		_test_prune_preview
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:prune_uninstalled_configs 1 0 0" ]]
}
