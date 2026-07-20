#!/usr/bin/env bash
# Unit tests for backup restore, transfer, and prune menu flows.
load '../helpers.bash'

setup() {
	bats_unit_setup
	BACKUP_TMP="$(temp_config_dir)"
	export CONFIG_DIR="$BACKUP_TMP"
	export XDG_CONFIG_HOME="$(mktemp -d)"
}

teardown() {
	[[ -n "${XDG_CONFIG_HOME:-}" ]] && rm -rf "$XDG_CONFIG_HOME"
	[[ -n "${BACKUP_TMP:-}" ]] && rm -rf "$BACKUP_TMP"
}

_tui_backup_flow_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs inspect setup
		launchlayer_source_tui
		tui_bats_menu_stub_install
		tui_maybe_press_enter() { :; }
		'"$1"'
		tui_bats_menu_stub_teardown
	'
}

@test "tui_restore_backup_flow previews without apply when not confirmed" {
	local archive_dir archive
	archive_dir="$(mktemp -d)"
	archive="$archive_dir/launchlayer-backup-2024-06-01.tar.gz"
	touch "$archive"
	run _tui_backup_flow_shell '
		_test_restore_preview() {
			local -a calls=()
			tui_confirm() { return 1; }
			tui_run_paged() { calls+=("$*"); return 0; }
			tui_restore_backup_flow "'"$archive"'" merge
			printf "calls:%s\n" "${#calls[@]}"
			printf "first:%s\n" "${calls[0]}"
		}
		_test_restore_preview
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"calls:1"* ]]
	[[ "$output" == *"restore_backup"* ]]
	[[ "$output" == *" 1 "* ]]  # dry-run flag
	rm -rf "$archive_dir"
}

@test "tui_restore_backup_flow applies when confirmed" {
	local archive_dir archive
	archive_dir="$(mktemp -d)"
	archive="$archive_dir/launchlayer-backup-2024-06-01.tar.gz"
	touch "$archive"
	run _tui_backup_flow_shell '
		_test_restore_apply() {
			local -a calls=()
			tui_confirm() { return 0; }
			tui_run_paged() { calls+=("$*"); return 0; }
			tui_restore_backup_flow "'"$archive"'" replace
			printf "calls:%s\n" "${#calls[@]}"
		}
		_test_restore_apply
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"calls:2"* ]]
	rm -rf "$archive_dir"
}

@test "tui_backup_prune_menu preview runs dry-run prune" {
	run _tui_backup_flow_shell '
		_test_prune_preview() {
			_tui_menu_queue=("Preview (dry-run)" "Back")
			PRUNE_ARGS=()
			tui_run_paged() { PRUNE_ARGS=("$@"); return 0; }
			tui_backup_prune_menu
			printf "args:%s\n" "${PRUNE_ARGS[*]}"
		}
		_test_prune_preview
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"prune_backup_archives"* ]]
	[[ "$output" == *" 1 "* ]]  # dry-run
}

@test "tui_backup_actions_menu backup now invokes backup_config" {
	run _tui_backup_flow_shell '
		_test_backup_now() {
			_tui_menu_queue=("Backup now (saved settings)")
			BACKUP_ARGS=()
			tui_run_paged() { BACKUP_ARGS=("$@"); return 0; }
			tui_backup_actions_menu
			printf "args:%s\n" "${BACKUP_ARGS[*]}"
		}
		_test_backup_now
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"args:backup_config"* ]]
}

@test "tui_backup_transfer_menu export path uses picked includes" {
	run _tui_backup_flow_shell '
		_test_export_includes_only() {
			local include_local=0 include_profiles=1 include_tui=0
			_tui_menu_queue=(
				"Include local.env"
				"Include profiles"
				"Exclude tui.conf"
			)
			tui_pick_export_includes include_local include_profiles include_tui
			printf "local:%s profiles:%s tui:%s\n" "$include_local" "$include_profiles" "$include_tui"
		}
		_test_export_includes_only
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "local:1 profiles:1 tui:0" ]]
}

@test "tui_backup_restore_menu merge latest uses merge mode" {
	run _tui_backup_flow_shell '
		_test_restore_merge() {
			_tui_menu_queue=("Restore latest (merge, skip existing)")
			RESTORE_ARGS=()
			tui_confirm() { return 1; }
			tui_run_paged() { RESTORE_ARGS+=("$*"); return 0; }
			tui_backup_restore_menu
			printf "first:%s\n" "${RESTORE_ARGS[0]}"
		}
		_test_restore_merge
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"restore_backup"* ]]
	[[ "$output" == *" merge "* ]]
}

@test "tui_backup_restore_latest merge confirms with skip-existing prompt" {
	run _tui_backup_flow_shell '
		_test_restore_latest_merge() {
			CONFIRM_MSG=""
			tui_confirm() { CONFIRM_MSG=$1; return 1; }
			tui_run_paged() { return 0; }
			BACKUP_PREFS_INCLUDE_LOCAL=1
			BACKUP_PREFS_INCLUDE_PROFILES=1
			BACKUP_PREFS_INCLUDE_TUI=0
			tui_backup_restore_latest /tmp/backups merge
			printf "confirm:%s\n" "$CONFIRM_MSG"
		}
		_test_restore_latest_merge
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"merge"* ]]
}
