#!/usr/bin/env bash
# Unit tests for lib/commands/status.sh show_status.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "show_status json reports dead active launch when pid file is stale" {
	local tmp pid_file
	tmp="$(temp_state_dir)"
	pid_file="$tmp/state/launchlayer/active-launch.pid"
	mkdir -p "$(dirname "$pid_file")"
	echo 999999 > "$pid_file"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands cli status platform steam vram preflight gpu
			show_status "" 1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"active_launch_state":"dead"'* ]]
	[[ "$output" == *'"active_launch_pid":"999999"'* ]]
	rm -rf "$tmp"
}

@test "show_status json includes cache entries for appid" {
	local fake_steam tmp
	fake_steam="$(fake_steam_root 42424242 "Status Cache Game")"
	tmp="$(temp_state_dir)"
	mkdir -p "$fake_steam/steamapps/shadercache/42424242"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		STEAM_ROOT="$fake_steam" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib commands cli status platform steam vram preflight gpu
			dir_size_bytes() { echo 1073741824; }
			show_status 42424242 1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"appid":"42424242"'* ]]
	[[ "$output" == *"shadercache/42424242"* ]]
	rm -rf "$fake_steam" "$tmp"
}
