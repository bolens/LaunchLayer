# shellcheck shell=bash
# lib/runtime/tuning.sh — Network, audio, CPU, Proton, and anticheat env tuning.

[[ -n "${LAUNCHLAYER_RUNTIME_TUNING_LOADED:-}" ]] && return 0
LAUNCHLAYER_RUNTIME_TUNING_LOADED=1

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
