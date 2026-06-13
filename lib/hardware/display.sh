# shellcheck shell=bash
# lib/hardware/display.sh
detect_active_output() {
	local desktop name=""
	desktop="$(detect_desktop_session)"
	case "$desktop" in
		kde) name="$(detect_kwin_active_output)" ;;
		hyprland)
			compositor_session_active hyprland \
				&& name="$(detect_hyprland_active_output)"
			;;
		sway)
			compositor_session_active sway \
				&& name="$(detect_sway_active_output)"
			;;
		gnome|cosmic|budgie|pantheon|deepin) name="$(detect_gnome_primary_output)" ;;
		niri)
			compositor_session_active niri \
				&& name="$(detect_niri_active_output)"
			;;
		river)
			compositor_session_active river \
				&& name="$(detect_river_active_output)"
			;;
		labwc|wayfire|weston|miracle) name="$(detect_wlr_active_output)" ;;
		xfce|mate|cinnamon|lxqt|enlightenment|i3|awesome|openbox|bspwm|qtile)
			name="$(detect_xrandr_active_output)"
			;;
	esac
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	if compositor_session_active hyprland; then
		name="$(detect_hyprland_active_output)"
		[[ -n "$name" ]] && { echo "$name"; return 0; }
	fi
	if compositor_session_active sway; then
		name="$(detect_sway_active_output)"
		[[ -n "$name" ]] && { echo "$name"; return 0; }
	fi
	if compositor_session_active niri; then
		name="$(detect_niri_active_output)"
		[[ -n "$name" ]] && { echo "$name"; return 0; }
	fi
	if compositor_session_active river; then
		name="$(detect_river_active_output)"
		[[ -n "$name" ]] && { echo "$name"; return 0; }
	fi
	name="$(detect_kwin_active_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_gnome_primary_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_wlr_active_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_xrandr_active_output)"
	[[ -n "$name" ]] && echo "$name"
}

# parse_wlr_randr_output — Read width height refresh from wlr-randr for a named output.
parse_wlr_randr_output() {
	local output=$1
	command -v wlr-randr >/dev/null 2>&1 || return 1
	wlr-randr 2>/dev/null | awk -v out="$output" '
		$1 == out && /current/ {
			if (match($0, /([0-9]+)x([0-9]+)/, m)) { w=m[1]; h=m[2] }
			if (match($0, /([0-9.]+)[[:space:]]*Hz/, r)) { hz=r[1] }
		}
		END {
			if (w != "" && h != "") {
				printf "%s %s", w, h
				if (hz != "") printf " %s", hz
				print ""
			}
		}'
}

# detect_kwin_active_output — Focused output name via KDE KWin (Plasma 6).
detect_kwin_active_output() {
	local name=""
	if command -v qdbus6 >/dev/null 2>&1; then
		name="$(qdbus6 org.kde.KWin /KWin org.kde.KWin.activeOutputName 2>/dev/null || true)"
	elif command -v qdbus >/dev/null 2>&1; then
		name="$(qdbus org.kde.KWin /KWin org.kde.KWin.activeOutputName 2>/dev/null || true)"
	fi
	[[ -n "$name" ]] && echo "$name"
}

# detect_display_resolution — Width/height for the active or primary display.
detect_display_resolution() {
	local w="" h="" output="" mode=""

	if is_steam_deck; then
		: "${w:=1280}"
		: "${h:=800}"
		echo "$w $h"
		return 0
	fi

	if is_darwin; then
		read -r w h < <(detect_darwin_display_mode 2>/dev/null || true) || true
		if [[ -n "$w" && -n "$h" && "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]]; then
			echo "$w $h"
			return 0
		fi
	fi

	read -r w h _ output < <(detect_compositor_display_mode 2>/dev/null || true) || true

	if { [[ -z "$w" || -z "$h" ]] || [[ ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; }; then
		output="$(detect_active_output)"
		if [[ -n "$output" ]]; then
			read -r w h _ < <(parse_wlr_randr_output "$output" 2>/dev/null || true) || true
		fi
	fi

	if { [[ -z "$w" || -z "$h" ]] || [[ ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; } \
		&& command -v kreadconfig6 >/dev/null 2>&1; then
		w="$(kreadconfig6 --file kwinrc --group X11 --key ScreenWidth 2>/dev/null || true)"
		h="$(kreadconfig6 --file kwinrc --group X11 --key ScreenHeight 2>/dev/null || true)"
	fi

	if { [[ -z "$w" || -z "$h" ]] || [[ ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; } \
		&& command -v wlr-randr >/dev/null 2>&1; then
		read -r w h < <(wlr-randr 2>/dev/null | awk '/current/ {
			if (match($0, /([0-9]+)x([0-9]+)/, m)) { print m[1], m[2]; exit }
		}') || true
	fi

	if { [[ -z "$w" || -z "$h" ]] || [[ ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; } \
		&& command -v xrandr >/dev/null 2>&1; then
		read -r w h < <(xrandr --query 2>/dev/null | awk '
			/ connected/ && / primary / {
				if (match($0, /([0-9]+)x([0-9]+)/, m)) { print m[1], m[2]; exit }
			}
			/ connected/ && !fallback {
				if (match($0, /([0-9]+)x([0-9]+)/, m)) {
					fw = m[1]; fh = m[2]; fallback = 1
				}
			}
			END { if (fw != "") print fw, fh }
		') || true
	fi

	: "${w:=3440}"
	: "${h:=1440}"
	echo "$w $h"
}

# detect_display_refresh — Refresh rate in Hz for the active or primary display.
detect_display_refresh() {
	local rate="" output="" mode=""

	if is_steam_deck; then
		echo 60
		return 0
	fi

	read -r _ _ rate _ < <(detect_compositor_display_mode 2>/dev/null || true) || true

	if [[ -z "$rate" ]]; then
		output="$(detect_active_output)"
		if [[ -n "$output" ]]; then
			read -r _ _ rate < <(parse_wlr_randr_output "$output" 2>/dev/null || true) || true
		fi
	fi

	if [[ -z "$rate" ]] && command -v wlr-randr >/dev/null 2>&1; then
		rate="$(wlr-randr 2>/dev/null | awk '/current/ {
			if (match($0, /([0-9.]+)[[:space:]]*Hz/, m)) { print m[1]; exit }
		}')"
	fi
	if [[ -z "$rate" ]] && command -v xrandr >/dev/null 2>&1; then
		rate="$(xrandr --query 2>/dev/null | awk '
			/ connected/ && / primary / { out = $1; primary = 1 }
			out != "" && $1 == out && /\*/ {
				if (match($0, /([0-9]+\.[0-9]+)/, m)) { print m[1]; exit }
			}
			/ connected/ && !seen {
				out = $1; seen = 1
			}
			seen && out != "" && $1 == out && /\*/ {
				if (match($0, /([0-9]+\.[0-9]+)/, m)) { print m[1]; exit }
			}
		')"
	fi
	[[ -n "$rate" ]] && rate="${rate%%.*}"
	: "${rate:=120}"
	echo "$rate"
}

# detect_wlr_vrr_enabled — True when wlr-randr reports adaptive sync on the active output.
detect_wlr_vrr_enabled() {
	local output="" result=""
	command -v wlr-randr >/dev/null 2>&1 || return 1
	output="$(detect_active_output 2>/dev/null || true)"
	[[ -n "$output" ]] || return 1
	result="$(wlr-randr 2>/dev/null | awk -v out="$output" '
		$1 == out { block=1; next }
		block && /^[^ \t]/ { exit }
		block && /Adaptive sync|VRR/ && /on|enabled|yes/ { print 1; exit }
	')"
	[[ "$result" == 1 ]]
}

# detect_compositor_vrr_enabled — Session-aware VRR/adaptive sync check.
detect_compositor_vrr_enabled() {
	local desktop vrr=""
	desktop="$(detect_desktop_session)"
	case "$desktop" in
		hyprland)
			compositor_session_active hyprland \
				&& command -v hyprctl >/dev/null 2>&1 \
				&& hyprctl monitors -j 2>/dev/null | parse_json_focused_vrr \
				&& return 0
			;;
		sway)
			compositor_session_active sway \
				&& command -v swaymsg >/dev/null 2>&1 \
				&& swaymsg -t get_outputs 2>/dev/null | parse_json_focused_vrr \
				&& return 0
			;;
		niri)
			compositor_session_active niri \
				&& command -v niri >/dev/null 2>&1 \
				&& niri msg -j outputs 2>/dev/null | parse_json_focused_vrr \
				&& return 0
			;;
		gnome|cosmic|budgie|pantheon|deepin)
			detect_gnome_vrr_enabled && return 0
			;;
		kde)
			if command -v kreadconfig6 >/dev/null 2>&1; then
				vrr="$(kreadconfig6 --file kwinrc --group Compositing --key AllowVrr 2>/dev/null \
					|| kreadconfig6 --file kwinrc --group Compositing --key AllowVRR 2>/dev/null \
					|| true)"
				[[ "$vrr" == 1 || "$vrr" == true ]] && return 0
			fi
			;;
	esac
	detect_wlr_vrr_enabled && return 0
	return 1
}

# detect_vrr_enabled — Best-effort VRR/G-Sync availability check.
detect_vrr_enabled() {
	local vendor
	detect_compositor_vrr_enabled && return 0
	vendor="$(detect_gpu_vendor)"
	if [[ "$vendor" == nvidia ]] && command -v nvidia-settings >/dev/null 2>&1; then
		local vrr
		vrr="$( { nvidia-settings -q AllowVRR -t 2>/dev/null || true; } | head -1 | tr -d ' ')"
		[[ "$vrr" == "1" ]] && return 0
	fi
	return 1
}

# detect_displays_json — JSON array of connected outputs [{name,width,height,refresh,primary}, ...].
detect_displays_json() {
	local -a lines=() first=1 line name pri w h hz
	if parse_kscreen_doctor_outputs >/dev/null 2>&1; then
		mapfile -t lines < <(parse_kscreen_doctor_outputs)
		((${#lines[@]})) || return 1
		printf '['
		for line in "${lines[@]}"; do
			read -r name pri w h hz <<< "$line"
			(( first )) || printf ','
			first=0
			printf '{"name":%s,"width":%s,"height":%s,"refresh":%s,"primary":%s}' \
				"$(json_string "$name")" "$w" "$h" "${hz:-0}" \
				"$(json_bool "$([[ "$pri" == "1" ]] && echo 1 || echo 0)")"
		done
		printf ']'
		return 0
	fi
	if command -v xrandr >/dev/null 2>&1; then
		mapfile -t lines < <(xrandr --query 2>/dev/null | awk '
			/ connected/ {
				name = $1
				primary = ($0 ~ / primary /) ? 1 : 0
				if (match($0, /([0-9]+)x([0-9]+)/, m)) {
					printf "%s %s %s %s %s\n", name, m[1], m[2], 0, primary
				}
			}
		')
		((${#lines[@]})) || return 1
		printf '['
		for line in "${lines[@]}"; do
			read -r name w h hz pri <<< "$line"
			if [[ "$hz" == "0" ]]; then
				hz="$(xrandr --query 2>/dev/null | awk -v out="$name" '
					$1 == out && /\*/ {
						if (match($0, /([0-9]+\.[0-9]+)/, m)) { print int(m[1] + 0.5); exit }
					}
				')"
			fi
			(( first )) || printf ','
			first=0
			printf '{"name":%s,"width":%s,"height":%s,"refresh":%s,"primary":%s}' \
				"$(json_string "$name")" "$w" "$h" "${hz:-0}" \
				"$(json_bool "$pri")"
		done
		printf ']'
		return 0
	fi
	return 1
}

# resolve_gamescope_dimension — Expand "auto" or empty to detected value.
resolve_gamescope_dimension() {
	local current=$1 detected=$2
	if [[ -z "$current" || "$current" == auto ]]; then
		echo "$detected"
	else
		echo "$current"
	fi
}

# apply_auto_hardware_defaults — Fill X3D_CPUS, NIC, and Gamescope dimensions when unset.
apply_auto_hardware_defaults() {
	local w h

	if [[ -z "${GAME_NIC:-}" ]]; then
		GAME_NIC="$(detect_default_nic 2>/dev/null || true)"
		if [[ -z "$GAME_NIC" ]] && command_available ip; then
			GAME_NIC="$( { ip -4 route show default 2>/dev/null || true; } | awk '{print $5; exit}')"
		fi
		export GAME_NIC
	fi

	if [[ -z "${X3D_CPUS:-}" ]]; then
		X3D_CPUS="$(detect_x3d_cpus)"
		export X3D_CPUS
	fi

	if [[ "${GAMESCOPE:-0}" == "1" ]]; then
		read -r w h < <(detect_display_resolution) || true
		GAMESCOPE_W="$(resolve_gamescope_dimension "${GAMESCOPE_W:-}" "$w")"
		GAMESCOPE_H="$(resolve_gamescope_dimension "${GAMESCOPE_H:-}" "$h")"
		export GAMESCOPE_W GAMESCOPE_H
		if [[ -z "${GAMESCOPE_R:-}" || "${GAMESCOPE_R}" == auto ]]; then
			GAMESCOPE_R="$(detect_display_refresh)"
			export GAMESCOPE_R
		fi
		if [[ -z "${GAMESCOPE_ADAPTIVE_SYNC+x}" ]] && detect_vrr_enabled; then
			GAMESCOPE_ADAPTIVE_SYNC=1
			export GAMESCOPE_ADAPTIVE_SYNC
		fi
	fi
}
