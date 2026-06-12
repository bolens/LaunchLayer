# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=config.sh
# shellcheck source=steam.sh
# shellcheck source=hardware.sh
# shellcheck source=preflight.sh
# shellcheck source=vram.sh
# shellcheck source=inspect.sh
# shellcheck source=completions.sh
# lib/commands.sh — CLI subcommands for inspection and config scaffolding.

[[ -n "${LAUNCHLAYER_COMMANDS_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMMANDS_LOADED=1

# show_status — Print runtime state and optional per-appid cache sizes.
show_status() {
	local appid=${1:-} json=${2:-0}
	local active_pid alive="dead"

	if [[ "$json" == "1" ]]; then
		if [[ -f "$ACTIVE_LAUNCH_PID_FILE" ]]; then
			active_pid="$(<"$ACTIVE_LAUNCH_PID_FILE")"
			kill -0 "$active_pid" 2>/dev/null && alive="running"
		fi
		if [[ -n "$appid" ]]; then
			collect_cache_size_entries "$appid"
		fi
		printf '{'
		json_object_pair "vm_max_map_count" "$(json_number_or_string "$(sysctl -n vm.max_map_count 2>/dev/null || echo unknown)")"
		json_object_pair "vram_hog_refcount" "$(get_vram_ref_count)" 1
		json_object_pair "active_launch_pid" "$(json_string "${active_pid:-}")" 1
		json_object_pair "active_launch_state" "$(json_string "$alive")" 1
		json_object_pair "x3d_cpus_cache" "$(json_string "$( [[ -f $X3D_CPUS_CACHE_FILE ]] && cat "$X3D_CPUS_CACHE_FILE" || echo unset )")" 1
		json_object_pair "steam_root" "$(json_string "$STEAM_ROOT")" 1
		json_object_pair "gpu_vendor" "$(json_string "$(detect_gpu_vendor)")" 1
		json_object_pair "systemd_user" "$(json_bool "$(has_systemd_user && echo 1 || echo 0)")" 1
		if [[ -n "$appid" ]]; then
			printf ',"appid":%s' "$(json_string "$appid")"
			printf_cache_dirs_json_pair shader_cache_entries compatdata_entries
		fi
		printf '}\n'
		return 0
	fi

	echo "=== launchlayer status ==="
	echo "vm.max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo unknown)"
	echo "vram_hog_refcount=$(get_vram_ref_count)"
	[[ -f "$VRAM_STATE_FILE" ]] && sed 's/^/paused: /' "$VRAM_STATE_FILE" || echo "paused_vram_units: (none)"
	if [[ -f "$ACTIVE_LAUNCH_PID_FILE" ]]; then
		active_pid="$(<"$ACTIVE_LAUNCH_PID_FILE")"
		kill -0 "$active_pid" 2>/dev/null && alive="running"
		echo "active_launch_pid=$active_pid ($alive)"
	else
		echo "active_launch_pid: (none)"
	fi
	echo "x3d_cpus_cache=$( [[ -f $X3D_CPUS_CACHE_FILE ]] && cat "$X3D_CPUS_CACHE_FILE" || echo unset )"
	echo "steam_root=$STEAM_ROOT"
	echo "gpu_vendor=$(detect_gpu_vendor)"
	echo "systemd_user=$(has_systemd_user && echo yes || echo no)"
	if [[ -n "$appid" ]]; then
		echo
		collect_cache_size_entries "$appid"
		print_cache_dirs_text "Shader cache AppID $appid" "Compatdata AppID $appid"
	fi
}

# tool_available — Print yes/no for an optional dependency.
tool_available() {
	command_available "$1" && echo yes || echo no
}

# show_detect_environment — Print auto-detected platform and hardware state.
show_detect_environment() {
	local w h r profiles free_vram json=0 access
	while [[ "${1:-}" == --* ]]; do
		case "$1" in
			--json) json=1; shift ;;
			*) shift ;;
		esac
	done
	profiles="$(detect_default_profiles 2>/dev/null || true)"
	[[ -n "$profiles" ]] || profiles="${LAUNCHLAYER_PROFILES:-${LAUNCHLAYER_PROFILE:-none}}"
	read -r w h < <(detect_display_resolution) || true
	r="$(detect_display_refresh)"
	free_vram="$(gpu_vram_free_mb 2>/dev/null || echo unknown)"
	access="$(flatpak_script_access)"

	if [[ "$json" == "1" ]]; then
		printf '{"config_dir":%s,"script":%s,"steam_root":%s,"profiles":%s,"desktop":%s,"gpu_vendor":%s,"audio":%s,"wsl2":%s,"container":%s,"flatpak_steam":%s,"flatpak_script_access":%s,"systemd_user":%s,"x3d_cpus":%s,"default_nic":%s,"display":%s,"vrr":%s,"gpu_vram_free_mb":%s}\n' \
			"$(json_string "$CONFIG_DIR")" \
			"$(json_string "$LAUNCHLAYER_MAIN_SCRIPT")" \
			"$(json_string "$STEAM_ROOT")" \
			"$(json_string "$profiles")" \
			"$(json_string "$(detect_desktop_session)")" \
			"$(json_string "$(detect_gpu_vendor)")" \
			"$(json_string "$(detect_audio_server)")" \
			"$(json_bool "$(is_wsl2 && echo 1 || echo 0)")" \
			"$(json_bool "$(is_container && echo 1 || echo 0)")" \
			"$(json_bool "$(is_flatpak_steam && echo 1 || echo 0)")" \
			"$(json_string "$access")" \
			"$(json_bool "$(has_systemd_user && echo 1 || echo 0)")" \
			"$(json_string "$(detect_x3d_cpus)")" \
			"$(json_string "$(detect_default_nic 2>/dev/null || echo unknown)")" \
			"$(json_string "${w}x${h}@${r}Hz")" \
			"$(json_bool "$(detect_vrr_enabled && echo 1 || echo 0)")" \
			"$(json_number_or_string "$free_vram")"
		return 0
	fi

	echo "=== launchlayer environment ==="
	echo "config_dir=$CONFIG_DIR"
	echo "script=$LAUNCHLAYER_MAIN_SCRIPT"
	echo "steam_root=$STEAM_ROOT"
	echo "flatpak_steam=$(is_flatpak_steam && echo yes || echo no)"
	echo "flatpak_script_access=$access"
	[[ "$access" == needs_override ]] && echo "  hint: $(flatpak_override_hint)"
	echo "steam_deck=$(is_steam_deck && echo yes || echo no)"
	echo "wsl2=$(is_wsl2 && echo yes || echo no) container=$(is_container && echo yes || echo no)"
	echo "profiles=${profiles:-none}"
	echo "desktop=$(detect_desktop_session) audio=$(detect_audio_server)"
	echo "gpu_vendor=$(detect_gpu_vendor)"
	echo "systemd_user=$(has_systemd_user && echo yes || echo no)"
	echo "x3d_cpus=$(detect_x3d_cpus)"
	echo "default_nic=$(detect_default_nic 2>/dev/null || echo unknown)"
	echo "display=${w}x${h}@${r}Hz"
	echo "vrr=$(detect_vrr_enabled && echo yes || echo no)"
	echo "gpu_vram_free_mb=$free_vram"
	echo
	echo "Optional tools:"
	printf '  gamemoderun=%s game-performance=%s cpupower=%s powerprofilesctl=%s\n' \
		"$(tool_available gamemoderun)" \
		"$(tool_available game-performance)" \
		"$(tool_available cpupower)" \
		"$(tool_available powerprofilesctl)"
	printf '  gamescope=%s mangohud=%s nvidia-smi=%s taskset=%s\n' \
		"$(tool_available gamescope)" \
		"$(tool_available mangohud)" \
		"$(tool_available nvidia-smi)" \
		"$(tool_available taskset)"
}

# show_cpu_topology — Print lscpu summary and detected X3D_CPUS range.
show_cpu_topology() {
	echo "=== CPU topology ==="
	lscpu | grep -E 'Model name|CPU\(s\)|Thread|Core|Socket|NUMA|On-line|MHz'
	echo
	echo "Detected X3D_CPUS: $(detect_x3d_cpus | tr ',' '-')"
	echo "Default route NIC: $(detect_default_nic 2>/dev/null || echo unknown)"
	echo "Cached in: $X3D_CPUS_CACHE_FILE"
}

# list_games — Tabular or JSON list with launch-time detection (heuristics + lists).
list_games() {
	local configured_only=${1:-0} json=${2:-0} grep_pattern=${3:-}
	local cfg native eac ac_type engine

	CLI_JSON_OUTPUT=$json

	if [[ "$json" != "1" ]]; then
		printf '%-10s %-5s %-5s %-5s %-8s %-12s %s\n' APPID CFG NAT EAC AC-TYPE ENGINE NAME
	fi

	_list_games_one() {
		local appid=$1 name=$2 _manifest=$3

		cli_scan_progress_tick
		game_name_matches_grep "$name" "$grep_pattern" || return 0

		cfg=no; native=no; eac=no
		[[ -f "$LAUNCHD_DIR/${appid}.env" ]] && cfg=yes
		detect_native_game "$appid" 1 && native=yes
		detect_anticheat_game "$appid" && eac=yes
		ac_type="$(detect_anticheat_type "$appid")"
		engine="$(detect_engine_hint "$appid")"
		[[ -z "$ac_type" ]] && ac_type="-"
		[[ "$configured_only" == "1" && "$cfg" == no ]] && return 0

		if [[ "$json" == "1" ]]; then
			printf '{"appid":%s,"configured":%s,"native":%s,"eac":%s,"anticheat_type":%s,"engine":%s,"name":%s}\n' \
				"$(json_string "$appid")" \
				"$(json_bool "$([[ "$cfg" == yes ]] && echo 1 || echo 0)")" \
				"$(json_bool "$([[ "$native" == yes ]] && echo 1 || echo 0)")" \
				"$(json_bool "$([[ "$eac" == yes ]] && echo 1 || echo 0)")" \
				"$(json_string "$ac_type")" \
				"$(json_string "$engine")" \
				"$(json_string "$name")"
		else
			printf '%-10s %-5s %-5s %-5s %-8s %-12s %s\n' \
				"$appid" "$cfg" "$native" "$eac" "$ac_type" "$engine" "$name"
		fi
	}

	cli_scan_progress_begin "Listing installed games"
	foreach_installed_game _list_games_one
	cli_scan_progress_end
}

# resolve_appid_arg — Resolve CLI AppID or name fragment; prints AppID.
resolve_appid_arg() {
	local query=$1
	[[ -n "$query" ]] || return 1
	resolve_appid_query "$query"
}

# init_appid_config — Create launch.d/<AppID>.env from a named preset.
init_appid_config() {
	local appid=$1 preset=${2:-} force=${3:-0} name path
	[[ "$appid" =~ ^[0-9]+$ ]] || {
		echo "Usage: $0 --init-appid APPID|NAME [preset] [--force]" >&2
		return 1
	}
	name="$(get_game_name "$appid" 2>/dev/null || true)"
	[[ -n "$name" ]] || {
		echo "AppID $appid not found in installed Steam libraries." >&2
		return 1
	}
	path="$LAUNCHD_DIR/${appid}.env"
	if [[ -f "$path" && "$force" != "1" ]]; then
		echo "Config already exists: $path (use --force to overwrite)" >&2
		return 1
	fi
	if [[ -z "$preset" ]]; then
		preset="$(suggest_preset_for_appid "$appid")"
	fi
	case "$preset" in
		standard|competitive|lightweight|native) ;;
		*) echo "Unknown preset: $preset" >&2; return 1 ;;
	esac
	write_appid_env_scaffold "$appid" "$name" "$preset" "$path"
	if [[ "$force" == "1" ]]; then
		echo "Overwrote $path (preset: $preset)"
	else
		echo "Created $path (preset: $preset)"
	fi
}

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
			apply_defaults
			show_detect_environment "$@"
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
