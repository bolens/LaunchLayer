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

# resolve_proton_path — Resolve version name to absolute proton script path.
resolve_proton_path() {
	local version=$1
	local path

	if [[ "$version" == */proton && -f "$version" ]]; then
		echo "$version"
		return 0
	fi

	if [[ -n "${STEAM_ROOT:-}" ]]; then
		path="${STEAM_ROOT}/compatibilitytools.d/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
		path="${STEAM_ROOT}/steamapps/common/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
	fi

	local fallback_roots=(
		"${HOME}/.local/share/Steam"
		"${HOME}/.steam/root"
		"${HOME}/.steam/steam"
	)
	local root
	for root in "${fallback_roots[@]}"; do
		path="${root}/compatibilitytools.d/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
		path="${root}/steamapps/common/${version}/proton"
		if [[ -f "$path" ]]; then
			echo "$path"
			return 0
		fi
	done
	return 1
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

