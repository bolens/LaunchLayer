# shellcheck shell=bash
# lib/tui/menus-config.sh — Config library, backup, and anticheat menus.
# tui_anticheat_menu — Filesystem vs list anticheat scans and detection audit.
tui_anticheat_menu() {
	local action
	while true; do
		action="$(tui_menu "Anticheat & detections" \
			"Scan anticheat (filesystem vs list)" \
			"Scan anticheat + update list" \
			"Detection audit (native/dlss hints)" \
			"Back")" || return 0

		case "$action" in
			"Scan anticheat (filesystem vs list)")
				tui_run_paged scan_anticheat 0 || true
				;;
			"Scan anticheat + update list")
				tui_run_paged scan_anticheat 1 || true
				;;
			"Detection audit (native/dlss hints)")
				tui_run_paged scan_detections || true
				;;
			*) return 0 ;;
		esac
	done
}

# tui_config_menu — Global config layers and validation.
tui_config_menu() {
	local action profile preset path
	tui_crumb_enter "Config library"
	tui_remember_main_menu "Config library"

	while true; do
		action="$(tui_menu "Layers & validation" \
			"Edit launch.d/default.env" \
			"Edit launch.d/local.env" \
			"Show detected defaults" \
			"Write local.env from detection" \
			"Anticheat & detections" \
			"Edit machine profile" \
			"Edit gameplay preset" \
			"Validate default + presets" \
			"Validate all game configs" \
			"Back")" || return 0

		case "$action" in
			"Edit launch.d/default.env")
				tui_open_in_editor "$LAUNCHD_DIR/default.env"
				;;
			"Edit launch.d/local.env")
				tui_open_or_create_in_editor "$LOCAL_CONFIG_FILE"
				;;
			"Show detected defaults")
				tui_run_paged show_detected_defaults "$(tui_json_flag)" || true
				;;
			"Write local.env from detection")
				tui_write_local_config_menu
				;;
			"Anticheat & detections")
				tui_anticheat_menu
				;;
			"Edit machine profile")
				local -a profiles=()
				for path in "$PROFILES_DIR"/*.env; do
					[[ -f "$path" ]] || continue
					profiles+=("$(basename "$path" .env)")
				done
				((${#profiles[@]})) || {
					echo "No profiles in $PROFILES_DIR"
					tui_press_enter
					continue
				}
				profile="$(tui_menu "Choose profile" "${profiles[@]}")" || continue
				tui_open_in_editor "$PROFILES_DIR/${profile}.env"
				;;
			"Edit gameplay preset")
				local -a presets=()
				for path in "$LAUNCHD_DIR"/presets/*.env; do
					[[ -f "$path" ]] || continue
					presets+=("$(basename "$path" .env)")
				done
				((${#presets[@]})) || {
					echo "No presets in $LAUNCHD_DIR/presets"
					tui_press_enter
					continue
				}
				preset="$(tui_menu "Choose preset" "${presets[@]}")" || continue
				tui_open_in_editor "$LAUNCHD_DIR/presets/${preset}.env"
				;;
			"Validate default + presets")
				tui_run_paged validate_config default 0 || true
				tui_run_paged validate_config presets 0 || true
				;;
			"Validate all game configs")
				tui_run_paged validate_config all 0 || true
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}

# tui_write_local_config_menu — Preview and write launch.d/local.env from detection.
tui_write_local_config_menu() {
	local action
	action="$(tui_menu "Write local.env" \
		"Preview detected defaults" \
		"Write local.env" \
		"Overwrite local.env (--force)" \
		"Back")" || return 0

	case "$action" in
		"Preview detected defaults")
			tui_run_paged write_local_config 0 1 || true
			;;
		"Write local.env")
			if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
				echo "local.env already exists — use overwrite or edit in place."
			else
				write_local_config 0 0
			fi
			;;
		"Overwrite local.env (--force)")
			tui_confirm "Overwrite $LOCAL_CONFIG_FILE with detected defaults?" || return 0
			write_local_config 1 0
			;;
		*) return 0 ;;
	esac
}

# tui_init_unconfigured_menu — Bulk scaffold missing per-game configs.
tui_init_unconfigured_menu() {
	local action preset
	action="$(tui_menu "Init unconfigured games" \
		"Preview (dry-run, suggested presets)" \
		"Create all (suggested presets)" \
		"Create all with chosen preset" \
		"Create EAC/BattlEye only (suggested)" \
		"Back")" || return 0

	case "$action" in
		"Preview (dry-run, suggested presets)")
			tui_run_paged init_unconfigured "" 1 0 || true
			;;
		"Create all (suggested presets)")
			tui_confirm "Create .env for every unconfigured game?" || return 0
			tui_run_paged init_unconfigured "" 0 0 || true
			;;
		"Create all with chosen preset")
			preset="$(tui_pick_preset)" || return 0
			tui_confirm "Create .env for every unconfigured game with preset $preset?" || return 0
			tui_run_paged init_unconfigured "$preset" 0 0 || true
			;;
		"Create EAC/BattlEye only (suggested)")
			tui_confirm "Scaffold anticheat titles only?" || return 0
			tui_run_paged init_unconfigured "" 0 1 || true
			;;
		*) return 0 ;;
	esac
}

# tui_prune_uninstalled_menu — Remove per-game configs for games no longer installed.
tui_prune_uninstalled_menu() {
	local action
	action="$(tui_menu "Prune uninstalled configs" \
		"Preview (dry-run)" \
		"Delete all orphan configs" \
		"Back")" || return 0

	case "$action" in
		"Preview (dry-run)")
			tui_run_paged prune_uninstalled_configs 1 0 0 || true
			;;
		"Delete all orphan configs")
			tui_run_paged prune_uninstalled_configs 1 0 0 || true
			tui_confirm "Delete every orphan per-game .env listed above?" || return 0
			tui_run_paged prune_uninstalled_configs 0 1 0 || true
			;;
		*) return 0 ;;
	esac
}

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
				echo "Invalid time — use HH:MM" >&2
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
				echo "Invalid time — use HH:MM" >&2
				return 1
			}
			;;
		"Custom OnCalendar (advanced)")
			echo "systemd OnCalendar examples: *-*-* 04:30:00  |  Mon..Fri *-*-* 02:00:00" >&2
			read -r -p "OnCalendar expression: " val </dev/tty || return 0
			[[ -n "$val" ]] || return 0
			backup_prefs_set_schedule_custom "$val" || {
				echo "Invalid OnCalendar expression" >&2
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

# tui_backup_settings_menu — Edit persisted backup location, schedule, and pruning.
tui_backup_settings_menu() {
	local action val was_enabled=0 schedule_label dir_label
	load_backup_prefs
	schedule_label="$(backup_prefs_schedule_summary)"
	dir_label="${BACKUP_PREFS_DIR}"

	while true; do
		action="$(tui_menu "Backup settings (saved to $(backup_prefs_path))" \
			"[Location] Directory: ${dir_label}" \
			"[Retention] Keep archives: ${BACKUP_PREFS_KEEP} (0=unlimited)" \
			"[Retention] Auto-prune after backup: $([[ "${BACKUP_PREFS_AUTO_PRUNE}" == "1" ]] && echo yes || echo no)" \
			"[Schedule] ${schedule_label}" \
			"[Schedule] Randomized delay: ${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}s" \
			"[Includes] local.env: $([[ "${BACKUP_PREFS_INCLUDE_LOCAL}" == "1" ]] && echo yes || echo no)" \
			"[Includes] profiles: $([[ "${BACKUP_PREFS_INCLUDE_PROFILES}" == "1" ]] && echo yes || echo no)" \
			"[Includes] tui.conf: $([[ "${BACKUP_PREFS_INCLUDE_TUI}" == "1" ]] && echo yes || echo no)" \
			"Reset to defaults" \
			"Save settings" \
			"Save & reinstall backup timer" \
			"Back")" || return 0

		case "$action" in
			"[Location] Directory:"*)
				read -r -p "Backup directory [${BACKUP_PREFS_DIR}]: " val </dev/tty || continue
				[[ -n "$val" ]] && BACKUP_PREFS_DIR="$(_backup_prefs_expand_path "$val")"
				dir_label="${BACKUP_PREFS_DIR}"
				;;
			"[Retention] Keep archives:"*)
				read -r -p "Keep newest N archives (0=unlimited) [${BACKUP_PREFS_KEEP}]: " val </dev/tty || continue
				[[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && BACKUP_PREFS_KEEP=$val
				;;
			"[Retention] Auto-prune after backup:"*)
				tui_backup_toggle_pref auto_prune
				;;
			"[Schedule] Randomized delay:"*)
				read -r -p "Randomized delay seconds [${BACKUP_PREFS_RANDOMIZED_DELAY_SEC}]: " val </dev/tty || continue
				[[ -n "$val" ]] && BACKUP_PREFS_RANDOMIZED_DELAY_SEC="$val"
				;;
			"[Schedule]"*)
				tui_backup_schedule_menu || continue
				schedule_label="$(backup_prefs_schedule_summary)"
				;;
			"[Includes] local.env:"*)
				tui_backup_toggle_pref include_local
				;;
			"[Includes] profiles:"*)
				tui_backup_toggle_pref include_profiles
				;;
			"[Includes] tui.conf:"*)
				tui_backup_toggle_pref include_tui
				;;
			"Reset to defaults")
				tui_confirm "Reset backup settings to repo defaults?" || continue
				reset_backup_prefs || continue
				load_backup_prefs
				schedule_label="$(backup_prefs_schedule_summary)"
				dir_label="${BACKUP_PREFS_DIR}"
				;;
			"Save settings")
				save_backup_prefs
				echo "Saved backup settings to $(backup_prefs_path)"
				tui_press_enter
				return 0
				;;
			"Save & reinstall backup timer")
				save_backup_prefs
				echo "Saved backup settings to $(backup_prefs_path)"
				if command -v systemctl >/dev/null 2>&1 \
					&& systemctl --user is-enabled launchlayer-backup.timer >/dev/null 2>&1; then
					was_enabled=1
				fi
				install_systemd_backup_units "$was_enabled"
				tui_press_enter
				return 0
				;;
			*) return 0 ;;
		esac
	done
}

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

# tui_backup_actions_menu — Run backups using saved preferences.
tui_backup_actions_menu() {
	local action path
	load_backup_prefs
	action="$(tui_menu "Backup actions" \
		"Show current preferences" \
		"Backup now (saved settings)" \
		"Backup to custom path" \
		"Run scheduled backup + prune" \
		"Back")" || return 0

	case "$action" in
		"Show current preferences")
			show_backup_prefs 0
			;;
		"Backup now (saved settings)")
			backup_prefs_apply_env
			backup_config "$(default_backup_dir)" \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0
			;;
		"Backup to custom path")
			read -r -p "Output directory or file [$(default_backup_dir)]: " path </dev/tty || return 0
			[[ -z "$path" ]] && path="$(default_backup_dir)"
			backup_prefs_apply_env
			backup_config "$path" \
				"${BACKUP_PREFS_INCLUDE_LOCAL}" \
				"${BACKUP_PREFS_INCLUDE_PROFILES}" \
				"${BACKUP_PREFS_INCLUDE_TUI}" 0
			;;
		"Run scheduled backup + prune")
			run_scheduled_backup "" "" 0
			;;
		*) return 0 ;;
	esac
	tui_press_enter
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
			export_config "$path" "$include_local" "$include_profiles" "$include_tui" 0
			;;
		"Import preview (dry-run)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			import_config "$path" 1 merge 0 "$include_local" "$include_profiles" "$include_tui" 0
			;;
		"Import apply (merge, skip existing)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			import_config "$path" 1 merge 0 "$include_local" "$include_profiles" "$include_tui" 0
			tui_confirm "Import new files only (skip existing)?" || return 0
			import_config "$path" 0 merge 1 "$include_local" "$include_profiles" "$include_tui" 0
			;;
		"Import apply (replace existing)")
			read -r -p "Archive path: " path </dev/tty || return 0
			[[ -n "$path" ]] || return 0
			include_local=1 include_profiles=1 include_tui=0
			tui_pick_import_includes include_local include_profiles include_tui || return 0
			import_config "$path" 1 replace 0 "$include_local" "$include_profiles" "$include_tui" 0
			tui_confirm "Overwrite existing config files from archive?" || return 0
			import_config "$path" 0 replace 1 "$include_local" "$include_profiles" "$include_tui" 0
			;;
		*) return 0 ;;
	esac
	tui_press_enter
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
			prune_backup_archives "$dir" "$keep" 1 0
			;;
		"Apply prune")
			prune_backup_archives "$dir" "$keep" 1 0
			tui_confirm "Delete archives beyond the newest $keep in $dir?" || return 0
			prune_backup_archives "$dir" "$keep" 0 0
			;;
		*) return 0 ;;
	esac
	tui_press_enter
}

# tui_backup_timer_menu — Systemd backup timer management.
tui_backup_timer_menu() {
	local action
	action="$(tui_menu "Backup timer (systemd)" \
		"Status" \
		"Install & enable" \
		"Enable" \
		"Reinstall (no enable)" \
		"Disable" \
		"Back")" || return 0

	case "$action" in
		"Status")
			systemd_backup_status
			;;
		"Install & enable")
			install_systemd_backup_units 1
			;;
		"Enable")
			handle_backup_timer_subcommand enable
			;;
		"Reinstall (no enable)")
			handle_backup_timer_subcommand reinstall
			;;
		"Disable")
			handle_backup_timer_subcommand disable
			;;
		*) return 0 ;;
	esac
	tui_press_enter
}

# tui_backup_menu — Backup hub (settings, actions, transfer, prune, timer).
tui_backup_menu() {
	local action prune_label
	tui_crumb_enter "Backup & restore"
	tui_remember_main_menu "Backup & restore"
	load_backup_prefs
	prune_label="$(backup_prune_summary) │ maint: $(tui_maintenance_timer_brief)"
	while true; do
		action="$(tui_menu "(${prune_label})" \
			"Settings & preferences" \
			"Backup actions" \
			"Export & import" \
			"Prune archives" \
			"Backup timer" \
			"Back")" || return 0

		case "$action" in
			"Settings & preferences")
				tui_backup_settings_menu
				load_backup_prefs
				prune_label="$(backup_prune_summary)"
				;;
			"Backup actions")
				tui_backup_actions_menu
				;;
			"Export & import")
				tui_backup_transfer_menu
				;;
			"Prune archives")
				tui_backup_prune_menu
				;;
			"Backup timer")
				tui_backup_timer_menu
				;;
			*)
				tui_crumb_leave
				return 0
				;;
		esac
	done
}
