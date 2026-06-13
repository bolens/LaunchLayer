#!/usr/bin/env bash
# Unit tests for lib/tui/menus-status.sh delegate flows.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_tui_status_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules inspect setup config
		launchlayer_source_tui
		tui_bats_menu_stub_install
		tui_crumb_enter() { :; }
		tui_crumb_leave() { :; }
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_status_menu run doctor delegates to show_doctor" {
	run _tui_status_shell '
		_test_doctor() {
			_tui_menu_queue=("Run doctor" "Back")
			DOCTOR_ARGS=()
			tui_run_paged() { DOCTOR_ARGS=("$@"); return 0; }
			tui_status_menu
			printf "args:%s\n" "${DOCTOR_ARGS[*]}"
		}
		_test_doctor
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:show_doctor"* ]]
}

@test "tui_status_menu detect environment delegates to show_detect_environment" {
	run _tui_status_shell '
		_test_detect() {
			_tui_menu_queue=("Detect environment" "Back")
			DETECT_ARGS=()
			tui_run_paged() { DETECT_ARGS=("$@"); return 0; }
			tui_status_menu
			printf "args:%s\n" "${DETECT_ARGS[*]}"
		}
		_test_detect
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:show_detect_environment"* ]]
}
