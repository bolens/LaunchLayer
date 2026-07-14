# shellcheck shell=bash
# lib/platform/steam-detect.sh — Steam root, Deck, and Flatpak detection.
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
		"${HOME}/.steam/steam" \
		"${HOME}/.steam/root" \
		"/var/home/${USER:-$(id -un 2>/dev/null || echo "")}/.local/share/Steam"; do
		[[ -n "$candidate" && "$candidate" != */ ]] || continue
		if [[ -d "$candidate/steamapps" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	# Fall back to the conventional native path even if libraries are empty.
	printf '%s\n' "${HOME}/.local/share/Steam"
}

# steam_compat_tool_roots — Print candidate compatibilitytools.d directories.
steam_compat_tool_roots() {
	local root
	[[ -n "${STEAM_ROOT:-}" ]] && printf '%s\n' "${STEAM_ROOT}/compatibilitytools.d"
	for root in \
		"${HOME}/.local/share/Steam/compatibilitytools.d" \
		"${HOME}/.steam/root/compatibilitytools.d" \
		"${HOME}/.steam/steam/compatibilitytools.d" \
		"/usr/share/steam/compatibilitytools.d"; do
		printf '%s\n' "$root"
	done
}

# resolve_proton_path — Resolve version name to absolute proton script path.
resolve_proton_path() {
	local version=$1
	local path root

	if [[ "$version" == */proton && -f "$version" ]]; then
		echo "$version"
		return 0
	fi

	while IFS= read -r root; do
		[[ -n "$root" ]] || continue
		path="${root}/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
	done < <(steam_compat_tool_roots)

	if [[ -n "${STEAM_ROOT:-}" ]]; then
		path="${STEAM_ROOT}/steamapps/common/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
	fi

	for root in \
		"${HOME}/.local/share/Steam" \
		"${HOME}/.steam/root" \
		"${HOME}/.steam/steam"; do
		path="${root}/steamapps/common/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
	done
	return 1
}

# list_installed_compat_tools — Print installed compatibility tool directory names.
list_installed_compat_tools() {
	local root entry name
	local -A seen=()
	while IFS= read -r root; do
		[[ -d "$root" ]] || continue
		for entry in "$root"/*; do
			[[ -d "$entry" ]] || continue
			[[ -f "$entry/proton" || -f "$entry/compatibilitytool.vdf" ]] || continue
			name="$(basename "$entry")"
			[[ -n "${seen[$name]+x}" ]] && continue
			seen["$name"]=1
			printf '%s\n' "$name"
		done
	done < <(steam_compat_tool_roots)
}

# prefer_proton_cachyos — Print preferred installed Proton-CachyOS tool name, or empty.
prefer_proton_cachyos() {
	local name
	local -a preferred=(proton-cachyos-slr proton-cachyos-native)
	for name in "${preferred[@]}"; do
		if resolve_proton_path "$name" >/dev/null 2>&1; then
			printf '%s\n' "$name"
			return 0
		fi
	done
	while IFS= read -r name; do
		[[ "${name,,}" == *cachyos* ]] || continue
		printf '%s\n' "$name"
		return 0
	done < <(list_installed_compat_tools)
	return 1
}

# proton_tool_family — Classify a Proton/compat tool name: valve|ge|cachyos|em|unknown.
proton_tool_family() {
	local name=${1:-}
	local n=${name,,}
	[[ -z "$n" ]] && {
		printf 'valve\n'
		return 0
	}
	case "$n" in
		ge-proton*|proton-ge*|geproton*) printf 'ge\n' ;;
		*cachyos*) printf 'cachyos\n' ;;
		proton-em*|proton_em*|em-proton*) printf 'em\n' ;;
		proton_*|proton-stable*|proton\ experimental*) printf 'valve\n' ;;
		*) printf 'unknown\n' ;;
	esac
}

# proton_tool_supports_upscaler_upgrades — True for GE / CachyOS / (FSR4-only) EM forks.
proton_tool_supports_upscaler_upgrades() {
	local name=${1:-} family
	family="$(proton_tool_family "$name")"
	case "$family" in
		ge|cachyos|em) return 0 ;;
		*) return 1 ;;
	esac
}

# resolve_effective_proton_tool — OVERRIDE_PROTON, else AppID tool, else empty.
resolve_effective_proton_tool() {
	local appid="${steam_app_id:-}"
	if [[ -n "${OVERRIDE_PROTON:-}" ]]; then
		printf '%s\n' "${OVERRIDE_PROTON}"
		return 0
	fi
	[[ -n "$appid" ]] || return 1
	get_proton_tool_for_appid "$appid" 2>/dev/null
}

# ananicy_cpp_active — True when ananicy-cpp systemd unit is active.
ananicy_cpp_active() {
	command_available systemctl || return 1
	systemctl is-active --quiet ananicy-cpp 2>/dev/null
}

# sched_ext_supported — Kernel exposes sched_ext sysfs (Linux 6.12+ gaming kernels).
sched_ext_supported() {
	[[ -d /sys/kernel/sched_ext ]]
}

# sched_ext_loaded — True when a sched_ext userspace scheduler is attached.
sched_ext_loaded() {
	local ops=""
	[[ -r /sys/kernel/sched_ext/root/ops ]] || return 1
	ops="$(tr -d '[:space:]' < /sys/kernel/sched_ext/root/ops 2>/dev/null || true)"
	[[ -n "$ops" && "$ops" != "(none)" && "$ops" != "none" ]]
}

# sched_ext_ops_name — Print attached sched_ext ops name, or empty.
sched_ext_ops_name() {
	sched_ext_loaded || return 1
	tr -d '[:space:]' < /sys/kernel/sched_ext/root/ops 2>/dev/null
}

# apply_override_proton — Rewrite */proton entries in an argv array (nameref).
apply_override_proton() {
	local -n _argv=$1
	[[ -n "${OVERRIDE_PROTON:-}" ]] || return 0
	local resolved_proton
	if ! resolved_proton="$(resolve_proton_path "$OVERRIDE_PROTON" 2>/dev/null)"; then
		warn "OVERRIDE_PROTON=${OVERRIDE_PROTON} failed: compatibility layer not found"
		return 0
	fi
	local -a modified_args=()
	local arg
	for arg in "${_argv[@]}"; do
		if [[ "$arg" == */proton ]]; then
			modified_args+=("$resolved_proton")
			debug "overridden Proton path: $resolved_proton"
		else
			modified_args+=("$arg")
		fi
	done
	_argv=("${modified_args[@]}")
}

