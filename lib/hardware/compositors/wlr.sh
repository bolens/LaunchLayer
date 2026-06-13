# shellcheck shell=bash
# lib/hardware/compositors/wlr.sh

[[ -n "${LAUNCHLAYER_COMPOSITORS_WLR_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMPOSITORS_WLR_LOADED=1

# detect_hyprland_active_output — Focused monitor name via hyprctl.
detect_hyprland_active_output() {
	command -v hyprctl >/dev/null 2>&1 || return 1
	hyprctl monitors -j 2>/dev/null \
		| awk -F'"' '/"focused":true/ {for(i=1;i<=NF;i++) if($i=="name") {print $(i+2); exit}}' \
		|| true
}

# detect_hyprland_display_mode — Width, height, refresh, and name via hyprctl.
detect_hyprland_display_mode() {
	command -v hyprctl >/dev/null 2>&1 || return 1
	hyprctl monitors -j 2>/dev/null | parse_json_focused_monitor
}

# detect_sway_active_output — Focused output name via swaymsg.
detect_sway_active_output() {
	command -v swaymsg >/dev/null 2>&1 || return 1
	swaymsg -t get_outputs 2>/dev/null \
		| awk -F'"' '/"focused":true/ {for(i=1;i<=NF;i++) if($i=="name") {print $(i+2); exit}}' \
		|| true
}

# detect_sway_display_mode — Width, height, refresh, and name via swaymsg.
detect_sway_display_mode() {
	command -v swaymsg >/dev/null 2>&1 || return 1
	swaymsg -t get_outputs 2>/dev/null | parse_json_focused_monitor
}

# detect_niri_active_output — Focused output name via niri msg.
detect_niri_active_output() {
	command -v niri >/dev/null 2>&1 || return 1
	niri msg -j outputs 2>/dev/null \
		| awk -F'"' '/"is_focused":true/ {for(i=1;i<=NF;i++) if($i=="name") {print $(i+2); exit}}' \
		|| true
}

# detect_niri_display_mode — Width, height, refresh, and name via niri msg.
detect_niri_display_mode() {
	command -v niri >/dev/null 2>&1 || return 1
	niri msg -j outputs 2>/dev/null | parse_json_focused_monitor
}

# detect_river_active_output — Focused monitor name via riverctl.
detect_river_active_output() {
	command -v riverctl >/dev/null 2>&1 || return 1
	riverctl monitors 2>/dev/null \
		| awk '/^Monitor: / {mon=$2} /Focused: yes/ {print mon; exit}' \
		|| true
}

# detect_river_display_mode — Width, height, refresh, and name via riverctl.
detect_river_display_mode() {
	command -v riverctl >/dev/null 2>&1 || return 1
	riverctl monitors 2>/dev/null | awk '
		/^Monitor: / {mon=$2; mode_w=mode_h=mode_rate=""}
		/Mode:/ && match($0, /([0-9]+)x([0-9]+)@([0-9.]+)Hz/, m) {
			mode_w=m[1]; mode_h=m[2]; mode_rate=int(m[3])
		}
		/Focused:/ && /yes/ && mode_w != "" {
			printf "%s %s %s %s\n", mode_w, mode_h, mode_rate, mon
			exit
		}'
}

# detect_wlr_active_output — First output with a current mode from wlr-randr.
detect_wlr_active_output() {
	command -v wlr-randr >/dev/null 2>&1 || return 1
	wlr-randr 2>/dev/null | awk '/ current / {print $1; exit}' || true
}
