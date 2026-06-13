#!/usr/bin/env bash
# Unit tests for lib/preflight.sh cache reporting helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "print_cache_dirs_text shows none for empty entries" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		shader_cache_entries=()
		compatdata_entries=()
		print_cache_dirs_text
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Shader cache:"* ]]
	[[ "$output" == *"(none)"* ]]
}

@test "print_cache_dirs_text formats byte sizes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		shader_cache_entries=("/tmp/shader|1073741824")
		compatdata_entries=()
		print_cache_dirs_text
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"/tmp/shader"* ]]
	[[ "$output" == *"1GB"* ]]
}

@test "collect_shader_cache_dirs finds fake steam shadercache" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Cache Game")"
	mkdir -p "$fake_steam/steamapps/shadercache/42424242"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform steam
		collect_shader_cache_dirs 42424242
		printf "%s\n" "${shader_cache_dirs[@]}"
	' 2>/dev/null
	[[ $status -eq 0 ]]
	[[ "$output" == *"/shadercache/42424242"* ]]
	rm -rf "$fake_steam"
}

@test "cache_check_due skips recent stamp files" {
	local tmp stamp
	tmp="$(temp_state_dir)"
	stamp="$tmp/state/launchlayer/shader-check.stamp"
	mkdir -p "$(dirname "$stamp")"
	date +%s > "$stamp"
	run env XDG_STATE_HOME="$tmp/state" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		cache_check_due "'"$stamp"'" 24 && echo due || echo skip
	'
	[[ $status -eq 0 ]]
	[[ "$output" == skip ]]
	rm -rf "$tmp"
}

@test "cache_check_due runs when stamp is stale" {
	local tmp stamp
	tmp="$(temp_state_dir)"
	stamp="$tmp/state/launchlayer/shader-check.stamp"
	mkdir -p "$(dirname "$stamp")"
	echo 0 > "$stamp"
	run env XDG_STATE_HOME="$tmp/state" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		cache_check_due "'"$stamp"'" 24 && echo due || echo skip
	'
	[[ $status -eq 0 ]]
	[[ "$output" == due ]]
	rm -rf "$tmp"
}

@test "check_vram_available warns when free VRAM is low" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export VRAM_PREFLIGHT_MIN_MB=4096
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		gpu_vram_free_mb() { echo 512; }
		check_vram_available 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GPU VRAM free 512MB < 4096MB"* ]]
}

@test "check_concurrent_launch warns on active launch pid file" {
	local tmp pid_file
	tmp="$(temp_state_dir)"
	pid_file="$tmp/state/launchlayer/active-launch.pid"
	mkdir -p "$(dirname "$pid_file")"
	echo "$$" > "$pid_file"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib preflight platform
			CONCURRENT_LAUNCH_GUARD=1
			check_concurrent_launch 2>&1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Another game launch is active"* ]]
	rm -rf "$tmp"
}

@test "collect_cache_size_entries sums shader and compat dirs" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Cache Game")"
	mkdir -p "$fake_steam/steamapps/shadercache/42424242" \
		"$fake_steam/steamapps/compatdata/42424242"
	echo data > "$fake_steam/steamapps/shadercache/42424242/blob.bin"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform steam
		dir_size_bytes() { echo 1024; }
		collect_cache_size_entries 42424242
		printf "shader:%s compat:%s path:%s\n" \
			"${#shader_cache_entries[@]}" \
			"${#compatdata_entries[@]}" \
			"${shader_cache_entries[0]%%|*}"
	' 2>/dev/null
	[[ $status -eq 0 ]]
	[[ "$output" == *"shader:1 compat:1"* ]]
	[[ "$output" == *"/shadercache/42424242"* ]]
	rm -rf "$fake_steam"
}

@test "check_compatdata skips native games without FORCE_PROTON" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform steam
		steam_app_id=42424242
		is_native=1
		FORCE_PROTON=0
		COMPATDATA_CHECK=1
		collect_compatdata_dirs() { echo "should not run" >&2; return 1; }
		check_compatdata 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" != *"should not run"* ]]
}
