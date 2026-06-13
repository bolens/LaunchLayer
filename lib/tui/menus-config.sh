# shellcheck shell=bash
# lib/tui/menus-config.sh — Config library and anticheat menus.

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
					tui_show_text "No profiles in $PROFILES_DIR" "Profiles"
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
					tui_show_text "No presets in $LAUNCHD_DIR/presets" "Presets"
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
				tui_show_text "local.env already exists — use overwrite or edit in place." "local.env"
			else
				tui_run_paged write_local_config 0 0 || true
			fi
			;;
		"Overwrite local.env (--force)")
			tui_confirm "Overwrite $LOCAL_CONFIG_FILE with detected defaults?" || return 0
			tui_run_paged write_local_config 1 0 || true
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
