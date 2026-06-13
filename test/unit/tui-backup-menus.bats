#!/usr/bin/env bash
# Unit tests for lib/tui/menus-backup/* orchestration helpers.
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

_tui_backup_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
		export NO_COLOR=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib load-modules prefs inspect setup
		launchlayer_source_tui
		_tui_menu_idx_file="$(mktemp)"
		echo 0 > "$_tui_menu_idx_file"
		tui_menu() {
			local idx choice
			idx="$(<"$_tui_menu_idx_file")"
			choice="${_tui_menu_queue[$idx]}"
			echo $((idx + 1)) > "$_tui_menu_idx_file"
			printf "%s\n" "$choice"
		}
		tui_menu_anchored() {
			shift 2
			tui_menu "$@"
		}
		'"$1"'
		rm -f "${_tui_menu_idx_file:-}"
	'
}

@test "tui_pick_export_includes sets nameref flags from menu choices" {
	run _tui_backup_shell '
		_test_pick_export() {
			_tui_menu_queue=(
				"Include local.env"
				"Exclude profiles"
				"Include tui.conf"
			)
			local include_local=0 include_profiles=1 include_tui=0
			tui_pick_export_includes include_local include_profiles include_tui
			printf "local:%s profiles:%s tui:%s\n" "$include_local" "$include_profiles" "$include_tui"
		}
		_test_pick_export
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "local:1 profiles:0 tui:1" ]]
}

@test "tui_pick_import_includes returns failure when user backs out" {
	run _tui_backup_shell '
		_test_import_cancel() {
			tui_menu() { return 1; }
			local include_local=0 include_profiles=0 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || exit 1
		}
		_test_import_cancel
	'
	[[ $status -ne 0 ]]
}

@test "tui_pick_import_includes sets nameref flags from menu choices" {
	run _tui_backup_shell '
		_test_pick_import() {
			_tui_menu_queue=(
				"Include local.env"
				"Exclude profiles"
				"Include tui.conf"
			)
			local include_local=0 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui
			printf "local:%s profiles:%s tui:%s\n" "$include_local" "$include_profiles" "$include_tui"
		}
		_test_pick_import
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "local:1 profiles:0 tui:1" ]]
}

@test "tui_backup_toggle_pref flips include and auto_prune prefs" {
	run _tui_backup_shell '
		load_backup_prefs
		BACKUP_PREFS_INCLUDE_LOCAL=1
		BACKUP_PREFS_AUTO_PRUNE=1
		tui_backup_toggle_pref include_local
		tui_backup_toggle_pref auto_prune
		printf "local:%s prune:%s\n" "${BACKUP_PREFS_INCLUDE_LOCAL}" "${BACKUP_PREFS_AUTO_PRUNE}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "local:0 prune:0" ]]
}

@test "tui_backup_timer glyphs reflect mocked systemd state" {
	run _tui_backup_shell '
		systemd_backup_units_installed_p() { return 0; }
		systemd_backup_timer_enabled_p() { return 0; }
		systemd_backup_service_enabled_p() { return 1; }
		printf "units:%s timer:%s service:%s\n" \
			"$(tui_backup_units_installed_glyph | tui_strip_ansi)" \
			"$(tui_backup_timer_enabled_glyph | tui_strip_ansi)" \
			"$(tui_backup_service_enabled_glyph | tui_strip_ansi)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"units:"* ]]
	[[ "$output" == *"timer:"* ]]
	[[ "$output" == *"service:"* ]]
}

@test "tui_backup_settings_items builds compact grouped rows" {
	run _tui_backup_shell '
		local -a items=()
		load_backup_prefs
		BACKUP_PREFS_DIR="~/backups"
		tui_backup_settings_items items "~/backups"
		printf "%s\n" "${items[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"[Path]"* ]]
	[[ "$output" == *"[Keep]"* ]]
	[[ "$output" == *"[When]"* ]]
	[[ "$output" == *"[Pack]"* ]]
	[[ "$output" == *"[Timer]"* ]]
}

@test "tui_pick_backup_archive returns selected archive path" {
	local archive_dir
	archive_dir="$(mktemp -d)"
	touch "$archive_dir/launchlayer-backup-2024-01-01.tar.gz"
	touch "$archive_dir/launchlayer-backup-2024-06-01.tar.gz"
	run _tui_backup_shell '
		tui_menu() {
			local _title=$1; shift
			printf "%s\n" "launchlayer-backup-2024-06-01.tar.gz"
		}
		tui_pick_backup_archive "'"$archive_dir"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$archive_dir/launchlayer-backup-2024-06-01.tar.gz" ]]
	rm -rf "$archive_dir"
}

@test "tui_backup_schedule_menu applies daily preset" {
	run _tui_backup_shell '
		tui_menu() { printf "%s\n" "Daily at 03:15"; }
		tui_backup_schedule_menu
		load_backup_prefs
		printf "type:%s calendar:%s\n" "${BACKUP_PREFS_TIMER_TYPE}" "${BACKUP_PREFS_ON_CALENDAR}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"type:calendar"* ]]
	[[ "$output" == *"03:15"* ]]
}
