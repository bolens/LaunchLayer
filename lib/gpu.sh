# shellcheck shell=bash
# shellcheck source=common.sh
# lib/gpu.sh — NVIDIA PowerMizer apply/restore for gaming sessions.

[[ -n "${LAUNCHLAYER_GPU_LOADED:-}" ]] && return 0
LAUNCHLAYER_GPU_LOADED=1

NVIDIA_POWER_STATE_FILE="$STATE_DIR/nvidia-power-mizer.saved"

# apply_nvidia_power_mode — Prefer max performance while a game runs.
apply_nvidia_power_mode() {
	local current=""
	[[ "${NVIDIA_POWER_MODE:-0}" == "1" ]] || return 0
	[[ "$(detect_gpu_vendor)" == nvidia ]] || return 0
	optional_tool_installed nvidia-settings || return 0

	current="$( { nvidia-settings -q GPUPowerMizerMode -t 2>/dev/null || true; } | head -1 | tr -d ' ')"
	[[ "$current" =~ ^[0-2]$ ]] || {
		warn "could not read GPUPowerMizerMode"
		return 0
	}

	mkdir -p "$STATE_DIR"
	echo "$current" > "$NVIDIA_POWER_STATE_FILE"

	if [[ "$current" == "1" ]]; then
		debug "nvidia power mode already maximum performance"
		return 0
	fi

	if nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1; then
		debug "nvidia power mode set to Prefer Maximum Performance (was $current)"
	else
		warn "failed to set nvidia Prefer Maximum Performance"
	fi
}

# restore_nvidia_power_mode — Restore saved PowerMizer mode after launch exit.
restore_nvidia_power_mode() {
	local saved=""
	[[ -f "$NVIDIA_POWER_STATE_FILE" ]] || return 0
	[[ "$(detect_gpu_vendor)" == nvidia ]] || return 0
	command -v nvidia-settings >/dev/null 2>&1 || return 0

	saved="$(<"$NVIDIA_POWER_STATE_FILE")"
	rm -f "$NVIDIA_POWER_STATE_FILE"
	[[ "$saved" =~ ^[0-2]$ ]] || return 0

	nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=$saved" >/dev/null 2>&1 \
		&& debug "nvidia power mode restored to $saved" \
		|| warn "failed to restore nvidia power mode $saved"
}
