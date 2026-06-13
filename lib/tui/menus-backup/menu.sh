# shellcheck shell=bash
# lib/tui/menus-backup/menu.sh — Backup hub entry menu.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_MENU_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_MENU_LOADED=1
# tui_backup_menu — Backup hub (settings, actions, transfer, prune).
tui_backup_menu() {
	local action prune_label
	tui_crumb_enter "Backup & restore"
	tui_remember_main_menu "Backup & restore"
	load_backup_prefs
	prune_label="$(backup_prune_summary) │ backup: $(tui_backup_timer_brief) │ maint: $(tui_maintenance_timer_brief)"
	while true; do
		TUI_MENU_CONTEXT=backup
		action="$(tui_menu "(${prune_label})" \
			"Settings" \
			"Backup actions" \
			"Restore from backup" \
			"Export & import" \
			"Prune archives" \
			"Back")" || return 0

		case "$action" in
			Settings)
				tui_backup_settings_menu
				load_backup_prefs
				prune_label="$(backup_prune_summary) │ backup: $(tui_backup_timer_brief) │ maint: $(tui_maintenance_timer_brief)"
				;;
			"Backup actions")
				tui_backup_actions_menu
				;;
			"Restore from backup")
				tui_backup_restore_menu
				;;
			"Export & import")
				tui_backup_transfer_menu
				;;
			"Prune archives")
				tui_backup_prune_menu
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}
