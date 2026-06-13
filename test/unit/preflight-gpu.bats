#!/usr/bin/env bash
# Unit tests for lib/preflight.sh GPU and shader cache rate limiting.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "check_gpu_power warns when nvidia pstate is not P0" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GPU_POWER_CHECK=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu tools
		detect_gpu_vendor() { echo nvidia; }
		optional_tool_installed() { [[ "$1" == nvidia-smi ]]; }
		nvidia-smi() { echo "P2"; }
		check_gpu_power 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GPU pstate is P2"* ]]
}

@test "check_gpu_power is no-op when GPU_POWER_CHECK is disabled" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GPU_POWER_CHECK=0
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu tools
		nvidia-smi() { echo unexpected; }
		check_gpu_power 2>&1
		echo done
	'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected"* ]]
}

@test "check_shader_cache skips entirely when SHADER_CACHE_CHECK is disabled" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		SHADER_CACHE_CHECK=0 \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib preflight platform steam
			steam_app_id=42424242
			collect_shader_cache_dirs() { echo unexpected-collect; }
			check_shader_cache
			echo done
		'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected-collect"* ]]
	rm -rf "$tmp"
}

@test "check_shader_cache writes stamp after oversized shader warning" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		SHADER_CACHE_CHECK=1 \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib preflight platform
			steam_app_id=42424242
			collect_shader_cache_dirs() {
				shader_cache_dirs=("/tmp/fake-shader-cache")
			}
			dir_size_bytes() { echo $((11 * 1024 * 1024 * 1024)); }
			check_shader_cache 2>/dev/null
			stamp="$(shader_cache_stamp_file 42424242)"
			[[ -f "$stamp" ]] && echo stamp:written || echo stamp:missing
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *"stamp:written"* ]]
	rm -rf "$tmp"
}

@test "check_compatdata skips native games without FORCE_PROTON" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		COMPATDATA_CHECK=1 \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib preflight platform steam
			steam_app_id=42424242
			is_native=1
			FORCE_PROTON=0
			collect_compatdata_dirs() { echo unexpected-collect; }
			check_compatdata
			echo done
		'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected-collect"* ]]
	rm -rf "$tmp"
}
