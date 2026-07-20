# shellcheck shell=bash
# lib/commands/dispatch-config.sh

[[ -n "${LAUNCHLAYER_DISPATCH_CONFIG_LOADED:-}" ]] && return 0
LAUNCHLAYER_DISPATCH_CONFIG_LOADED=1

# dispatch_config_subcommand — Return 0 when verb is handled.
dispatch_config_subcommand() {
	local verb=${1:-}
	shift || true
	case "$verb" in
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
			local bc_output="" bc_local=1 bc_profiles=1 bc_tui=0 bc_json=0 arg
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
		--restore-backup)
			local rb_archive="" rb_dir="" rb_dry=1 rb_mode=replace rb_yes=0 rb_local=1 rb_profiles=1
			local rb_tui=0 rb_json=0 rb_list=0 rb_appid="" arg
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--dir) rb_dir=${2:-}; shift 2 ;;
					--dry-run) rb_dry=1; shift ;;
					--yes) rb_yes=1; rb_dry=0; shift ;;
					--merge) rb_mode=merge; shift ;;
					--replace) rb_mode=replace; shift ;;
					--exclude-local) rb_local=0; shift ;;
					--no-profiles) rb_profiles=0; shift ;;
					--include-tui) rb_tui=1; shift ;;
					--appid) rb_appid=${2:-}; shift 2 ;;
					--list) rb_list=1; shift ;;
					--json) rb_json=1; shift ;;
					*)
						[[ -z "$rb_archive" ]] && rb_archive=$1
						shift
						;;
				esac
			done
			if [[ "$rb_list" == "1" ]]; then
				list_backups "$rb_dir" "$rb_json"
			else
				restore_backup "$rb_archive" "$rb_dir" "$rb_dry" "$rb_mode" "$rb_yes" \
					"$rb_local" "$rb_profiles" "$rb_tui" "$rb_json" "$rb_appid"
			fi
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
		--suggest-config)
			local suggest_query="" suggest_apply=0
			while [[ $# -gt 0 ]]; do
				case "$1" in
					--apply) suggest_apply=1; shift ;;
					*) [[ -z "$suggest_query" ]] && suggest_query=$1; shift ;;
				esac
			done
			[[ -n "$suggest_query" ]] || {
				echo "Usage: $(cli_basename) --suggest-config APPID|NAME [--apply]" >&2
				return 1
			}
			local appid=$suggest_query
			if [[ ! "$appid" =~ ^[0-9]+$ ]]; then
				appid="$(resolve_appid_arg "$appid")" || return $?
			fi
			suggest_config "$appid" "$suggest_apply"
			;;
		--bulk-set-include)
			bulk_set_include_preset "$@"
			;;
		*)
			return 1
			;;
	esac
}
