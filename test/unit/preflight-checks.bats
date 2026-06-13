#!/usr/bin/env bash
# Unit tests for lib/preflight.sh launch-time check helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "check_oversized_cache_dirs warns when shader cache exceeds max_gb" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform
		steam_app_id=42424242
		shader_cache_dirs=("/tmp/fake-shader-cache")
		dir_size_bytes() { echo $((11 * 1024 * 1024 * 1024)); }
		check_oversized_cache_dirs shader 10 0 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"shader cache"* ]]
	[[ "$output" == *"42424242"* ]]
	[[ "$output" == *"> 10GB"* ]]
}

@test "sum_cache_dirs_gb totals shader directories" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Sum Cache Game")"
	mkdir -p "$fake_steam/steamapps/shadercache/42424242"
	run env STEAM_ROOT="$fake_steam" bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform steam
		dir_size_gb() { echo 3; }
		sum_cache_dirs_gb 42424242 shader
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "3" ]]
	rm -rf "$fake_steam"
}

@test "check_disk_space warns when library partition is below threshold" {
	local fake_steam
	fake_steam="$(fake_steam_root 42424242 "Disk Game")"
	run env \
		STEAM_ROOT="$fake_steam" \
		DISK_PREFLIGHT_MIN_GB=100 \
		bash -c '
			export CONFIG_DIR="'"$CONFIG_DIR"'"
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib preflight platform steam
			df_avail_gb() { echo 5; }
			check_disk_space 2>&1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"Low disk space"* ]]
	[[ "$output" == *"5GB free"* ]]
	rm -rf "$fake_steam"
}

@test "check_vram_available warns when free VRAM is below threshold" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export VRAM_PREFLIGHT_MIN_MB=8192
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu
		gpu_vram_free_mb() { echo 1024; }
		check_vram_available 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GPU VRAM free 1024MB"* ]]
	[[ "$output" == *"8192MB"* ]]
}
