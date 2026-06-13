#!/usr/bin/env bash
# Unit tests for lib/vram.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "vram ref count round-trip" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			set_vram_ref_count 2
			[[ "$(get_vram_ref_count)" == "2" ]]
			set_vram_ref_count 0
			[[ "$(get_vram_ref_count)" == "0" ]]
			[[ ! -f "$VRAM_REF_COUNT_FILE" ]]
		'
	[[ $status -eq 0 ]]
	rm -rf "$tmp"
}

@test "save and load paused vram units" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib vram
			paused_vram_units=(sunshine.service hyprwhspr.service)
			save_paused_vram_units
			paused_vram_units=()
			load_paused_vram_units_from_state
			(( ${#paused_vram_units[@]} == 2 ))
			[[ "${paused_vram_units[0]}" == sunshine.service ]]
		'
	[[ $status -eq 0 ]]
	rm -rf "$tmp"
}
