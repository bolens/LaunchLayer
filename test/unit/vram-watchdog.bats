#!/usr/bin/env bash
# Unit tests for lib/vram.sh launch watchdog and stale-session guards.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "stop_launch_watchdog kills tracked pid and removes pid file" {
	local tmp pid_file fake_pid
	tmp="$(temp_state_dir)"
	pid_file="$tmp/state/launchlayer/launch-watchdog.pid"
	mkdir -p "$(dirname "$pid_file")"
	fake_pid=424242
	echo "$fake_pid" > "$pid_file"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			kill() { printf "kill:%s\n" "$1"; return 0; }
			stop_launch_watchdog
			[[ -f "$WATCHDOG_PID_FILE" ]] && echo file:present || echo file:absent
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"kill:$fake_pid"* ]]
	[[ "$output" == *"file:absent"* ]]
	rm -rf "$tmp"
}

@test "stop_launch_watchdog is no-op when pid file absent" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			kill() { echo unexpected-kill; return 0; }
			stop_launch_watchdog
			echo done
		'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected-kill"* ]]
	rm -rf "$tmp"
}

@test "cleanup_stale_launch skips when expected launch pid still running" {
	local tmp pid_file live_pid
	tmp="$(temp_state_dir)"
	live_pid=$$
	pid_file="$tmp/state/launchlayer/active-launch.pid"
	mkdir -p "$(dirname "$pid_file")"
	echo "$live_pid" > "$pid_file"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			stop_launch_watchdog() { :; }
			restore_nvidia_power_mode() { :; }
			resume_vram_hogs_force() { echo force-resumed; }
			cleanup_stale_launch "'"$live_pid"'"
			[[ -f "$ACTIVE_LAUNCH_PID_FILE" ]] && echo kept || echo cleared
		'
	[[ $status -eq 0 ]]
	[[ "$output" == kept ]]
	[[ "$output" != *"force-resumed"* ]]
	rm -rf "$tmp"
}

@test "cleanup_stale_launch skips when active pid differs from expected" {
	local tmp pid_file
	tmp="$(temp_state_dir)"
	pid_file="$tmp/state/launchlayer/active-launch.pid"
	mkdir -p "$(dirname "$pid_file")"
	echo 999001 > "$pid_file"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			stop_launch_watchdog() { :; }
			restore_nvidia_power_mode() { :; }
			resume_vram_hogs_force() { echo force-resumed; }
			cleanup_stale_launch 111222
			[[ -f "$ACTIVE_LAUNCH_PID_FILE" ]] && echo kept || echo cleared
		'
	[[ $status -eq 0 ]]
	[[ "$output" == kept ]]
	[[ "$output" != *"force-resumed"* ]]
	rm -rf "$tmp"
}
