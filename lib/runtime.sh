# shellcheck shell=bash
# shellcheck source=common.sh
# shellcheck source=keys.sh
# lib/runtime.sh — Environment tuning and launch-chain assembly.

[[ -n "${LAUNCHLAYER_RUNTIME_LOADED:-}" ]] && return 0
LAUNCHLAYER_RUNTIME_LOADED=1

# run_pre_launch_cmd — Execute PRE_LAUNCH_CMD hook if set.
run_pre_launch_cmd() {
	[[ -n "${PRE_LAUNCH_CMD:-}" ]] || return 0
	debug "PRE_LAUNCH_CMD: $PRE_LAUNCH_CMD"
	eval "$PRE_LAUNCH_CMD"
}

# run_post_launch_cmd — Execute POST_LAUNCH_CMD hook if set.
run_post_launch_cmd() {
	[[ -n "${POST_LAUNCH_CMD:-}" ]] || return 0
	debug "POST_LAUNCH_CMD: $POST_LAUNCH_CMD"
	eval "$POST_LAUNCH_CMD"
}

# for_each_effective_setting — Invoke callback(key, value, source_file) for each summary key.
for_each_effective_setting() {
	local callback=$1 key val source
	[[ "$(type -t "$callback")" == function ]] || return 1
	for key in "${LAUNCHLAYER_SUMMARY_KEYS[@]}"; do
		val="${!key-}"
		[[ -n "$val" ]] || continue
		source="${config_key_sources[$key]:-default}"
		"$callback" "$key" "$val" "$source"
	done
}

# print_effective_config_summary — Show non-default tunables with config layer source.
print_effective_config_summary() {
	_summary_print_line() {
		printf '  %s=%s  (%s)\n' "$1" "$2" "$(config_file_relative "$3")"
	}
	echo "Effective settings:"
	for_each_effective_setting _summary_print_line
}

# print_config_layers — List loaded config files in order.
print_config_layers() {
	local layer
	[[ ${#config_layers[@]} -gt 0 ]] || return 0
	echo "Config layers:"
	for layer in "${config_layers[@]}"; do
		echo "  → $(config_file_relative "$layer")"
	done
	echo
}

# apply_network_tuning — Low-latency NIC settings (requires passwordless sudo).
apply_network_tuning() {
	[[ "${NETWORK_TUNE:-0}" == "1" ]] || return 0
	require_tool_or_skip ethtool "NETWORK_TUNE=1 skipped" || return 0
	sudo -n true 2>/dev/null || {
		warn "NETWORK_TUNE=1 skipped: sudo requires a password"
		return 0
	}
	local nic="${GAME_NIC:-}"
	[[ -n "$nic" ]] || nic="$(detect_default_nic 2>/dev/null || true)"
	[[ -n "$nic" ]] || {
		warn "NETWORK_TUNE=1 skipped: no default NIC detected"
		return 0
	}
	if ! command_available ip; then
		warn "NETWORK_TUNE=1 skipped: ip is not installed$(tool_warn_suffix ip)"
		return 0
	fi
	ip link show "$nic" >/dev/null 2>&1 || {
		warn "NETWORK_TUNE=1 skipped: NIC '$nic' not found"
		return 0
	}
	local max_rx=256 max_tx=256 ethtool_out
	if ethtool_out=$(ethtool -g "$nic" 2>/dev/null); then
		max_rx=$(printf '%s\n' "$ethtool_out" | awk '/^RX:/{print $2; exit}')
		max_tx=$(printf '%s\n' "$ethtool_out" | awk '/^TX:/{print $2; exit}')
	fi
	sudo -n ip link set "$nic" up 2>/dev/null || true
	sudo -n ethtool -G "$nic" rx "$max_rx" tx "$max_tx" 2>/dev/null || true
	sudo -n sysctl -w net.ipv4.tcp_low_latency=1 >/dev/null 2>&1 || true
	sudo -n ethtool -C "$nic" adaptive-rx off adaptive-tx off 2>/dev/null || true
	sudo -n ethtool -C "$nic" rx-usecs 0 rx-frames 1 2>/dev/null || true
	debug "network tuning applied on $nic"
}

# apply_pipewire_low_latency — Tighten audio buffer/quantum for lower latency.
apply_pipewire_low_latency() {
	[[ "${PIPEWIRE_LOW_LATENCY:-0}" == "1" ]] || return 0
	local audio
	audio="$(detect_audio_server)"
	case "$audio" in
		pipewire)
			export PULSE_LATENCY_MSEC=30
			if optional_tool_installed pw-metadata; then
				pw-metadata -n settings 0 clock.force-quantum 512 2>/dev/null || true
			else
				debug "PIPEWIRE_LOW_LATENCY: pw-metadata unavailable — using PULSE_LATENCY_MSEC only"
			fi
			debug "pipewire low-latency mode enabled"
			;;
		pulse)
			export PULSE_LATENCY_MSEC=30
			debug "pulseaudio low-latency mode enabled (PULSE_LATENCY_MSEC=30)"
			;;
		*)
			debug "PIPEWIRE_LOW_LATENCY skipped: audio server is ${audio:-unknown}"
			;;
	esac
}

# restore_pipewire_low_latency — Reset PipeWire quantum on launch exit.
restore_pipewire_low_latency() {
	[[ "${PIPEWIRE_LOW_LATENCY:-0}" == "1" ]] || return 0
	[[ "$(detect_audio_server)" == pipewire ]] || return 0
	if optional_tool_installed pw-metadata; then
		pw-metadata -n settings 0 clock.force-quantum 0 2>/dev/null || true
	fi
}

# apply_cpu_performance — Fallback when game-performance wrapper is absent.
apply_cpu_performance() {
	[[ "${GAME_PERFORMANCE:-1}" == "1" ]] || return 0
	command_available game-performance && return 0
	if command_available cpupower && sudo -n true 2>/dev/null; then
		sudo -n cpupower frequency-set -g performance >/dev/null 2>&1 \
			&& debug "cpupower performance (fallback)" && return 0
	fi
	if command_available powerprofilesctl; then
		powerprofilesctl set performance >/dev/null 2>&1 \
			&& debug "powerprofilesctl performance (fallback)" && return 0
	fi
	debug "GAME_PERFORMANCE=1: no game-performance/cpupower/powerprofilesctl — continuing without CPU perf tuning"
}

# apply_unset_vars — Remove env vars listed in UNSET_VARS (space-separated).
apply_unset_vars() {
	local var
	[[ -n "${UNSET_VARS:-}" ]] || return 0
	for var in ${UNSET_VARS}; do
		unset "$var" 2>/dev/null || true
		debug "unset $var"
	done
}

# apply_anticheat_guardrails — Conservative defaults for EAC/BattlEye titles.
apply_anticheat_guardrails() {
	# shellcheck disable=SC2154  # is_anticheat set by resolve_game_flags
	[[ "$is_anticheat" == "1" ]] || return 0
	[[ "${DEBUG:-0}" == "1" ]] && warn "DEBUG=1 with EAC title may cause launch failures"
	export PROTON_LOG="${PROTON_LOG:-0}"
	if [[ -n "${DXVK_ASYNC+x}" && "${DXVK_ASYNC:-}" == "1" ]]; then
		warn "DXVK_ASYNC=1 on EAC title — unset via UNSET_VARS if unstable"
	fi
}

# apply_proton_env — Export Proton/DXVK/VKD3D/NVIDIA tuning variables.
#
# Skipped entirely for native games unless FORCE_PROTON=1.
# BENCHMARK=1 uses a stripped profile (no MangoHUD, no VRR).
apply_proton_env() {
	# shellcheck disable=SC2154  # is_native set by resolve_game_flags
	[[ "$is_native" == "1" && "${FORCE_PROTON:-0}" != "1" ]] && {
		debug "skipping Proton env (native game)"
		return 0
	}

	export PROTON_ENABLE_WAYLAND=${PROTON_ENABLE_WAYLAND:-1}
	export PROTON_USE_NTSYNC=${PROTON_USE_NTSYNC:-1}
	export PROTON_HIDE_NVIDIA_GPU=${PROTON_HIDE_NVIDIA_GPU:-0}
	export PROTON_ENABLE_NVAPI=${PROTON_ENABLE_NVAPI:-1}
	export PROTON_NO_ESYNC=${PROTON_NO_ESYNC:-0}
	export PROTON_NO_FSYNC=${PROTON_NO_FSYNC:-0}
	export PROTON_BYPASS_WINMENUBUILDER=${PROTON_BYPASS_WINMENUBUILDER:-1}
	export PROTON_LOG=${PROTON_LOG:-0}

	export __GL_THREADED_OPTIMIZATIONS=${__GL_THREADED_OPTIMIZATIONS:-1}
	export __GL_YIELD=${__GL_YIELD:-USLEEP}
	export __GL_MaxFramesAllowed=${__GL_MaxFramesAllowed:-1}
	export __GL_SYNC_TO_VBLANK=${__GL_SYNC_TO_VBLANK:-0}
	export __GL_SHADER_DISK_CACHE=${__GL_SHADER_DISK_CACHE:-1}
	export __VK_LAYER_NV_optimus=${__VK_LAYER_NV_optimus:-NVIDIA_only}
	export VKD3D_FEATURE_LEVEL=${VKD3D_FEATURE_LEVEL:-12_2}
	export DXVK_HUD=${DXVK_HUD:-0}

	if [[ "${DEBUG:-0}" == "1" ]]; then
		export PROTON_LOG=1
		export PROTON_LOG_DIR="${PROTON_LOG_DIR:-$HOME/steam-proton-logs}"
		mkdir -p "$PROTON_LOG_DIR"
	fi

	if [[ "${BENCHMARK:-0}" == "1" ]]; then
		unset MANGOHUD MANGOHUD_CONFIG MANGOHUD_LOG
		export DXVK_ASYNC=${DXVK_ASYNC:-1}
		export __GL_GSYNC_ALLOWED=${__GL_GSYNC_ALLOWED:-0}
		export __GL_VRR_ALLOWED=${__GL_VRR_ALLOWED:-0}
		apply_unset_vars
		return 0
	fi

	export __GL_GSYNC_ALLOWED=${__GL_GSYNC_ALLOWED:-1}
	export __GL_VRR_ALLOWED=${__GL_VRR_ALLOWED:-1}
	export DXVK_ASYNC=${DXVK_ASYNC:-1}
	apply_unset_vars

	if [[ "${MANGOHUD_LOG:-0}" == "1" ]]; then
		export MANGOHUD_LOG=1
	fi
}

# warn_missing_tools — Surface missing optional dependencies before launch fails.
warn_missing_tools() {
	warn_enabled_missing_tools
}

# append_launch_wrappers_from — Append installed binaries from a wrapper list to launch[].
append_launch_wrappers_from() {
	local wrappers=$1 wrapper
	for wrapper in $wrappers; do
		if command_available "$wrapper"; then
			launch+=("$wrapper")
		else
			debug "launch wrapper skipped (not installed): $wrapper"
		fi
	done
}

# append_launch_wrappers — Prepend LAUNCH_WRAPPERS_BEFORE binaries to the chain.
append_launch_wrappers() {
	append_launch_wrappers_from "${LAUNCH_WRAPPERS_BEFORE}"
}

# append_launch_wrappers_after_performance — Append LAUNCH_WRAPPERS after game-performance.
append_launch_wrappers_after_performance() {
	append_launch_wrappers_from "${LAUNCH_WRAPPERS}"
}

# parse_game_extra_args — Split GAME_EXTRA_ARGS into game_extra_argv[].
parse_game_extra_args() {
	game_extra_argv=()
	[[ -n "${GAME_EXTRA_ARGS:-}" ]] || return 0
	local arg
	read -r -a game_extra_argv <<< "$GAME_EXTRA_ARGS"
	for arg in "${game_extra_argv[@]}"; do
		debug "extra arg: $arg"
	done
}

# build_launch_chain — Assemble the wrapper prefix executed before Steam's %command%.
#
# Typical chain:
#   [wrappers_before] → gamemoderun → taskset → game-performance
#   → [wrappers] → [gamescope --mangoapp] → [mangohud]
build_launch_chain() {
	local use_mangoapp=0

	launch=( )
	append_launch_wrappers

	if [[ "${GAMEMODE:-1}" == "1" ]] && optional_tool_installed gamemoderun; then
		launch+=(gamemoderun)
	elif [[ "${GAMEMODE:-1}" == "1" ]]; then
		debug "gamemoderun unavailable — continuing without GameMode wrapper"
	fi

	if [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]] && optional_tool_installed taskset; then
		launch+=(taskset -c "${X3D_CPUS:-$(default_online_cpus)}")
	elif [[ "${DISABLE_CPU_AFFINITY:-0}" != "1" ]]; then
		debug "taskset unavailable — continuing without CPU affinity wrapper"
	fi
	if [[ "${GAME_PERFORMANCE:-1}" == "1" ]] && command_available game-performance; then
		launch+=(game-performance)
	fi
	append_launch_wrappers_after_performance

	if [[ "${GAMESCOPE:-0}" == "1" && "$is_native" == "1" && "${FORCE_PROTON:-0}" != "1" ]]; then
		warn "GAMESCOPE=1 on native game — set FORCE_PROTON=1 if intentional"
	fi

	if [[ "${GAMESCOPE:-0}" == "1" ]] && optional_tool_installed gamescope; then
		launch+=(gamescope)
		launch+=(-W "${GAMESCOPE_W}" -H "${GAMESCOPE_H}" -r "${GAMESCOPE_R:-120}")
		launch+=(-f --force-grab-cursor)
		[[ "${GAMESCOPE_ADAPTIVE_SYNC:-0}" == "1" ]] && launch+=(--adaptive-sync)
		[[ "${GAMESCOPE_EXPOSE_WAYLAND:-0}" == "1" ]] && launch+=(--expose-wayland)
		[[ "${GAMESCOPE_FSR:-0}" == "1" ]] && launch+=(--fsr-sharpness "${GAMESCOPE_FSR_SHARPNESS:-5}")
		# --mangoapp integrates MangoHUD inside gamescope (avoids double-wrapping).
		if [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" ]]; then
			launch+=(--mangoapp)
			use_mangoapp=1
		fi
		launch+=(--)
	elif [[ "${GAMESCOPE:-0}" == "1" ]]; then
		debug "gamescope unavailable — continuing without Gamescope wrapper"
	fi

	if [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" && "$use_mangoapp" != "1" ]] \
		&& optional_tool_installed mangohud; then
		launch+=(mangohud)
	elif [[ "${BENCHMARK:-0}" != "1" && "${MANGOHUD:-0}" == "1" && "$use_mangoapp" != "1" ]]; then
		debug "mangohud unavailable — continuing without MangoHUD wrapper"
	fi

	debug "launch chain: ${launch[*]}"
}

# rotate_launch_log — Trim launch.log to LAUNCH_LOG_MAX_LINES.
rotate_launch_log() {
	local max_lines=${LAUNCH_LOG_MAX_LINES:-5000}
	[[ -f "$LAUNCH_LOG_FILE" ]] || return 0
	[[ "$max_lines" =~ ^[0-9]+$ && "$max_lines" -gt 0 ]] || return 0
	local count
	count="$(wc -l < "$LAUNCH_LOG_FILE")"
	if (( count > max_lines )); then
		tail -n "$max_lines" "$LAUNCH_LOG_FILE" > "${LAUNCH_LOG_FILE}.tmp"
		mv "${LAUNCH_LOG_FILE}.tmp" "$LAUNCH_LOG_FILE"
	fi
}

# log_launch_event — Append a structured line to launch.log.
log_launch_event() {
	local exit_code=${1:-} duration=${2:-0}
	mkdir -p "$STATE_DIR"
	rotate_launch_log
	printf '%s appid=%s name=%q native=%s eac=%s benchmark=%s gamescope=%s vram_hogs=%s mangohud=%s x3d_cpus=%s duration=%ss exit=%s\n' \
		"$(timestamp_iso)" \
		"${steam_app_id:-unknown}" \
		"${steam_game_name:-unknown}" \
		"$is_native" \
		"$is_anticheat" \
		"${BENCHMARK:-0}" \
		"${GAMESCOPE:-0}" \
		"${VRAM_HOGS:-0}" \
		"${MANGOHUD:-0}" \
		"${X3D_CPUS:-$(default_online_cpus)}" \
		"$duration" \
		"${exit_code:-}" \
		>> "$LAUNCH_LOG_FILE"
}

# print_dry_run — Show resolved env and launch chain without executing.
print_dry_run() {
	echo "=== launchlayer dry run ==="
	echo "appid=${steam_app_id:-unknown} name=${steam_game_name:-unknown} native=$is_native eac=$is_anticheat"
	echo
	print_config_layers
	print_effective_config_summary
	echo
	echo "Environment (selected):"
	env | grep -E '^(PROTON_|DXVK_|VKD3D_|__GL_|__VK_|MANGOHUD|GAMESCOPE_)' | sort || true
	echo
	echo "Launch chain:"
	printf '  %q' "${launch[@]}" "$@" "${game_extra_argv[@]}"
	echo
}
