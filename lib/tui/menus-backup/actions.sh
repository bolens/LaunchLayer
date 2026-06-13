# shellcheck shell=bash
# lib/tui/menus-backup/actions.sh — Backup actions, prune, and timer menus.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_ACTIONS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_ACTIONS_LOADED=1
# tui_backup_actions_menu — Run backups using saved preferences.
tui_backup_actions_menu() {
	local action path
	load_backup_prefs
	action="$(tui_menu "Backup actions" \
		"Backup now (saved settings)" \
		"Backup to custom path" \
		"Run scheduled backup + prune" \
		"Back")" || return 0

	case "$action" in
		"Backup now (saved settings)")
			backup_prefs_apply_env
			tui_run_paged backup_config "$(default_backup_dir)" \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0 || true
			;;
		"Backup to custom path")
			read -r -p "Output directory or file [$(default_backup_dir)]: " path </dev/tty || return 0
			[[ -z "$path" ]] && path="$(default_backup_dir)"
			backup_prefs_apply_env
			tui_run_paged backup_config "$path" \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0 || true
			;;
		"Run scheduled backup + prune")
			tui_run_paged run_scheduled_backup "" "" 0 || true
			;;
		*) return 0 ;;
	esac
	tui_maybe_press_enter
}
# tui_backup_prune_menu — Manual archive pruning.
tui_backup_prune_menu() {
	local action dir keep
	load_backup_prefs
	dir="${BACKUP_PREFS_DIR}"
	keep="${BACKUP_PREFS_KEEP}"
	action="$(tui_menu "Prune archives  (keep=${keep}, dir=${dir})" \
		"Preview (dry-run)" \
		"Apply prune" \
		"Back")" || return 0

	case "$action" in
		"Preview (dry-run)")
			tui_run_paged prune_backup_archives "$dir" "$keep" 1 0 || true
			;;
		"Apply prune")
			tui_run_paged prune_backup_archives "$dir" "$keep" 1 0 || true
			tui_confirm "Delete archives beyond the newest $keep in $dir?" || return 0
			tui_run_paged prune_backup_archives "$dir" "$keep" 0 0 || true
			;;
		*) return 0 ;;
	esac
	tui_maybe_press_enter
}

# tui_backup_timer_menu — Implemented in menus-backup/timer.sh (toggle menu with status glyphs).
