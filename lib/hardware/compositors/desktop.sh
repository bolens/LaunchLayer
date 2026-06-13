# shellcheck shell=bash
# lib/hardware/compositors/desktop.sh

[[ -n "${LAUNCHLAYER_COMPOSITORS_DESKTOP_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMPOSITORS_DESKTOP_LOADED=1

# detect_xrandr_active_output — Primary or first connected output via xrandr (X11).
detect_xrandr_active_output() {
	command -v xrandr >/dev/null 2>&1 || return 1
	xrandr --query 2>/dev/null | awk '/ primary / {print $1; exit}
		/ connected/ && !seen {print $1; seen=1; exit}' || true
}

# detect_xrandr_display_mode — Width, height, refresh, and name via xrandr (X11).
detect_xrandr_display_mode() {
	local output w h rate
	command -v xrandr >/dev/null 2>&1 || return 1
	output="$(detect_xrandr_active_output 2>/dev/null || true)"
	[[ -n "$output" ]] || return 1
	read -r w h rate < <(xrandr --query 2>/dev/null | awk -v out="$output" '
		$1 == out && /connected/ {
			if (match($0, /([0-9]+)x([0-9]+)\+/, m)) { w=m[1]; h=m[2] }
			in_modes=1
			next
		}
		in_modes && /^\s/ {
			if (/\*/ && match($0, /([0-9]+)x([0-9]+)/, m2)) { w=m2[1]; h=m2[2] }
			if (/\*/ && match($0, /([0-9]+\.?[0-9]*)\*/, r)) {
				rate=int(r[1] + 0.5)
				exit
			}
		}
		END {
			if (w != "") printf "%s %s %s\n", w, h, rate
		}') || true
	[[ -n "$w" && -n "$h" ]] && printf '%s\n' "$w $h ${rate:-} $output"
}

# detect_darwin_display_mode — Best-effort resolution via system_profiler (macOS).
detect_darwin_display_mode() {
	is_darwin || return 1
	command -v system_profiler >/dev/null 2>&1 || return 1
	system_profiler SPDisplaysDataType 2>/dev/null | awk '
		/Resolution:/ {
			if (match($0, /([0-9]+) x ([0-9]+)/, m)) {
				printf "%s %s\n", m[1], m[2]
				exit
			}
		}'
}

# detect_gnome_vrr_enabled — True when Mutter VRR policy is enabled (GNOME 43+).
detect_gnome_vrr_enabled() {
	local vrr features
	command -v gsettings >/dev/null 2>&1 || return 1
	vrr="$(gsettings get org.gnome.mutter display-config.vrr-policy 2>/dev/null || true)"
	case "$vrr" in
		*always*|*on-demand*) return 0 ;;
	esac
	features="$(gsettings get org.gnome.mutter experimental-features 2>/dev/null || true)"
	[[ "$features" == *variable-refresh-rate* ]] && return 0
	return 1
}

# detect_gnome_primary_output — Primary monitor via Mutter DBus (best effort).
detect_gnome_primary_output() {
	command -v gdbus >/dev/null 2>&1 || return 1
	gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
		--object-path /org/gnome/Mutter/DisplayConfig \
		--method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
		| grep -oE "'[^']+'" | head -1 | tr -d "'" || true
}

# detect_gnome_display_mode — Width, height, refresh from Mutter DBus (best effort).
detect_gnome_display_mode() {
	local raw w h rate
	command -v gdbus >/dev/null 2>&1 || return 1
	raw="$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
		--object-path /org/gnome/Mutter/DisplayConfig \
		--method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null || true)"
	[[ -n "$raw" ]] || return 1
	w="$(printf '%s' "$raw" | grep -oE '[0-9]{3,5}, [0-9]{3,5}' | head -1 | cut -d, -f1 | tr -d ' ')"
	h="$(printf '%s' "$raw" | grep -oE '[0-9]{3,5}, [0-9]{3,5}' | head -1 | cut -d, -f2 | tr -d ' ')"
	rate="$(printf '%s' "$raw" | grep -oE '[0-9]{2,3}\.[0-9]+' | head -1)"
	[[ -n "$w" && -n "$h" ]] || return 1
	rate="${rate%%.*}"
	printf '%s %s %s\n' "$w" "$h" "${rate:-}"
}

# detect_kwin_primary_output — KDE primary output (kscreen priority 1, else lowest priority).
detect_kwin_primary_output() {
	local name=""
	name="$(parse_kscreen_doctor_outputs 2>/dev/null | awk '$2 == 1 { print $1; exit }')" || true
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(parse_kscreen_doctor_outputs 2>/dev/null | awk '
		NF >= 2 {
			pri = $2 + 0
			if (best_pri == "" || pri < best_pri) {
				best_pri = pri
				best_name = $1
			}
		}
		END { if (best_name != "") print best_name }
	')" || true
	[[ -n "$name" ]] && echo "$name"
}

# kscreen_doctor_plain — kscreen-doctor output with ANSI color stripped.
kscreen_doctor_plain() {
	command -v kscreen-doctor >/dev/null 2>&1 || return 1
	kscreen-doctor -o 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g'
}

# parse_kscreen_doctor_outputs — One line per output: "name priority width height refresh".
parse_kscreen_doctor_outputs() {
	kscreen_doctor_plain | awk '
		function flush() {
			if (name != "" && w != "" && h != "") {
				printf "%s %s %s %s %s\n", name, priority, w, h, (hz == "" ? 0 : hz)
			}
		}
		/^Output:/ {
			flush()
			name = $3
			priority = 999
			w = h = hz = ""
			next
		}
		/priority/ {
			if (match($0, /priority[[:space:]]+[0-9]+/)) {
				s = substr($0, RSTART, RLENGTH)
				sub(/^priority[[:space:]]+/, "", s)
				priority = s + 0
			}
			next
		}
		/Geometry:/ {
			if (match($0, /[0-9]+x[0-9]+[[:space:]]*$/)) {
				s = substr($0, RSTART, RLENGTH)
				split(s, parts, "x")
				w = parts[1]
				sub(/[[:space:]]+$/, "", parts[2])
				h = parts[2]
			}
			next
		}
		/Modes:/ && /\*/ {
			line = $0
			while (match(line, /[0-9]+x[0-9]+@[0-9.]+/)) {
				s = substr(line, RSTART, RLENGTH)
				rest = substr(line, RSTART + RLENGTH, 1)
				if (rest == "*") {
					n = split(s, parts, /[@x]/)
					if (n >= 3) {
						hz = int(parts[3] + 0.5)
					}
					break
				}
				line = substr(line, RSTART + RLENGTH)
			}
			next
		}
		END { flush() }
	'
}

# detect_kwin_display_mode — Width, height, refresh via kscreen-doctor (primary/active output).
detect_kwin_display_mode() {
	local want="" name w h rate
	want="$(detect_kwin_primary_output 2>/dev/null || true)"
	[[ -n "$want" ]] || want="$(detect_kwin_active_output 2>/dev/null || true)"
	if [[ -n "$want" ]]; then
		read -r w h rate name < <(parse_kscreen_doctor_outputs 2>/dev/null | awk -v want="$want" '
			$1 == want && NF >= 5 { printf "%s %s %s %s\n", $3, $4, $5, $1; exit }
		') || true
		if [[ -n "$w" && -n "$h" ]]; then
			printf '%s %s %s %s\n' "$w" "$h" "${rate:-}" "${name:-$want}"
			return 0
		fi
		read -r w h rate < <(parse_wlr_randr_output "$want" 2>/dev/null || true) || true
		if [[ -n "$w" && -n "$h" ]]; then
			printf '%s %s %s %s\n' "$w" "$h" "${rate:-}" "$want"
			return 0
		fi
	fi
	return 1
}

# detect_compositor_display_mode — Session-aware width height refresh output_name.
detect_compositor_display_mode() {
	local desktop mode="" output
	desktop="$(detect_desktop_session)"
	case "$desktop" in
		hyprland)
			compositor_session_active hyprland \
				&& mode="$(detect_hyprland_display_mode 2>/dev/null || true)"
			;;
		sway)
			compositor_session_active sway \
				&& mode="$(detect_sway_display_mode 2>/dev/null || true)"
			;;
		niri)
			compositor_session_active niri \
				&& mode="$(detect_niri_display_mode 2>/dev/null || true)"
			;;
		river)
			compositor_session_active river \
				&& mode="$(detect_river_display_mode 2>/dev/null || true)"
			;;
		kde) mode="$(detect_kwin_display_mode 2>/dev/null || true)" ;;
		gnome|cosmic|budgie|pantheon|deepin)
			mode="$(detect_gnome_display_mode 2>/dev/null || true)"
			;;
		labwc|wayfire|weston|miracle)
			output="$(detect_wlr_active_output 2>/dev/null || true)"
			[[ -n "$output" ]] && mode="$(parse_wlr_randr_output "$output" 2>/dev/null || true)"
			[[ -n "$mode" && -n "$output" ]] && mode="$mode $output"
			;;
		xfce|mate|cinnamon|lxqt|enlightenment|i3|awesome|openbox|bspwm|qtile)
			mode="$(detect_xrandr_display_mode 2>/dev/null || true)"
			;;
	esac
	[[ -n "$mode" ]] && printf '%s\n' "$mode"
}
