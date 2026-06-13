#!/usr/bin/env bash
# Unit tests for lib/tui/hub/browse.sh menu delegate flows.
load '../helpers.bash'

setup() {
	bats_unit_setup
	HUB_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$HUB_TMP"
	export CONFIG_DIR="$(launchlayer_root)"
	start_hub_mock_server test-secret 0
	write_hub_conf "$XDG_CONFIG_HOME" "$HUB_MOCK_URL" test-secret minimal
}

teardown() {
	[[ -n "${HUB_TMP:-}" ]] && rm -rf "$HUB_TMP"
	stop_hub_mock_server
}

_tui_hub_browse_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs hub cli tools config
		launchlayer_source_tui
		tui_bats_menu_stub_install
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_hub_search_machines top 5 delegates hub_search_machines --limit 5" {
	run _tui_hub_browse_shell '
		_test_search() {
			_tui_menu_queue=("Top 5")
			SEARCH_ARGS=()
			tui_run_paged() { SEARCH_ARGS=("$@"); return 0; }
			tui_json_flag() { :; }
			tui_hub_search_machines
			printf "args:%s\n" "${SEARCH_ARGS[*]}"
		}
		_test_search
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:hub_search_machines --limit 5"* ]]
}

@test "tui_hub_recommend_for_appid json mode pages hub response without picker" {
	run _tui_hub_browse_shell '
		_test_recommend_json() {
			TUI_JSON_OUTPUT=1
			PAGED=""
			tui_spinner_capture() {
				printf "%s" "{\"results\":[{\"config_id\":\"cfgjson0001\",\"similarity\":90}]}"
				return 0
			}
			tui_run_paged() { PAGED="$*"; return 0; }
			tui_hub_recommend_for_appid 42424242 10
			printf "paged:%s\n" "$PAGED"
		}
		_test_recommend_json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cfgjson0001"* ]]
	[[ "$output" == *"paged:printf"* ]]
}

@test "tui_hub_recommend_menu limit 20 calls recommend helper with appid and limit" {
	run _tui_hub_browse_shell '
		_test_recommend_menu() {
			_tui_menu_queue=("Top 20")
			REC_ARGS=()
			tui_pick_game_appid() { echo 42424242; return 0; }
			tui_hub_recommend_for_appid() { REC_ARGS=("$@"); return 0; }
			tui_hub_recommend_menu
			printf "args:%s\n" "${REC_ARGS[*]}"
		}
		_test_recommend_menu
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:42424242 20" ]]
}
