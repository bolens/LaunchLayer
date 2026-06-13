#!/usr/bin/env bash
# Unit tests for lib/commands/dispatch-launch.sh routing.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

_dispatch_launch_shell() {
	bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands cli
		'"$1"'
	'
}

@test "dispatch_launch_subcommand cleanup-stale-launch delegates to cleanup_stale_launch" {
	local tmp
	tmp="$(temp_state_dir)"
	run env XDG_STATE_HOME="$tmp/state" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands platform config inspect runtime launch vram
		CLEANUP_ARGS=""
		cleanup_stale_launch() { CLEANUP_ARGS="$*"; echo "cleaned:$*"; }
		dispatch_launch_subcommand --cleanup-stale-launch 424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cleaned:424242"* ]]
	rm -rf "$tmp"
}

@test "dispatch_launch_subcommand resume-vram-hogs clears active launch pid file" {
	local tmp pid_file
	tmp="$(temp_state_dir)"
	pid_file="$tmp/state/launchlayer/active-launch.pid"
	mkdir -p "$(dirname "$pid_file")"
	echo 111111 > "$pid_file"
	run env XDG_STATE_HOME="$tmp/state" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib commands platform config inspect runtime launch vram
		resume_vram_hogs_force() { echo force-resumed; }
		stop_launch_watchdog() { :; }
		dispatch_launch_subcommand --resume-vram-hogs
		[[ -f "$ACTIVE_LAUNCH_PID_FILE" ]] && echo pid:present || echo pid:cleared
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Resumed paused VRAM-heavy services"* ]]
	[[ "$output" == *"pid:cleared"* ]]
	rm -rf "$tmp"
}

@test "dispatch_launch_subcommand cache-report routes to cache_report" {
	run _dispatch_launch_shell '
		source_lib platform config inspect preflight steam runtime launch
		CACHE_ARGS=""
		cache_report() { CACHE_ARGS="$*"; echo "cache:$*"; }
		dispatch_launch_subcommand --cache-report --min-gb 7 --shader-only --json
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"cache:7 shader"* ]]
}
