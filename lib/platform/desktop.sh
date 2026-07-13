# shellcheck shell=bash
# lib/platform/desktop.sh — Desktop session, audio, NIC, and Flatpak access.
# _match_desktop_session — Map one XDG desktop string to a compositor id.
_match_desktop_session() {
	local session=${1,,}
	[[ -n "$session" ]] || return 1
	[[ "$session" == *gamescope* ]] && { echo gamescope; return 0; }
	[[ "$session" == *kde* || "$session" == *plasma* ]] && { echo kde; return 0; }
	[[ "$session" == *gnome* ]] && { echo gnome; return 0; }
	[[ "$session" == *cosmic* ]] && { echo cosmic; return 0; }
	[[ "$session" == *hyprland* ]] && { echo hyprland; return 0; }
	[[ "$session" == *sway* ]] && { echo sway; return 0; }
	[[ "$session" == *niri* ]] && { echo niri; return 0; }
	[[ "$session" == *river* ]] && { echo river; return 0; }
	[[ "$session" == *labwc* ]] && { echo labwc; return 0; }
	[[ "$session" == *wayfire* ]] && { echo wayfire; return 0; }
	[[ "$session" == *xfce* ]] && { echo xfce; return 0; }
	[[ "$session" == *mate* ]] && { echo mate; return 0; }
	[[ "$session" == *cinnamon* ]] && { echo cinnamon; return 0; }
	[[ "$session" == *weston* ]] && { echo weston; return 0; }
	[[ "$session" == *budgie* ]] && { echo budgie; return 0; }
	[[ "$session" == *pantheon* ]] && { echo pantheon; return 0; }
	[[ "$session" == *deepin* || "$session" == *dde* ]] && { echo deepin; return 0; }
	[[ "$session" == *lxqt* || "$session" == *lxde* || "$session" == *lxsession* ]] && { echo lxqt; return 0; }
	[[ "$session" == *enlightenment* ]] && { echo enlightenment; return 0; }
	[[ "$session" == i3 || "$session" == *i3* ]] && { echo i3; return 0; }
	[[ "$session" == *awesome* ]] && { echo awesome; return 0; }
	[[ "$session" == *openbox* ]] && { echo openbox; return 0; }
	[[ "$session" == *bspwm* ]] && { echo bspwm; return 0; }
	[[ "$session" == *qtile* ]] && { echo qtile; return 0; }
	[[ "$session" == *miracle* ]] && { echo miracle; return 0; }
	return 1
}

# is_wayland_session — True when running under a Wayland compositor session.
is_wayland_session() {
	[[ "${XDG_SESSION_TYPE:-}" == wayland ]] && return 0
	[[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0
	return 1
}

# compositor_session_active — True when a Wayland compositor IPC socket responds.
compositor_session_active() {
	case "$1" in
		hyprland)
			[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && return 0
			command -v hyprctl >/dev/null 2>&1 \
				&& hyprctl monitors -j >/dev/null 2>&1
			;;
		sway)
			[[ -n "${SWAYSOCK:-}" ]] && return 0
			command -v swaymsg >/dev/null 2>&1 \
				&& swaymsg -t get_version >/dev/null 2>&1
			;;
		niri)
			[[ -n "${NIRI_SOCKET:-}" ]] && return 0
			command -v niri >/dev/null 2>&1 \
				&& niri msg --version >/dev/null 2>&1
			;;
		river)
			[[ -n "${RIVER_STATUS:-}" ]] && return 0
			command -v riverctl >/dev/null 2>&1 \
				&& riverctl version >/dev/null 2>&1
			;;
		*)
			return 1
			;;
	esac
}

# detect_desktop_session — Return desktop/compositor id or unknown.
# Recognizes KDE, GNOME, COSMIC, Hyprland, Sway, Niri, River, wlroots compositors,
# Budgie, Pantheon, Deepin, LXQt, X11 WMs (i3, Openbox, …), and gamescope sessions.
detect_desktop_session() {
	local matched=""

	[[ -n "${STEAMDeck:-}" ]] && { echo gamescope; return 0; }
	[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && { echo hyprland; return 0; }
	[[ -n "${NIRI_SOCKET:-}" ]] && { echo niri; return 0; }
	[[ -n "${RIVER_STATUS:-}" ]] && { echo river; return 0; }
	[[ -n "${LABWC_PID:-}" ]] && { echo labwc; return 0; }
	[[ -n "${WAYFIRE_CONFIG:-}" ]] && { echo wayfire; return 0; }
	[[ -n "${COSMIC_SESSION:-}" || -n "${COSMIC_COMPOSITOR:-}" ]] && { echo cosmic; return 0; }

	matched="$(_match_desktop_session "${XDG_CURRENT_DESKTOP:-}" 2>/dev/null || true)"
	[[ -n "$matched" ]] && { echo "$matched"; return 0; }
	matched="$(_match_desktop_session "${XDG_SESSION_DESKTOP:-}" 2>/dev/null || true)"
	[[ -n "$matched" ]] && { echo "$matched"; return 0; }

	if is_wayland_session; then
		compositor_session_active hyprland && { echo hyprland; return 0; }
		compositor_session_active sway && { echo sway; return 0; }
		compositor_session_active niri && { echo niri; return 0; }
		compositor_session_active river && { echo river; return 0; }
	fi
	echo unknown
}
# detect_session_type — wayland, x11, tty, or unknown.
detect_session_type() {
	if is_wayland_session; then
		echo wayland
		return 0
	fi
	[[ -n "${DISPLAY:-}" ]] && { echo x11; return 0; }
	echo unknown
}
# process_running — True when a process name is running (portable pgrep).
process_running() {
	local name=$1
	pgrep -x "$name" >/dev/null 2>&1 && return 0
	pgrep "$name" >/dev/null 2>&1
}

# detect_default_nic — Interface for the default IPv4 route (Linux, BSD, macOS).
detect_default_nic() {
	local nic=""
	if command -v ip >/dev/null 2>&1; then
		nic="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"
		[[ -n "$nic" ]] && { echo "$nic"; return 0; }
	fi
	if command -v route >/dev/null 2>&1; then
		nic="$(route -4 get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
		[[ -n "$nic" ]] && { echo "$nic"; return 0; }
		nic="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
		[[ -n "$nic" ]] && { echo "$nic"; return 0; }
	fi
	if command -v netstat >/dev/null 2>&1; then
		nic="$(netstat -rn -f inet 2>/dev/null | awk '/^default/{print $NF; exit}')"
		[[ -n "$nic" ]] && echo "$nic"
	fi
}

# detect_nic_driver — Best-effort driver name for a NIC (default NIC when unset).
detect_nic_driver() {
	local nic="${1:-}"
	local sysfs_net="${LAUNCHLAYER_SYSFS_NET:-/sys/class/net}"
	[[ -n "$nic" ]] || nic="$(detect_default_nic 2>/dev/null || true)"
	[[ -n "$nic" ]] || { echo "unknown"; return 0; }
	if [[ -d "$sysfs_net/$nic/device/driver" ]]; then
		basename "$(readlink -f "$sysfs_net/$nic/device/driver")"
	elif command -v ethtool >/dev/null 2>&1; then
		ethtool -i "$nic" 2>/dev/null | awk '/^driver:/{print $2; exit}' || echo "unknown"
	else
		echo "unknown"
	fi
}

# detect_nic_type — wired, wireless, or loopback for a NIC (default NIC when unset).
detect_nic_type() {
	local nic="${1:-}"
	local sysfs_net="${LAUNCHLAYER_SYSFS_NET:-/sys/class/net}"
	[[ -n "$nic" ]] || nic="$(detect_default_nic 2>/dev/null || true)"
	[[ -n "$nic" ]] || { echo "unknown"; return 0; }
	if [[ -d "$sysfs_net/$nic/wireless" || -d "$sysfs_net/$nic/phy80211" ]]; then
		echo "wireless"
	elif [[ "$nic" == "lo" ]]; then
		echo "loopback"
	else
		echo "wired"
	fi
}

# detect_audio_server — Return pipewire, pulse, jack, or unknown.
detect_audio_server() {
	if process_running pipewire || command -v pw-metadata >/dev/null 2>&1; then
		echo pipewire
		return 0
	fi
	if process_running pulseaudio || command -v pactl >/dev/null 2>&1; then
		echo pulse
		return 0
	fi
	if process_running jackd || command -v jack_lsp >/dev/null 2>&1; then
		echo jack
		return 0
	fi
	echo unknown
}

# flatpak_script_access — Report ok, likely_ok, or needs_override for Flatpak Steam.
flatpak_script_access() {
	local script="${LAUNCHLAYER_MAIN_SCRIPT:-}"
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
