#!/usr/bin/env bash
# Unit tests for check_gpu_vram_processes preflight helper.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "check_gpu_vram_processes warns on high nvidia compute usage" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GPU_VRAM_PROCESS_MIN_MB=512
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu
		detect_gpu_vendor() { echo nvidia; }
		nvidia-smi() {
			printf "%s\n" "1234, HeavyGame.exe, 2048"
		}
		check_gpu_vram_processes 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"GPU process using 2048MB"* ]]
	[[ "$output" == *"HeavyGame.exe"* ]]
}

@test "check_gpu_vram_processes skips when threshold is zero" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GPU_VRAM_PROCESS_MIN_MB=0
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu
		nvidia-smi() { echo unexpected; }
		check_gpu_vram_processes 2>&1
		echo done
	'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected"* ]]
}

@test "check_gpu_vram_processes skips on non-nvidia gpus" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GPU_VRAM_PROCESS_MIN_MB=512
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib preflight platform gpu
		detect_gpu_vendor() { echo amd; }
		nvidia-smi() { echo unexpected; }
		check_gpu_vram_processes 2>&1
		echo done
	'
	[[ $status -eq 0 ]]
	[[ "$output" == done ]]
	[[ "$output" != *"unexpected"* ]]
}
