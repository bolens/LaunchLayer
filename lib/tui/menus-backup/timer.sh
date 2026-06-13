# shellcheck shell=bash
# lib/tui/menus-backup/timer.sh — Backup systemd timer/service toggles.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_TIMER_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_TIMER_LOADED=1

# tui_backup_units_installed_glyph — ● when unit files exist, ○ otherwise.
tui_backup_units_installed_glyph() {
	if systemd_backup_units_installed_p; then
		tui_glyph_ok
	else
		tui_glyph_off
	fi
}

# tui_backup_timer_enabled_glyph — Timer scheduling state (requires units for ●/◑).
tui_backup_timer_enabled_glyph() {
	if ! systemd_backup_units_installed_p; then
		tui_glyph_off
	elif systemd_backup_timer_enabled_p; then
		tui_glyph_ok
	else
		tui_glyph_mid
	fi
}

# tui_backup_service_enabled_glyph — Oneshot service enabled for manual systemctl start.
tui_backup_service_enabled_glyph() {
	if ! systemd_backup_units_installed_p; then
		tui_glyph_off
	elif systemd_backup_service_enabled_p; then
		tui_glyph_ok
	else
		tui_glyph_off
	fi
}

# tui_backup_timer_menu_header — Submenu title with schedule summary.
tui_backup_timer_menu_header() {
	local schedule
	load_backup_prefs
	schedule="$(backup_prefs_schedule_summary)"
	printf '%s' "Backup timer  (${schedule})"
}

# tui_backup_timer_toggle_units — Install or uninstall service + timer unit files.
tui_backup_timer_toggle_units() {
	if systemd_backup_units_installed_p; then
		tui_confirm "Uninstall launchlayer-backup.service and .timer?" || return 0
		tui_run_paged uninstall_systemd_backup_units || true
	else
		tui_run_paged install_systemd_backup_units 1 || true
	fi
}

# tui_backup_timer_toggle_scheduling — Enable or disable scheduled backups.
tui_backup_timer_toggle_scheduling() {
	if ! systemd_backup_units_installed_p; then
		tui_run_paged install_systemd_backup_units 1 || true
		return 0
	fi
	if systemd_backup_timer_enabled_p; then
		tui_run_paged disable_systemd_backup_timer || true
	else
		tui_run_paged enable_systemd_backup_timer || true
	fi
}

# tui_backup_timer_toggle_service — Enable or disable manual systemctl start of the oneshot.
tui_backup_timer_toggle_service() {
	if ! systemd_backup_units_installed_p; then
		tui_show_text "Install units first." "Backup timer"
		return 0
	fi
	if systemd_backup_service_enabled_p; then
		tui_run_paged disable_systemd_backup_service || true
	else
		tui_run_paged enable_systemd_backup_service || true
	fi
}

# tui_backup_settings_reinstall_units_preserve — Refresh unit files; keep timer/service enable state.
tui_backup_settings_reinstall_units_preserve() {
	if ! systemd_backup_units_installed_p; then
		return 0
	fi
	local was_enabled=0 was_service=0
	systemd_backup_timer_enabled_p && was_enabled=1
	systemd_backup_service_enabled_p && was_service=1
	install_systemd_backup_units 0 || return 1
	(( was_enabled )) && enable_systemd_backup_timer || true
	(( was_service )) && enable_systemd_backup_service || true
}

# tui_backup_systemd_menu — Systemd unit toggles, status, and reinstall.
tui_backup_systemd_menu() {
	local action last_anchor=""
	while true; do
		load_backup_prefs
		action="$(tui_menu_anchored "Backup timer ($(backup_prefs_schedule_summary))" "$last_anchor" \
			"Units installed: $(tui_backup_units_installed_glyph)" \
			"Scheduling enabled: $(tui_backup_timer_enabled_glyph)" \
			"Manual start enabled: $(tui_backup_service_enabled_glyph)" \
			"Show full status" \
			"Reinstall units (refresh script path)" \
			"Back")" || return 0

		case "$action" in
			"Units installed:"*)
				last_anchor="Units installed:"
				tui_backup_timer_toggle_units
				;;
			"Scheduling enabled:"*)
				last_anchor="Scheduling enabled:"
				tui_backup_timer_toggle_scheduling
				;;
			"Manual start enabled:"*)
				last_anchor="Manual start enabled:"
				tui_backup_timer_toggle_service
				;;
			"Show full status")
				tui_run_paged systemd_backup_status || true
				tui_maybe_press_enter
				;;
			"Reinstall units (refresh script path)")
				if systemd_backup_units_installed_p; then
					tui_run_paged tui_backup_settings_reinstall_units_preserve || true
				else
					tui_show_text "Units not installed — enable units first." "Backup timer"
				fi
				;;
			*) return 0 ;;
		esac
	done
}

# tui_backup_timer_menu — Legacy entry; opens backup settings.
tui_backup_timer_menu() {
	tui_backup_settings_menu
}

# tui_backup_timer_menu_standalone — Alias for tests / direct dispatch.
tui_backup_timer_menu_standalone() {
	tui_backup_systemd_menu
}
