#!/usr/bin/env bash
# Unit tests for lib/gpu.sh NVIDIA power helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "apply_nvidia_power_mode is no-op when disabled" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		NVIDIA_POWER_MODE=0 \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib gpu platform
			apply_nvidia_power_mode
			[[ -f "$NVIDIA_POWER_STATE_FILE" ]] && echo saved || echo none
		'
	[[ $status -eq 0 ]]
	[[ "$output" == none ]]
	rm -rf "$tmp"
}

@test "apply_nvidia_power_mode saves and sets performance mode" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			export NVIDIA_POWER_MODE=1
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib gpu platform
			detect_gpu_vendor() { echo nvidia; }
			optional_tool_installed() { [[ "$1" == nvidia-settings ]]; }
			nvidia-settings() {
				case "$*" in
					*-q*) echo 0 ;;
					*-a*) return 0 ;;
				esac
			}
			apply_nvidia_power_mode
			[[ -f "$NVIDIA_POWER_STATE_FILE" ]] && cat "$NVIDIA_POWER_STATE_FILE" || echo missing
		'
	[[ $status -eq 0 ]]
	[[ "$output" == "0" ]]
	rm -rf "$tmp"
}

@test "restore_nvidia_power_mode restores saved mode and clears state" {
	local tmp bindir saved
	tmp="$(temp_state_dir)"
	bindir="$tmp/bin"
	saved="$tmp/state/launchlayer/nvidia-power-mizer.saved"
	mkdir -p "$(dirname "$saved")" "$bindir"
	echo 2 > "$saved"
	printf '#!/bin/sh\nexit 0\n' > "$bindir/nvidia-settings"
	chmod +x "$bindir/nvidia-settings"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		PATH="$bindir:$PATH" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib gpu platform
			detect_gpu_vendor() { echo nvidia; }
			restore_nvidia_power_mode
			[[ -f "'"$saved"'" ]] && echo still-there || echo cleared
		'
	[[ $status -eq 0 ]]
	[[ "$output" == cleared ]]
	rm -rf "$tmp"
}
