# shellcheck shell=bash
# lib/platform.sh — Cross-distro detection and portable system helpers.

[[ -n "${LAUNCHLAYER_PLATFORM_LOADED:-}" ]] && return 0
LAUNCHLAYER_PLATFORM_LOADED=1

# realpath_portable — Resolve symlinks without requiring GNU readlink -f.
realpath_portable() {
	local path=$1 resolved=""
	[[ -n "$path" ]] || return 1

	if resolved="$(readlink -f "$path" 2>/dev/null)" && [[ -n "$resolved" ]]; then
		printf '%s\n' "$resolved"
		return 0
	fi

	if command -v python3 >/dev/null 2>&1; then
		python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null && return 0
	fi

	# Last resort: cd + pwd (works for existing paths).
	if [[ -e "$path" ]]; then
		( cd "$(dirname "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")" )
		return 0
	fi
	return 1
}

# timestamp_iso — ISO-8601 timestamp without GNU date -Iseconds.
timestamp_iso() {
	if date -Iseconds >/dev/null 2>&1; then
		date -Iseconds
	else
		date '+%Y-%m-%dT%H:%M:%S%z'
	fi
}

# dir_size_bytes — Directory size in bytes (prefers du -b, falls back to 512-byte blocks).
dir_size_bytes() {
	local dir=$1 bytes=""
	[[ -d "$dir" ]] || return 1
	if bytes="$(du -sb "$dir" 2>/dev/null | awk '{print $1}')" && [[ "$bytes" =~ ^[0-9]+$ ]]; then
		echo "$bytes"
		return 0
	fi
	bytes="$(du -s "$dir" 2>/dev/null | awk '{print $1 * 512}')"
	[[ "$bytes" =~ ^[0-9]+$ ]] || return 1
	echo "$bytes"
}

# bytes_to_gb — Round bytes up to whole GB for display.
bytes_to_gb() {
	local size_bytes=${1:-0}
	echo $(( (size_bytes + 512 * 1024 * 1024) / 1024 / 1024 / 1024 ))
}

# dir_size_gb — Return directory size rounded up to whole GB (0 when missing/empty).
dir_size_gb() {
	local dir=$1 size_bytes
	size_bytes="$(dir_size_bytes "$dir" 2>/dev/null || true)"
	[[ -n "$size_bytes" && "$size_bytes" =~ ^[0-9]+$ ]] || {
		echo 0
		return 0
	}
	bytes_to_gb "$size_bytes"
}

# command_available — True when a binary is on PATH.
command_available() {
	command -v "$1" >/dev/null 2>&1
}

# df_avail_gb — Free space on a mount in whole GB.
df_avail_gb() {
	local path=$1 avail=""
	[[ -d "$path" ]] || return 1
	if avail="$(df -BG "$path" 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print $4}')" \
		&& [[ "$avail" =~ ^[0-9]+$ ]]; then
		echo "$avail"
		return 0
	fi
	avail="$(df -Pk "$path" 2>/dev/null | awk 'NR==2 {print int($4 / 1024 / 1024)}')"
	[[ "$avail" =~ ^[0-9]+$ ]] || return 1
	echo "$avail"
}

# has_systemd_user — True when systemd user session is available.
has_systemd_user() {
	command -v systemctl >/dev/null 2>&1 \
		&& systemctl --user show-environment >/dev/null 2>&1
}

# is_steam_deck — True on Steam Deck / SteamOS handheld sessions.
is_steam_deck() {
	[[ -n "${STEAM_DECK:-}" && "${STEAM_DECK}" != "0" ]] && return 0
	[[ -f /etc/os-release ]] || return 1
	grep -qiE '^(ID|ID_LIKE)=.*steamos' /etc/os-release 2>/dev/null \
		|| grep -qi '^ID=steamos' /etc/os-release 2>/dev/null
}

# is_flatpak_steam — True when Flatpak Steam data dir exists.
is_flatpak_steam() {
	[[ -d "${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/steamapps" ]]
}

# detect_steam_root — Probe common native, Flatpak, and Snap Steam install paths.
detect_steam_root() {
	local candidate steam_real

	if [[ -n "${STEAM_ROOT:-}" && -d "$STEAM_ROOT/steamapps" ]]; then
		printf '%s\n' "$STEAM_ROOT"
		return 0
	fi

	if [[ -L "${HOME}/.steam/root" ]]; then
		steam_real="$(realpath_portable "${HOME}/.steam/root" 2>/dev/null || true)"
		if [[ -n "$steam_real" && -d "$steam_real/steamapps" ]]; then
			printf '%s\n' "$steam_real"
			return 0
		fi
	fi

	for candidate in \
		"${HOME}/.local/share/Steam" \
		"${HOME}/.var/app/com.valvesoftware.Steam/data/Steam" \
		"${HOME}/snap/steam/common/.local/share/Steam" \
		"${HOME}/.steam/steam"; do
		if [[ -d "$candidate/steamapps" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	# Fall back to the conventional native path even if libraries are empty.
	printf '%s\n' "${HOME}/.local/share/Steam"
}

# detect_gpu_vendor — Return nvidia, amd, intel, or unknown.
detect_gpu_vendor() {
	local vendor=""
	if command -v nvidia-smi >/dev/null 2>&1 \
		&& nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -q .; then
		echo nvidia
		return 0
	fi
	for vendor in /sys/class/drm/card*/device/vendor; do
		[[ -f "$vendor" ]] || continue
		case "$(<"$vendor")" in
			0x10de) echo nvidia; return 0 ;;
			0x1002) echo amd; return 0 ;;
			0x8086) echo intel; return 0 ;;
		esac
	done
	echo unknown
}

# gpu_vram_free_mb — Best-effort free VRAM in MB for the primary GPU.
gpu_vram_free_mb() {
	local vendor free_mb=""
	vendor="$(detect_gpu_vendor)"

	case "$vendor" in
		nvidia)
			command -v nvidia-smi >/dev/null 2>&1 || return 1
			free_mb="$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null \
				| head -1 | tr -d ' ')"
			[[ "$free_mb" =~ ^[0-9]+$ ]] && echo "$free_mb"
			;;
		amd)
			local mem node total used
			for mem in /sys/class/drm/card*/device/mem_info_vram_used; do
				[[ -f "$mem" ]] || continue
				node="${mem%/mem_info_vram_used}"
				total="$(cat "${node}/mem_info_vram_total" 2>/dev/null || echo 0)"
				used="$(cat "$mem" 2>/dev/null || echo 0)"
				[[ "$total" =~ ^[0-9]+$ && "$used" =~ ^[0-9]+$ ]] || continue
				free_mb=$(( (total - used) / 1024 / 1024 ))
				echo "$free_mb"
				return 0
			done
			return 1
			;;
		*)
			return 1
			;;
	esac
}

# detect_desktop_session — Return kde, gnome, hyprland, sway, gamescope, or unknown.
detect_desktop_session() {
	local session="${XDG_CURRENT_DESKTOP:-}${XDG_SESSION_DESKTOP:-}"
	session="${session,,}"
	[[ "$session" == *gamescope* || -n "${STEAMDeck:-}" ]] && { echo gamescope; return 0; }
	[[ "$session" == *kde* || "$session" == *plasma* ]] && { echo kde; return 0; }
	[[ "$session" == *gnome* ]] && { echo gnome; return 0; }
	[[ "$session" == *hyprland* || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && { echo hyprland; return 0; }
	[[ "$session" == *sway* ]] && { echo sway; return 0; }
	command -v hyprctl >/dev/null 2>&1 && { echo hyprland; return 0; }
	command -v swaymsg >/dev/null 2>&1 && { echo sway; return 0; }
	echo unknown
}

# default_online_cpus — taskset range covering all online CPUs.
default_online_cpus() {
	local count last
	count="$(nproc 2>/dev/null || echo 0)"
	[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] || { echo "0"; return 0; }
	last=$((count - 1))
	if (( last == 0 )); then
		echo "0"
	else
		echo "0-$last"
	fi
}

# is_wsl2 — True when running under Windows Subsystem for Linux.
is_wsl2() {
	[[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] && return 0
	[[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
	grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

# is_container — True in Docker/LXC-style environments (best effort).
is_container() {
	[[ -f /.dockerenv ]] && return 0
	[[ -f /run/.containerenv ]] && return 0
	grep -qE 'docker|lxc|container' /proc/1/cgroup 2>/dev/null
}

# detect_audio_server — Return pipewire, pulse, jack, or unknown.
detect_audio_server() {
	if pgrep -x pipewire >/dev/null 2>&1 || command -v pw-metadata >/dev/null 2>&1; then
		echo pipewire
		return 0
	fi
	if pgrep -x pulseaudio >/dev/null 2>&1 || command -v pactl >/dev/null 2>&1; then
		echo pulse
		return 0
	fi
	if pgrep -x jackd >/dev/null 2>&1 || command -v jack_lsp >/dev/null 2>&1; then
		echo jack
		return 0
	fi
	echo unknown
}

# flatpak_script_access — Report ok, likely_ok, or needs_override for Flatpak Steam.
flatpak_script_access() {
	local script=${1:-${LAUNCHLAYER_MAIN_SCRIPT:-}}
	is_flatpak_steam || { echo ok; return 0; }
	[[ -n "$script" ]] || { echo unknown; return 0; }
	if [[ "$script" == "${HOME}"/* ]]; then
		echo likely_ok
		return 0
	fi
	if [[ "$script" == "${HOME}/.var/app/com.valvesoftware.Steam/"* ]]; then
		echo likely_ok
		return 0
	fi
	echo needs_override
}

# flatpak_override_hint — Suggested flatpak override when script is outside $HOME.
flatpak_override_hint() {
	printf 'flatpak override --user com.valvesoftware.Steam --filesystem=%s' "$CONFIG_DIR"
}

# detect_login_shell_name — Basename of the login shell (bash, zsh, fish, …).
detect_login_shell_name() {
	local shell_path="${SHELL:-}"
	[[ -n "$shell_path" ]] || shell_path="$(command -v bash 2>/dev/null || echo bash)"
	basename "$shell_path"
}

# profile_list_contains — True when profile name is already in a space-separated list.
profile_list_contains() {
	local list=$1 name=$2
	[[ " $list " == *" $name "* ]]
}

# detect_default_profiles — Space-separated auto-selected profile names (layered).
detect_default_profiles() {
	local -a profiles=()
	local -a seen=()
	local p vendor access

	local profiles_arg="${LAUNCHLAYER_PROFILES:-${STEAM_LAUNCH_PROFILES:-}}"
	if [[ -n "$profiles_arg" ]]; then
		echo "${profiles_arg//,/ }"
		return 0
	fi
	if [[ -n "${LAUNCHLAYER_PROFILE:-${STEAM_LAUNCH_PROFILE:-}}" ]]; then
		echo "${LAUNCHLAYER_PROFILE:-${STEAM_LAUNCH_PROFILE:-}}"
		return 0
	fi

	is_wsl2 && profiles+=(wsl2)
	is_steam_deck && profiles+=(steam-deck)
	is_flatpak_steam && profiles+=(flatpak-steam)
	vendor="$(detect_gpu_vendor)"
	case "$vendor" in
		amd) profiles+=(amd-gpu) ;;
		intel) profiles+=(intel-gpu) ;;
		nvidia) profiles+=(nvidia-desktop) ;;
	esac

	for p in "${profiles[@]}"; do
		profile_list_contains "${seen[*]}" "$p" && continue
		seen+=("$p")
	done
	((${#seen[@]} > 0)) && echo "${seen[*]}"
}

# detect_default_profile — Legacy single-profile helper (first auto-detected profile).
detect_default_profile() {
	detect_default_profiles | awk '{print $1}'
}

# init_platform_paths — Resolve STEAM_ROOT after explicit overrides are honored.
init_platform_paths() {
	if [[ -z "${STEAM_ROOT:-}" || ! -d "${STEAM_ROOT}/steamapps" ]]; then
		STEAM_ROOT="$(detect_steam_root)"
	fi
	export STEAM_ROOT
}

init_platform_paths
