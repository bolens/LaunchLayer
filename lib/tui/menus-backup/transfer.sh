# shellcheck shell=bash
# lib/tui/menus-backup/transfer.sh — Export/import bundle menus.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_TRANSFER_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_TRANSFER_LOADED=1
# tui_pick_export_includes — Prompt for export bundle includes (parity with --export-config).
tui_pick_export_includes() {
	local action
	local -n _local=$1 _profiles=$2 _tui=$3
	action="$(tui_menu "Export: local.env" \
		"Include local.env" \
		"Exclude local.env" \
		"Back")" || return 1
	case "$action" in
		"Include local.env") _local=1 ;;
		"Exclude local.env") _local=0 ;;
		*) return 1 ;;
	esac
	action="$(tui_menu "Export: profiles" \
		"Include profiles" \
		"Exclude profiles" \
		"Back")" || return 1
	case "$action" in
		"Include profiles") _profiles=1 ;;
		"Exclude profiles") _profiles=0 ;;
		*) return 1 ;;
	esac
	action="$(tui_menu "Export: tui.conf" \
		"Include tui.conf" \
		"Exclude tui.conf" \
		"Back")" || return 1
	case "$action" in
		"Include tui.conf") _tui=1 ;;
		"Exclude tui.conf") _tui=0 ;;
		*) return 1 ;;
	esac
	return 0
}

# tui_pick_import_includes — Prompt for import bundle includes (parity with --import-config).
tui_pick_import_includes() {
	local action
	local -n _local=$1 _profiles=$2 _tui=$3
	action="$(tui_menu "Import: local.env" \
		"Include local.env" \
		"Exclude local.env" \
		"Back")" || return 1
	case "$action" in
		"Include local.env") _local=1 ;;
		"Exclude local.env") _local=0 ;;
		*) return 1 ;;
	esac
	action="$(tui_menu "Import: profiles" \
		"Include profiles" \
		"Exclude profiles" \
		"Back")" || return 1
	case "$action" in
		"Include profiles") _profiles=1 ;;
		"Exclude profiles") _profiles=0 ;;
		*) return 1 ;;
	esac
	action="$(tui_menu "Import: tui.conf" \
		"Include tui.conf" \
		"Exclude tui.conf" \
		"Back")" || return 1
	case "$action" in
		"Include tui.conf") _tui=1 ;;
		"Exclude tui.conf") _tui=0 ;;
		*) return 1 ;;
	esac
	return 0
}
# tui_backup_transfer_menu — Export and import config bundles.
tui_backup_transfer_menu() {
	local action path include_local include_profiles include_tui
	action="$(tui_menu "Export & import" \
		"Export to archive" \
		"Import preview (dry-run)" \
		"Import apply (merge, skip existing)" \
		"Import apply (replace existing)" \
		"Back")" || return 0

	case "$action" in
		"Export to archive")
			read -r -p "Output path [./launchlayer-export.tar.gz]: " path </dev/tty || return 0
			[[ -z "$path" ]] && path="./launchlayer-export.tar.gz"
			include_local=0 include_profiles=1 include_tui=0
			tui_pick_export_includes include_local include_profiles include_tui || return 0
			tui_run_paged export_config "$path" "$include_local" "$include_profiles" "$include_tui" 0 || true
			;;
		"Import preview (dry-run)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			tui_run_paged import_config "$path" 1 merge 0 "$include_local" "$include_profiles" "$include_tui" 0 || true
			;;
		"Import apply (merge, skip existing)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			tui_run_paged import_config "$path" 1 merge 0 "$include_local" "$include_profiles" "$include_tui" 0 || true
			tui_confirm "Import new files only (skip existing)?" || return 0
			tui_run_paged import_config "$path" 0 merge 1 "$include_local" "$include_profiles" "$include_tui" 0 || true
			;;
		"Import apply (replace existing)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			tui_run_paged import_config "$path" 1 replace 0 "$include_local" "$include_profiles" "$include_tui" 0 || true
			tui_confirm "Overwrite existing config files from archive?" || return 0
			tui_run_paged import_config "$path" 0 replace 1 "$include_local" "$include_profiles" "$include_tui" 0 || true
			;;
		*) return 0 ;;
	esac
	tui_maybe_press_enter
}
