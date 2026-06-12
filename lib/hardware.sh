# shellcheck shell=bash
# shellcheck source=common.sh
# lib/hardware.sh — CPU topology and display auto-detection for this machine.

[[ -n "${LAUNCHLAYER_HARDWARE_LOADED:-}" ]] && return 0
LAUNCHLAYER_HARDWARE_LOADED=1

# format_taskset_cpus — Collapse a sorted CPU list into taskset ranges (e.g. 0-7,16-23).
format_taskset_cpus() {
	local -a cpus=()
	local cpu start prev
	local -a ranges=()

	for cpu in "$@"; do
		[[ "$cpu" =~ ^[0-9]+$ ]] && cpus+=("$cpu")
	done
	[[ ${#cpus[@]} -gt 0 ]] || { default_online_cpus; return; }

	mapfile -t cpus < <(printf '%s\n' "${cpus[@]}" | sort -n)
	start=${cpus[0]}
	prev=$start

	for cpu in "${cpus[@]:1}"; do
		if (( cpu == prev + 1 )); then
			prev=$cpu
			continue
		fi
		if (( start == prev )); then ranges+=("$start"); else ranges+=("$start-$prev"); fi
		start=$cpu
		prev=$cpu
	done
	if (( start == prev )); then ranges+=("$start"); else ranges+=("$start-$prev"); fi
	IFS=','; echo "${ranges[*]}"
}

# compute_x3d_cpus — Scan sysfs for the L3 CCD with the largest cache.
compute_x3d_cpus() {
	local cpu cache max_cache
	local -a cpus=()

	max_cache=0
	for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
		[[ -f "$cpu/cache/index3/size" ]] || continue
		cache="$(<"$cpu/cache/index3/size")"
		cache="${cache%K}"
		[[ "$cache" =~ ^[0-9]+$ ]] || continue
		(( cache > max_cache )) && max_cache=$cache
	done

	if (( max_cache == 0 )); then
		default_online_cpus
		return 0
	fi

	for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
		[[ -f "$cpu/cache/index3/size" ]] || continue
		cache="$(<"$cpu/cache/index3/size")"
		cache="${cache%K}"
		[[ "$cache" == "$max_cache" ]] || continue
		cpus+=("${cpu##*cpu}")
	done

	if [[ ${#cpus[@]} -eq 0 ]]; then
		default_online_cpus
		return 0
	fi

	format_taskset_cpus "${cpus[@]}"
}

# read_max_l3_cache_kb — Return largest L3 cache size (KB) seen on this host.
read_max_l3_cache_kb() {
	local cpu cache max_cache=0
	for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
		[[ -f "$cpu/cache/index3/size" ]] || continue
		cache="$(<"$cpu/cache/index3/size")"
		cache="${cache%K}"
		[[ "$cache" =~ ^[0-9]+$ ]] || continue
		(( cache > max_cache )) && max_cache=$cache
	done
	echo "$max_cache"
}

# detect_x3d_cpus — V-Cache CCD range with stale-cache invalidation.
detect_x3d_cpus() {
	local result max_l3 cpu_count cached_l3 cached_count stale=0

	max_l3="$(read_max_l3_cache_kb)"
	cpu_count="$(nproc 2>/dev/null || echo 0)"

	if [[ -f "$X3D_CPUS_CACHE_FILE" && -f "$X3D_CPUS_META_FILE" ]]; then
		read -r cached_l3 cached_count < "$X3D_CPUS_META_FILE" 2>/dev/null || stale=1
		if [[ "$cached_l3" != "$max_l3" || "$cached_count" != "$cpu_count" ]]; then
			stale=1
		fi
		if (( stale == 0 )); then
			cat "$X3D_CPUS_CACHE_FILE"
			return 0
		fi
		debug "x3d cpu cache stale — refreshing"
	fi

	result="$(compute_x3d_cpus)"
	mkdir -p "$STATE_DIR"
	printf '%s\n' "$result" > "$X3D_CPUS_CACHE_FILE"
	printf '%s %s\n' "$max_l3" "$cpu_count" > "$X3D_CPUS_META_FILE"
	echo "$result"
}

# detect_default_nic — Interface used for the default IPv4 route.
detect_default_nic() {
	ip -4 route show default 2>/dev/null | awk '{print $5; exit}'
}

# detect_hyprland_active_output — Focused monitor name via hyprctl.
detect_hyprland_active_output() {
	command -v hyprctl >/dev/null 2>&1 || return 1
	hyprctl monitors -j 2>/dev/null \
		| awk -F'"' '/"focused":true/ {for(i=1;i<=NF;i++) if($i=="name") {print $(i+2); exit}}' \
		|| true
}

# detect_sway_active_output — Focused output name via swaymsg.
detect_sway_active_output() {
	command -v swaymsg >/dev/null 2>&1 || return 1
	swaymsg -t get_outputs 2>/dev/null \
		| awk -F'"' '/"focused":true/ {for(i=1;i<=NF;i++) if($i=="name") {print $(i+2); exit}}' \
		|| true
}

# detect_gnome_primary_output — Primary monitor via Mutter DBus (best effort).
detect_gnome_primary_output() {
	command -v gdbus >/dev/null 2>&1 || return 1
	gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
		--object-path /org/gnome/Mutter/DisplayConfig \
		--method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
		| grep -oE "'[^']+'" | head -1 | tr -d "'" || true
}

# detect_active_output — Best-effort focused/primary output name.
detect_active_output() {
	local name=""
	name="$(detect_kwin_active_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_hyprland_active_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_sway_active_output)"
	[[ -n "$name" ]] && { echo "$name"; return 0; }
	name="$(detect_gnome_primary_output)"
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

# detect_kwin_active_output — Primary/focused output name via KDE KWin (Plasma 6).
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
	local w="" h="" output=""

	if is_steam_deck; then
		: "${w:=1280}"
		: "${h:=800}"
		echo "$w $h"
		return 0
	fi

	output="$(detect_active_output)"
	if [[ -n "$output" ]]; then
		read -r w h _ < <(parse_wlr_randr_output "$output" 2>/dev/null || true) || true
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
		read -r w h < <(xrandr --query 2>/dev/null | awk '/ connected/ {
			if (match($0, /([0-9]+)x([0-9]+)/, m)) { print m[1], m[2]; exit }
		}') || true
	fi

	: "${w:=3440}"
	: "${h:=1440}"
	echo "$w $h"
}

# detect_display_refresh — Refresh rate in Hz for the active or primary display.
detect_display_refresh() {
	local rate="" output=""

	if is_steam_deck; then
		echo 60
		return 0
	fi

	output="$(detect_active_output)"
	if [[ -n "$output" ]]; then
		read -r _ _ rate < <(parse_wlr_randr_output "$output" 2>/dev/null || true) || true
	fi

	if [[ -z "$rate" ]] && command -v wlr-randr >/dev/null 2>&1; then
		rate="$(wlr-randr 2>/dev/null | awk '/current/ {
			if (match($0, /([0-9.]+)[[:space:]]*Hz/, m)) { print m[1]; exit }
		}')"
	fi
	if [[ -z "$rate" ]] && command -v xrandr >/dev/null 2>&1; then
		rate="$(xrandr --query 2>/dev/null | awk '/ connected/ {print $4; exit}' || true)"
		rate="$(printf '%s' "$rate" | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
	fi
	[[ -n "$rate" ]] && rate="${rate%%.*}"
	: "${rate:=120}"
	echo "$rate"
}

# detect_vrr_enabled — Best-effort VRR/G-Sync availability check.
detect_vrr_enabled() {
	local vendor
	vendor="$(detect_gpu_vendor)"
	if [[ "$vendor" == nvidia ]] && command -v nvidia-settings >/dev/null 2>&1; then
		local vrr
		vrr="$(nvidia-settings -q AllowVRR -t 2>/dev/null | head -1 | tr -d ' ')"
		[[ "$vrr" == "1" ]] && return 0
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
		[[ -n "$GAME_NIC" ]] || GAME_NIC="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"
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
