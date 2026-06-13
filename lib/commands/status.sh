# shellcheck shell=bash
# lib/commands/status.sh

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
