# shellcheck shell=bash
# lib/tui/menus-backup/settings.sh — Backup schedule, preferences, and systemd toggles.

[[ -n "${LAUNCHLAYER_TUI_MENUS_BACKUP_SETTINGS_LOADED:-}" ]] && return 0
LAUNCHLAYER_TUI_MENUS_BACKUP_SETTINGS_LOADED=1

# tui_backup_schedule_menu — Pick a backup timer schedule preset.
tui_backup_schedule_menu() {
	local action val weekday
	action="$(tui_menu "Backup schedule" \
		"Daily at 03:15" \
		"Daily at custom time" \
		"Every 12 hours" \
		"Every 6 hours" \
		"Weekly (Sunday 03:15)" \
		"Weekly custom day + time" \
		"Custom OnCalendar (advanced)" \
		"Back")" || return 0

	case "$action" in
		"Daily at 03:15")
			backup_prefs_set_schedule_daily "03:15"
			;;
		"Daily at custom time")
			read -r -p "Time (HH:MM) [03:15]: " val </dev/tty || return 0
			[[ -z "$val" ]] && val="03:15"
			backup_prefs_set_schedule_daily "$val" || {
				tui_show_text "Invalid time — use HH:MM" "Backup schedule"
				return 1
			}
			;;
		"Every 12 hours")
			backup_prefs_set_schedule_interval "12h" "15min"
			;;
		"Every 6 hours")
			backup_prefs_set_schedule_interval "6h" "15min"
			;;
		"Weekly (Sunday 03:15)")
			backup_prefs_set_schedule_weekly "Sun" "03:15"
			;;
		"Weekly custom day + time")
			read -r -p "Weekday (Mon..Sun) [Sun]: " weekday </dev/tty || return 0
			[[ -z "$weekday" ]] && weekday="Sun"
			read -r -p "Time (HH:MM) [03:15]: " val </dev/tty || return 0
			[[ -z "$val" ]] && val="03:15"
			backup_prefs_set_schedule_weekly "$weekday" "$val" || {
				tui_show_text "Invalid time — use HH:MM" "Backup schedule"
				return 1
			}
			;;
		"Custom OnCalendar (advanced)")
			tui_panel_note "systemd OnCalendar examples: *-*-* 04:30:00  |  Mon..Fri *-*-* 02:00:00" "Backup schedule"
			read -r -p "OnCalendar expression: " val </dev/tty || return 0
			[[ -n "$val" ]] || return 0
			backup_prefs_set_schedule_custom "$val" || {
				tui_show_text "Invalid OnCalendar expression" "Backup schedule"
				return 1
			}
			;;
		*) return 0 ;;
	esac
}

# tui_backup_toggle_pref — Flip a 0/1 backup preference by name.
tui_backup_toggle_pref() {
	local key=$1
	case "$key" in
		include_local)
			[[ "${BACKUP_PREFS_INCLUDE_LOCAL:-1}" == "1" ]] && BACKUP_PREFS_INCLUDE_LOCAL=0 || BACKUP_PREFS_INCLUDE_LOCAL=1
			;;
		include_profiles)
			[[ "${BACKUP_PREFS_INCLUDE_PROFILES:-1}" == "1" ]] && BACKUP_PREFS_INCLUDE_PROFILES=0 || BACKUP_PREFS_INCLUDE_PROFILES=1
			;;
		include_tui)
			[[ "${BACKUP_PREFS_INCLUDE_TUI:-0}" == "1" ]] && BACKUP_PREFS_INCLUDE_TUI=0 || BACKUP_PREFS_INCLUDE_TUI=1
			;;
		auto_prune)
			[[ "${BACKUP_PREFS_AUTO_PRUNE:-1}" == "1" ]] && BACKUP_PREFS_AUTO_PRUNE=0 || BACKUP_PREFS_AUTO_PRUNE=1
			;;
	esac
}

# tui_backup_keep_menu — Retention count and auto-prune toggle.
tui_backup_keep_menu() {
	local action val last_anchor=""
	load_backup_prefs
	while true; do
		action="$(tui_menu_anchored "Retention" "$last_anchor" \
			"Keep archives: ${BACKUP_PREFS_KEEP} (0=unlimited)" \
			"Auto-prune after backup: $(tui_glyph_pref "${BACKUP_PREFS_AUTO_PRUNE}")" \
			"Back")" || return 0
		case "$action" in
			"Keep archives:"*)
				read -r -p "Keep newest N archives (0=unlimited) [${BACKUP_PREFS_KEEP}]: " val </dev/tty || continue
				[[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && BACKUP_PREFS_KEEP=$val
				;;
			"Auto-prune after backup:"*)
				last_anchor="Auto-prune after backup:"
				tui_backup_toggle_pref auto_prune
				;;
			*) return 0 ;;
		esac
	done
}

# tui_backup_when_menu — Schedule preset and randomized delay.
tui_backup_when_menu() {
	local action val schedule_label
	load_backup_prefs
	schedule_label="$(backup_prefs_schedule_summary)"
	while true; do
		action="$(tui_menu "Schedule (${schedule_label})" \
			"Change schedule preset…" \
			"Randomized delay: ${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}s" \
			"Back")" || return 0
		case "$action" in
			"Change schedule preset…")
				tui_backup_schedule_menu || continue
				schedule_label="$(backup_prefs_schedule_summary)"
				;;
			"Randomized delay:"*)
				read -r -p "Randomized delay seconds [${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}]: " val </dev/tty || continue
				[[ -n "$val" ]] && BACKUP_PREFS_RANDOMIZED_DELAY_SEC="$val"
				;;
			*) return 0 ;;
		esac
	done
}

# tui_backup_pack_menu — Include toggles for backup archive contents.
tui_backup_pack_menu() {
	local action last_anchor=""
	load_backup_prefs
	while true; do
		action="$(tui_menu_anchored "Backup includes" "$last_anchor" \
			"local.env: $(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_LOCAL}")" \
			"profiles: $(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_PROFILES}")" \
			"tui.conf: $(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_TUI}")" \
			"Back")" || return 0
		case "$action" in
			"local.env:"*)
				last_anchor="local.env:"
				tui_backup_toggle_pref include_local
				;;
			"profiles:"*)
				last_anchor="profiles:"
				tui_backup_toggle_pref include_profiles
				;;
			"tui.conf:"*)
				last_anchor="tui.conf:"
				tui_backup_toggle_pref include_tui
				;;
			*) return 0 ;;
		esac
	done
}

# tui_backup_keep_label — Compact retention row label.
tui_backup_keep_label() {
	load_backup_prefs
	printf 'keep %s · prune %s' "${BACKUP_PREFS_KEEP}" "$(tui_glyph_pref "${BACKUP_PREFS_AUTO_PRUNE}")"
}

# tui_backup_when_label — Compact schedule row label.
tui_backup_when_label() {
	load_backup_prefs
	printf '%s · jitter %ss' "$(backup_prefs_schedule_summary)" "${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}"
}

# tui_backup_pack_label — Compact includes row label.
tui_backup_pack_label() {
	load_backup_prefs
	printf 'local %s · profiles %s · tui %s' \
		"$(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_LOCAL}")" \
		"$(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_PROFILES}")" \
		"$(tui_glyph_pref "${BACKUP_PREFS_INCLUDE_TUI}")"
}

# tui_backup_timer_label — Compact systemd row label.
tui_backup_timer_label() {
	printf 'units %s · timer %s · manual %s' \
		"$(tui_backup_units_installed_glyph)" \
		"$(tui_backup_timer_enabled_glyph)" \
		"$(tui_backup_service_enabled_glyph)"
}

# tui_backup_settings_items — Compact backup preference rows.
tui_backup_settings_items() {
	local arr_name=$1
	# shellcheck disable=SC2178 # nameref to caller's array
	local -n out_arr=$arr_name
	local dir_label=${2:-}
	load_backup_prefs
	dir_label="${dir_label:-$(tui_prefs_path_short "${BACKUP_PREFS_DIR}")}"
	out_arr=(
		"[Path] ${dir_label}"
		"[Keep] $(tui_backup_keep_label)"
		"[When] $(tui_backup_when_label)"
		"[Pack] $(tui_backup_pack_label)"
		"[Timer] $(tui_backup_timer_label)"
	)
	tui_prefs_footer "$arr_name" save
}

# tui_backup_settings_save — Persist backup.conf and refresh systemd units when installed.
tui_backup_settings_save() {
	save_backup_prefs
	if systemd_backup_units_installed_p; then
		tui_run_paged tui_backup_settings_reinstall_units_preserve || true
	fi
	tui_show_text "Saved backup settings to $(backup_prefs_path)" "Backup settings"
}

# tui_backup_settings_menu — Edit backup.conf and systemd backup units.
tui_backup_settings_menu() {
	local action val dir_label
	local -a items=()

	load_backup_prefs
	dir_label="$(tui_prefs_path_short "${BACKUP_PREFS_DIR}")"

	while true; do
		tui_backup_settings_items items "$dir_label"
		action="$(tui_menu_anchored "backup.conf" "" "${items[@]}")" || return 0

		case "$action" in
			"[Path]"*)
				read -r -p "Backup directory [${BACKUP_PREFS_DIR}]: " val </dev/tty || continue
				[[ -n "$val" ]] && BACKUP_PREFS_DIR="$(_backup_prefs_expand_path "$val")"
				dir_label="$(tui_prefs_path_short "${BACKUP_PREFS_DIR}")"
				;;
			"[Keep]"*)
				tui_backup_keep_menu
				;;
			"[When]"*)
				tui_backup_when_menu
				;;
			"[Pack]"*)
				tui_backup_pack_menu
				;;
			"[Timer]"*)
				tui_backup_systemd_menu
				;;
			"[·] Show all")
				tui_run_paged show_backup_prefs 0 || true
				;;
			"[·] Reset defaults")
				tui_confirm "Reset backup settings to repo defaults?" || continue
				reset_backup_prefs || continue
				load_backup_prefs
				dir_label="$(tui_prefs_path_short "${BACKUP_PREFS_DIR}")"
				;;
			"[·] Save")
				tui_backup_settings_save
				return 0
				;;
			*) return 0 ;;
		esac
	done
}
