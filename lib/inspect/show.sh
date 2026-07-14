# shellcheck shell=bash
# lib/inspect/show.sh

[[ -n "${LAUNCHLAYER_INSPECT_LOADED:-}" ]] && return 0
LAUNCHLAYER_INSPECT_LOADED=1
# show_paths — Print shader cache, compatdata, install, and config paths for a game.
show_paths() {
	local query=$1 json=${2:-0}
	local appid name game_dir proton_tool config_path

	[[ -n "$query" ]] || {
		echo "Usage: $0 --paths APPID|NAME [--json]" >&2
		return 1
	}

	appid="$(resolve_appid_query "$query")" || return $?
	name="$(get_game_name "$appid" 2>/dev/null || echo unknown)"
	game_dir="$(get_game_dir_for_appid "$appid" 2>/dev/null || true)"
	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	config_path="$(resolve_appid_env_path "$appid")"

	collect_cache_size_entries "$appid"

	if [[ "$json" == "1" ]]; then
		printf '{'
		json_object_pair "appid" "$(json_string "$appid")"
		json_object_pair "name" "$(json_string "$name")" 1
		json_object_pair "config" "$(json_string "$config_path")" 1
		json_object_pair "install_dir" "$(json_string "$game_dir")" 1
		json_object_pair "proton_tool" "$(json_string "$proton_tool")" 1
		printf_cache_dirs_json_pair shader_cache_entries compatdata_entries
		printf '}\n'
		return 0
	fi

	echo "=== Paths for AppID $appid ($name) ==="
	echo "config=$config_path$([[ -f "$config_path" ]] && echo ' (exists)' || echo ' (missing)')"
	[[ -n "$game_dir" ]] && echo "install_dir=$game_dir" || echo "install_dir: (not found)"
	[[ -n "$proton_tool" ]] && echo "proton_tool=$proton_tool"
	echo
	print_cache_dirs_text "Shader cache" "Compatdata"
}

# show_config — Print resolved config and launch chain for an AppID or name fragment.
show_config() {
	local query=$1 json=${2:-0}
	local appid resolved chain_args=()
	[[ -n "$query" ]] || {
		echo "Usage: $0 --show-config APPID|NAME [--json]" >&2
		return 1
	}

	resolved="$(resolve_appid_query "$query")" || return $?
	appid="$resolved"

	prepare_launch_context "$appid"
	local name="${steam_game_name:-unknown}" proton_tool="" compat_path=""

	if [[ "$json" == "1" ]]; then
		show_config_json "$appid" "$name"
		return 0
	fi

	echo "=== Config for AppID $appid ($name) ==="
	echo "Layers:"
	local layer
	for layer in "${config_layers[@]}"; do
		echo "  → $(config_file_relative "$layer")"
	done
	echo
	echo "Detection: native=$is_native anticheat=$is_anticheat type=${anticheat_type:-none} engine=$game_engine_hint"
	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	compat_path="$(get_compatdata_path_for_appid "$appid" 2>/dev/null || true)"
	if [[ -n "$compat_path" ]]; then
		echo "Proton prefix: $compat_path${proton_tool:+ (tool: $proton_tool)}"
	fi
	if detect_dlss_present "$appid"; then
		local cachyos_tool=""
		echo "Note: DLSS libraries detected — consider DLSS_SWAPPER=1 (NGX) or PROTON_DLSS_UPGRADE=1 (GE/CachyOS/EM)"
		if cachyos_tool="$(prefer_proton_cachyos 2>/dev/null)"; then
			echo "Note: Proton-CachyOS available ($cachyos_tool) — good match for PROTON_DLSS_UPGRADE"
		fi
		if optional_tool_installed dlss-updater 2>/dev/null; then
			echo "Note: dlss-updater GUI installed — use for in-place DLL replace; no launch CLI"
		fi
	fi
	case "$(detect_gpu_vendor 2>/dev/null || true)" in
		amd)
			echo "Note: AMD — consider PROTON_FSR4_UPGRADE=1 with Proton-CachyOS/GE (RDNA3 uses RDNA3 DLL path automatically)"
			;;
		intel)
			echo "Note: Intel — consider PROTON_XESS_UPGRADE=1 with Proton-CachyOS/GE"
			;;
	esac
	echo
	print_effective_config_summary
	echo
	echo "Launch chain:"
	chain_args=("${launch[@]}" "<steam %command%>" "${game_extra_argv[@]}")
	printf '  %q' "${chain_args[@]}"
	echo
}

# collect_effective_settings_json — Build JSON array of {key,value,source} objects.
collect_effective_settings_json() {
	local first=1
	_json_settings_item() {
		(( first )) || printf ','
		first=0
		printf '{"key":%s,"value":%s,"source":%s}' \
			"$(json_string "$1")" \
			"$(json_string "$2")" \
			"$(json_string "$(config_file_relative "$3")")"
	}
	printf '['
	for_each_effective_setting _json_settings_item
	printf ']'
}

# show_config_json — Machine-readable resolved config for an AppID.
show_config_json() {
	local appid=$1 name=$2
	local proton_tool="" compat_path="" layer
	local -a rel_layers=() chain_args=()

	proton_tool="$(get_proton_tool_for_appid "$appid" 2>/dev/null || true)"
	compat_path="$(get_compatdata_path_for_appid "$appid" 2>/dev/null || true)"
	for layer in "${config_layers[@]}"; do
		rel_layers+=("$(config_file_relative "$layer")")
	done
	chain_args=("${launch[@]}" "<steam %command%>" "${game_extra_argv[@]}")

	printf '{'
	json_object_pair "appid" "$(json_string "$appid")"
	json_object_pair "name" "$(json_string "$name")" 1
	json_object_pair "layers" "$(json_array_strings rel_layers)" 1
	printf ',"detection":{"native":%s,"anticheat":%s,"type":%s,"engine":%s}' \
		"$(json_bool "$is_native")" \
		"$(json_bool "$is_anticheat")" \
		"$(json_string "${anticheat_type:-}")" \
		"$(json_string "$game_engine_hint")"
	printf ',"proton_prefix":%s,"proton_tool":%s,"dlss_present":%s' \
		"$(json_string "$compat_path")" \
		"$(json_string "$proton_tool")" \
		"$(json_bool "$(detect_dlss_present "$appid" && echo 1 || echo 0)")"
	printf ',"settings":'
	collect_effective_settings_json
	printf ',"launch_chain":%s}\n' "$(json_array_strings chain_args)"
}
