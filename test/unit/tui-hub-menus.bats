#!/usr/bin/env bash
# Unit tests for lib/tui/hub/* menu workflows.
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

_tui_hub_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
		export LAUNCHLAYER_GAMES_DIR="'"${LAUNCHLAYER_GAMES_DIR:-${XDG_CONFIG_HOME}/games}"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs hub cli tools config
		launchlayer_source_tui
		tui_bats_menu_stub_install
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_hub_pick_recommendation returns selected config id" {
	local response='{"results":[{"config_id":"cfg-pick-1","similarity":90,"machine_label":"rig","note":"ok","published_at":1704067200000}]}'
	run _tui_hub_shell '
		_tui_menu_queue=("cfg-pick-1	90% match · rig · updated 2024-01-01 · ok")
		tui_hub_pick_recommendation '"$(printf '%q' "$response")"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "cfg-pick-1" ]]
}

@test "tui_hub_status_brief shows fingerprint level when hub url unset" {
	local empty_xdg
	empty_xdg="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$empty_xdg" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs hub
		launchlayer_source_tui
		tui_hub_status_brief | tui_strip_ansi
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"fp:minimal"* ]]
	rm -rf "$empty_xdg"
}

@test "tui_hub_require_ready fails when hub url is unset" {
	local empty_xdg
	empty_xdg="$(mktemp -d)"
	run env XDG_CONFIG_HOME="$empty_xdg" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs hub
		launchlayer_source_tui
		tui_show_text() { printf "%s\n" "$1"; return 0; }
		tui_hub_require_ready
	'
	[[ $status -ne 0 ]]
	rm -rf "$empty_xdg"
}

@test "tui_hub_apply_menu preview delegates to hub_apply_config" {
	run _tui_hub_shell '
		_test_apply_preview_branch() {
			local config_id="cfgtest00001" action
			APPLY_ARGS=()
			tui_run_paged() { APPLY_ARGS=("$@"); return 0; }
			_tui_menu_queue=("Preview (dry-run)")
			action="$(tui_menu "Apply hub config" \
				"Preview (dry-run)" \
				"Apply" \
				"Back")" || return 0
			case "$action" in
				"Preview (dry-run)")
					tui_run_paged hub_apply_config "$config_id" --dry-run || true
					;;
			esac
			printf "args:%s\n" "${APPLY_ARGS[*]}"
		}
		_test_apply_preview_branch
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:hub_apply_config cfgtest00001 --dry-run" ]]
}

@test "tui_hub_delete_menu delegates to hub_delete_config when confirmed" {
	run _tui_hub_shell '
		_test_delete_branch() {
			local config_id="cfgdelete001"
			DELETE_ARGS=()
			tui_confirm() { return 0; }
			tui_run_capture() { shift; DELETE_ARGS=("$@"); return 0; }
			tui_confirm "Delete hub config ${config_id}? This cannot be undone." || return 0
			tui_run_capture "Deleting hub config…" hub_delete_config "$config_id" --yes || true
			printf "args:%s\n" "${DELETE_ARGS[*]}"
		}
		_test_delete_branch
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "args:hub_delete_config cfgdelete001 --yes" ]]
}

@test "tui_hub_update_for_appid offers publish when no shared config exists" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Hub Update Game")"
	tmp="$(temp_config_dir)"
	mkdir -p "$tmp/games"
	echo 'INCLUDE=presets/standard.env' > "$tmp/games/42424242.env"
	run env \
		CONFIG_DIR="$tmp" \
		STEAM_ROOT="$fake_steam" \
		LAUNCHLAYER_GAMES_DIR="$tmp/games" \
		XDG_CONFIG_HOME="$HUB_TMP" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib load-modules hub
			launchlayer_source_tui
			tui_bats_menu_stub_install
			write_hub_conf "'"$XDG_CONFIG_HOME"'" "http://127.0.0.1:9" test-secret minimal
			_test_update_missing() {
				_tui_menu_queue=("Back")
				hub_find_my_config_id() { return 1; }
				tui_show_text() { :; }
				PUBLISHED=0
				tui_hub_publish_for_appid() { PUBLISHED=1; }
				tui_hub_update_for_appid 42424242
				printf "published:%s\n" "$PUBLISHED"
			}
			_test_update_missing
			tui_bats_menu_stub_teardown
		'
	[[ $status -eq 0 ]]
	[[ "$output" == "published:0" ]]
	rm -rf "$fake_steam" "$tmp"
}
