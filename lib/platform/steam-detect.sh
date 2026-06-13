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
