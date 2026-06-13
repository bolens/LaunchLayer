# shellcheck shell=bash
# lib/commands/dispatch.sh
# handle_subcommand — Dispatch utility verbs; return 0 if handled, 1 if unknown.
handle_subcommand() {
	local verb=${1:-}
	shift || true
	case "$verb" in
		--pause-vram-hogs)
			pause_vram_hogs
			echo "Paused VRAM-heavy services (ref=$(get_vram_ref_count))"
			;;
		--resume-vram-hogs)
			resume_vram_hogs_force
			rm -f "$ACTIVE_LAUNCH_PID_FILE"
			stop_launch_watchdog
			echo "Resumed paused VRAM-heavy services."
			;;
		--cleanup-stale-launch)
			cleanup_stale_launch "${1:-}"
			;;
		--status)
			load_profile_config
			load_config_file "$LAUNCHD_DIR/default.env" 0
			apply_defaults
			local status_appid="" status_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) status_json=1 ;;
					*) [[ -z "$status_appid" ]] && status_appid=$arg ;;
				esac
			done
			if [[ -n "$status_appid" && ! "$status_appid" =~ ^[0-9]+$ ]]; then
				status_appid="$(resolve_appid_arg "$status_appid")" || return $?
			fi
			show_status "$status_appid" "$status_json"
			;;
		--show-cpu-topology)
			load_config_file "$LAUNCHD_DIR/default.env" 0
			apply_defaults
			show_cpu_topology
			;;
		--detect-environment)
			load_profile_config
			load_config_file "$LAUNCHD_DIR/default.env" 0
			[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
			apply_defaults
			show_detect_environment "$@"
			;;
		--detect-defaults)
			load_profile_config
			load_config_file "$LAUNCHD_DIR/default.env" 0
			apply_defaults
			local defaults_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) defaults_json=1 ;;
				esac
			done
			show_detected_defaults "$defaults_json"
			;;
		--write-local-config)
			local wl_force=0 wl_dry=0 arg
			for arg in "$@"; do
				case "$arg" in
					--force) wl_force=1 ;;
					--dry-run) wl_dry=1 ;;
				esac
			done
			write_local_config "$wl_force" "$wl_dry"
			;;
		--list-games)
			local configured_only=0 json=0 grep_pattern=""
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--configured) configured_only=1; shift ;;
					--json) json=1; shift ;;
					--grep) grep_pattern=${2:-}; shift 2 ;;
					*) break ;;
				esac
			done
			list_games "$configured_only" "$json" "$grep_pattern"
			;;
		--init-appid)
			local init_appid="" init_preset="" init_force=0 arg
			for arg in "$@"; do
				case "$arg" in
					--force) init_force=1 ;;
					standard|competitive|lightweight|native) init_preset=$arg ;;
					*)
						if [[ -z "$init_appid" ]]; then
							init_appid=$arg
						fi
						;;
				esac
			done
			if [[ -n "$init_appid" && ! "$init_appid" =~ ^[0-9]+$ ]]; then
				init_appid="$(resolve_appid_arg "$init_appid")" || return $?
			fi
			init_appid_config "$init_appid" "$init_preset" "$init_force"
			;;
		--init-unconfigured)
			local preset="" dry_run=0 eac_only=0
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--preset) preset=${2:-}; shift 2 ;;
					--dry-run) dry_run=1; shift ;;
					--eac-only) eac_only=1; shift ;;
					*) break ;;
				esac
			done
			init_unconfigured "$preset" "$dry_run" "$eac_only"
			;;
		--prune-uninstalled)
			local pu_dry=0 pu_yes=0 pu_json=0
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--dry-run) pu_dry=1; shift ;;
					--yes) pu_yes=1; shift ;;
					--json) pu_json=1; shift ;;
					*) break ;;
				esac
			done
			prune_uninstalled_configs "$pu_dry" "$pu_yes" "$pu_json"
			;;
		--export-config)
			local ec_output="" ec_local=0 ec_profiles=1 ec_tui=0 ec_json=0 arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--output) ec_output=${2:-}; shift 2 ;;
					--include-local) ec_local=1; shift ;;
					--no-profiles) ec_profiles=0; shift ;;
					--include-tui) ec_tui=1; shift ;;
					--json) ec_json=1; shift ;;
					*) break ;;
				esac
			done
			export_config "$ec_output" "$ec_local" "$ec_profiles" "$ec_tui" "$ec_json"
			;;
		--backup-config)
			local bc_output="$HOME" bc_local=1 bc_profiles=1 bc_tui=0 bc_json=0 arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--output) bc_output=${2:-}; shift 2 ;;
					--exclude-local) bc_local=0; shift ;;
					--no-profiles) bc_profiles=0; shift ;;
					--include-tui) bc_tui=1; shift ;;
					--json) bc_json=1; shift ;;
					*) break ;;
				esac
			done
			backup_config "$bc_output" "$bc_local" "$bc_profiles" "$bc_tui" "$bc_json"
			;;
		--import-config)
			local ic_archive="" ic_dry=1 ic_mode=merge ic_yes=0 ic_local=1 ic_profiles=1 ic_tui=0 ic_json=0 arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--dry-run) ic_dry=1; shift ;;
					--yes) ic_yes=1; ic_dry=0; shift ;;
					--merge) ic_mode=merge; shift ;;
					--replace) ic_mode=replace; shift ;;
					--exclude-local) ic_local=0; shift ;;
					--no-profiles) ic_profiles=0; shift ;;
					--include-tui) ic_tui=1; shift ;;
					--json) ic_json=1; shift ;;
					*)
						[[ -z "$ic_archive" ]] && ic_archive=$1
						shift
						;;
				esac
			done
			import_config "$ic_archive" "$ic_dry" "$ic_mode" "$ic_yes" "$ic_local" "$ic_profiles" "$ic_tui" "$ic_json"
			;;
		--prune-backups)
			local pb_dir="" pb_keep="" pb_dry=0 pb_json=0 arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--dir) pb_dir=${2:-}; shift 2 ;;
					--keep) pb_keep=${2:-}; shift 2 ;;
					--dry-run) pb_dry=1; shift ;;
					--json) pb_json=1; shift ;;
					*) break ;;
				esac
			done
			[[ -n "$pb_dir" ]] || pb_dir="$(default_backup_dir)"
			[[ -n "$pb_keep" ]] || pb_keep="$(default_backup_keep)"
			prune_backup_archives "$pb_dir" "$pb_keep" "$pb_dry" "$pb_json"
			;;
		--run-scheduled-backup)
			local rs_dir="" rs_keep="" rs_json=0 arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--dir) rs_dir=${2:-}; shift 2 ;;
					--keep) rs_keep=${2:-}; shift 2 ;;
					--json) rs_json=1; shift ;;
					*) break ;;
				esac
			done
			[[ -n "$rs_dir" ]] || rs_dir="$(default_backup_dir)"
			[[ -n "$rs_keep" ]] || rs_keep="$(default_backup_keep)"
			run_scheduled_backup "$rs_dir" "$rs_keep" "$rs_json"
			;;
		--backup-timer)
			handle_backup_timer_subcommand "$@"
			;;
		--backup-prefs)
			handle_backup_prefs_subcommand "$@"
			;;
		--tui-prefs)
			handle_tui_prefs_subcommand "$@"
			;;
		--tui-game-preview)
			local preview_appid=${1:-}
			[[ -n "$preview_appid" ]] || {
				echo "Usage: $0 --tui-game-preview APPID" >&2
				return 1
			}
			tui_render_game_preview "$preview_appid"
			;;
		--show-config)
			local cfg_query="" cfg_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) cfg_json=1 ;;
					*) [[ -z "$cfg_query" ]] && cfg_query=$arg ;;
				esac
			done
			show_config "$cfg_query" "$cfg_json"
			;;
		--edit-appid)
			local edit_query="" arg
			for arg in "$@"; do
				case "$arg" in
					--json) ;;
					*) [[ -z "$edit_query" ]] && edit_query=$arg ;;
				esac
			done
			edit_appid_config "$edit_query"
			;;
		--paths)
			local paths_query="" paths_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) paths_json=1 ;;
					*) [[ -z "$paths_query" ]] && paths_query=$arg ;;
				esac
			done
			show_paths "$paths_query" "$paths_json"
			;;
		--cache-report)
			local min_gb=5 mode=both grep_pattern="" cache_json=0
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--min-gb) min_gb=${2:-5}; shift 2 ;;
					--grep) grep_pattern=${2:-}; shift 2 ;;
					--shader-only) mode=shader; shift ;;
					--compat-only) mode=compat; shift ;;
					--json) cache_json=1; shift ;;
					*) shift ;;
				esac
			done
			cache_report "$min_gb" "$mode" "$grep_pattern" "$cache_json"
			;;
		--launch-stats)
			local stats_query="" stats_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) stats_json=1 ;;
					*) [[ -z "$stats_query" ]] && stats_query=$arg ;;
				esac
			done
			launch_stats "$stats_query" "$stats_json"
			;;
		--validate-config)
			local validate_target="all" validate_json=0 arg
			for arg in "$@"; do
				case "$arg" in
					--json) validate_json=1 ;;
					*) validate_target=$arg ;;
				esac
			done
			validate_config "$validate_target" "$validate_json"
			;;
		--scan-anticheat)
			local update_list=0
			[[ "${1:-}" == "--update-list" ]] && update_list=1
			scan_anticheat "$update_list"
			;;
		--scan-detections)
			scan_detections
			;;
		--completions)
			handle_completions_subcommand "$@"
			;;
		--tui)
			run_tui
			;;
		--doctor)
			local doctor_json=0
			[[ "${1:-}" == --json ]] && doctor_json=1
			show_doctor "$doctor_json"
			;;
		--setup)
			run_setup "$@"
			;;
		--install-systemd)
			install_systemd_user_units
			;;
		--sysctl)
			handle_sysctl_subcommand "${1:-status}"
			;;
		--hub-fingerprint)
			load_profile_config
			load_config_file "$LAUNCHD_DIR/default.env" 0
			[[ -f "$LAUNCHD_DIR/local.env" ]] && load_config_file "$LAUNCHD_DIR/local.env" 0
			apply_defaults
			hub_show_fingerprint "$@"
			;;
		--hub-publish)
			hub_publish_config "$@"
			;;
		--hub-update)
			hub_update_config "$@"
			;;
		--hub-delete)
			hub_delete_config "$@"
			;;
		--hub-recommend)
			hub_recommend_configs "$@"
			;;
		--hub-apply)
			hub_apply_config "$@"
			;;
		--hub-search)
			hub_search_machines "$@"
			;;
		--hub-prefs)
			handle_hub_prefs_subcommand "$@"
			;;
		--bulk-set-include)
			bulk_set_include_preset "$@"
			;;
		--help|-h)
			print_help
			;;
		--version|-V)
			print_version
			;;
		*)
			return 1
			;;
	esac
}
