# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=keys.sh
# shellcheck source=steam.sh
# lib/config.sh — Layered .env config loading and default values.
#
# Config resolution order:
#   0. launch.d/profiles/*.env (LAUNCHLAYER_PROFILES or auto-detected, layered)
#   1. launch.d/default.env
#   2. launch.d/presets/*.env (via INCLUDE= or auto-selected standard/native)
#   3. launch.d/<AppID>.env (overrides everything above)

[[ -n "${LAUNCHLAYER_CONFIG_LOADED:-}" ]] && return 0
LAUNCHLAYER_CONFIG_LOADED=1

# load_env_file — Parse KEY=VALUE lines from a file and export them.
#
# Skips comments, blank lines, and INCLUDE= directives (handled separately).
# When force=0, existing environment variables are not overwritten.
# When force=1, values from this file always win (used for per-appid overrides).
load_env_file() {
	local file=$1
	local force=${2:-0}

	[[ -f "$file" ]] || return 0

	local line key value
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Strip inline comments and surrounding whitespace.
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ -z "$line" ]] && continue
		[[ "$line" =~ ^INCLUDE= ]] && continue
		[[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue

		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		# Remove optional surrounding quotes.
		value="${value#\"}"; value="${value%\"}"
		value="${value#\'}"; value="${value%\'}"

		if [[ "$force" == "1" ]] || [[ -z "${!key+x}" ]]; then
			export "$key=$value"
			config_key_sources["$key"]="$file"
		fi
	done < "$file"

	debug "loaded $file"
}

# load_config_file — Recursively load a config file and its INCLUDE= chain.
#
# Tracks loaded files in config_loaded[] to prevent circular INCLUDE loops.
load_config_file() {
	local file=$1
	local force=$2
	local include_line include_path

	[[ -f "$file" ]] || return 0
	[[ -n "${config_loaded[$file]+x}" ]] && return 0
	config_loaded["$file"]=1

	# Process INCLUDE= before local keys so the preset layer sits underneath.
	include_line="$(grep -E '^[[:space:]]*INCLUDE=' "$file" 2>/dev/null | head -1 || true)"
	if [[ -n "$include_line" ]]; then
		include_path="${include_line#INCLUDE=}"
		include_path="${include_path#"${include_path%%[![:space:]]*}"}"
		include_path="${include_path%"${include_path##*[![:space:]]}"}"
		include_path="${include_path#\"}"; include_path="${include_path%\"}"
		include_path="${include_path#\'}"; include_path="${include_path%\'}"
		load_config_file "$LAUNCHD_DIR/$include_path" 0
	fi

	config_layers+=("$file")
	load_env_file "$file" "$force"
}

# appid_in_list_file — Return 0 if appid appears as a line in list_file.
appid_in_list_file() {
	local appid=$1
	local list_file=$2
	local line
	[[ -n "$appid" && -f "$list_file" ]] || return 1
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ "$line" == "$appid" ]] && return 0
	done < "$list_file"
	return 1
}

# config_file_relative — Strip LAUNCHD_DIR prefix for display.
config_file_relative() {
	local file=$1
	if [[ "$file" == "$LAUNCHD_DIR/"* ]]; then
		echo "${file#"$LAUNCHD_DIR/"}"
	else
		basename "$file"
	fi
}

# detect_steam_app_id — Resolve AppID from env vars or Steam launch argv.
detect_steam_app_id() {
	local arg prev=""
	steam_app_id=""

	if [[ -n "${SteamAppId:-}" && "${SteamAppId}" =~ ^[0-9]+$ ]]; then
		steam_app_id="$SteamAppId"
		return 0
	fi
	if [[ -n "${STEAM_APPID:-}" && "${STEAM_APPID}" =~ ^[0-9]+$ ]]; then
		steam_app_id="$STEAM_APPID"
		return 0
	fi

	for arg in "$@"; do
		if [[ "$prev" == "-applaunch" && "$arg" =~ ^[0-9]+$ ]]; then
			steam_app_id="$arg"
			return 0
		fi
		if [[ "$arg" =~ (AppId|SteamAppId)=([0-9]+) ]]; then
			steam_app_id="${BASH_REMATCH[2]}"
			return 0
		fi
		prev="$arg"
	done
}

# reset_config_state — Clear layered config before a fresh load (show-config / dry-run).
# shellcheck disable=SC2034  # reset for prepare_launch_context / show-config
reset_config_state() {
	local key
	config_loaded=()
	config_key_sources=()
	config_layers=()
	launch=()
	game_extra_argv=()
	is_native=0
	is_anticheat=0
	anticheat_type=""
	game_engine_hint=""
	steam_game_name=""

	for key in "${LAUNCHLAYER_CONFIG_KEYS[@]}"; do
		unset "$key" 2>/dev/null || true
	done
}

# load_profile_config — Load one or more machine profile layers when present.
load_profile_config() {
	local profiles profile profile_file

	profiles="${LAUNCHLAYER_PROFILES:-${STEAM_LAUNCH_PROFILES:-}}"
	if [[ -z "$profiles" && -n "${LAUNCHLAYER_PROFILE:-${STEAM_LAUNCH_PROFILE:-}}" ]]; then
		profiles="${LAUNCHLAYER_PROFILE:-${STEAM_LAUNCH_PROFILE:-}}"
	fi
	if [[ -z "$profiles" ]]; then
		profiles="$(detect_default_profiles 2>/dev/null || true)"
	fi
	[[ -n "$profiles" ]] || return 0

	profiles="${profiles//,/ }"
	for profile in $profiles; do
		profile_file="$PROFILES_DIR/${profile}.env"
		if [[ -f "$profile_file" ]]; then
			debug "loaded profile: $profile"
			load_config_file "$profile_file" 0
		fi
	done
}

# load_launch_config — Build the effective config for the current launch.
load_launch_config() {
	config_loaded=()
	config_key_sources=()
	config_layers=()
	load_profile_config
	load_config_file "$LAUNCHD_DIR/default.env" 0

	if [[ -z "$steam_app_id" ]]; then
		return 0
	fi

	if [[ -f "$LAUNCHD_DIR/${steam_app_id}.env" ]]; then
		# Per-game file overrides preset selection entirely.
		load_config_file "$LAUNCHD_DIR/${steam_app_id}.env" 1
	elif detect_native_game "$steam_app_id"; then
		debug "auto-selected preset: native"
		load_config_file "$LAUNCHD_DIR/presets/native.env" 0
	else
		debug "auto-selected preset: standard"
		load_config_file "$LAUNCHD_DIR/presets/standard.env" 0
	fi
}

# apply_defaults — Set fallback values for every tunable knob.
#
# Uses bash parameter expansion (: "${VAR:=default}") so explicit exports
# from .env files are never clobbered.
apply_defaults() {
	: "${BENCHMARK:=0}"
	: "${GAMEMODE:=1}"
	: "${MANGOHUD:=0}"
	: "${MANGOHUD_LOG:=0}"
	: "${NETWORK_TUNE:=0}"
	: "${DEBUG:=0}"
	: "${X3D_CPUS:=}"
	: "${GAME_NIC:=}"
	: "${GAMESCOPE:=0}"
	: "${GAMESCOPE_W:=}"
	: "${GAMESCOPE_H:=}"
	: "${GAMESCOPE_R:=}"
	: "${GAMESCOPE_ADAPTIVE_SYNC:=0}"
	: "${GAMESCOPE_EXPOSE_WAYLAND:=0}"
	: "${GAMESCOPE_FSR:=0}"
	: "${GAMESCOPE_FSR_SHARPNESS:=5}"
	: "${SHADER_CACHE_CHECK:=1}"
	: "${SHADER_CACHE_MAX_GB:=10}"
	: "${SHADER_CACHE_TRIM:=0}"
	: "${SHADER_CACHE_CHECK_INTERVAL_HOURS:=24}"
	: "${COMPATDATA_CHECK:=1}"
	: "${COMPATDATA_MAX_GB:=50}"
	: "${COMPATDATA_TRIM:=0}"
	: "${VM_MAX_MAP_COUNT_MIN:=$LAUNCHLAYER_VM_MAX_MAP_COUNT_DEFAULT}"
	: "${VM_MAX_MAP_COUNT_FIX:=0}"
	: "${VRAM_HOG_UNITS:=hyprwhspr.service app-dev.lizardbyte.app.Sunshine.service}"
	: "${VRAM_HOG_PIDS:=}"
	: "${VRAM_HOGS:=0}"
	: "${LAUNCH_WATCHDOG:=1}"
	: "${LAUNCH_WRAPPERS:=}"
	: "${LAUNCH_WRAPPERS_BEFORE:=}"
	: "${GAME_EXTRA_ARGS:=}"
	: "${UNSET_VARS:=}"
	: "${FORCE_NATIVE:=0}"
	: "${FORCE_PROTON:=0}"
	: "${VRAM_PREFLIGHT_MIN_MB:=0}"
	: "${PIPEWIRE_LOW_LATENCY:=0}"
	: "${LAUNCH_LOG_MAX_LINES:=5000}"
	: "${PRE_LAUNCH_CMD:=}"
	: "${POST_LAUNCH_CMD:=}"
	: "${DISK_PREFLIGHT_MIN_GB:=0}"
	: "${GPU_POWER_CHECK:=0}"
	: "${NVIDIA_POWER_MODE:=0}"
	: "${CONCURRENT_LAUNCH_GUARD:=1}"
	: "${GPU_VRAM_PROCESS_MIN_MB:=0}"
	: "${DISABLE_CPU_AFFINITY:=0}"
	: "${GAME_PERFORMANCE:=1}"
}

# write_appid_env_scaffold — Create launch.d/<AppID>.env from a preset name.
write_appid_env_scaffold() {
	local appid=$1 name=$2 preset=$3 path=${4:-}
	[[ -n "$path" ]] || path="$LAUNCHD_DIR/${appid}.env"
	cat > "$path" <<EOF
# $name (Steam AppID $appid)
INCLUDE=presets/${preset}.env

EOF
}
