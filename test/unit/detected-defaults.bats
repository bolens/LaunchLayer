#!/usr/bin/env bash
# Unit tests for lib/detected-defaults.sh.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "set_detected_default applies unset keys only" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib detected-defaults config keys
		declare -gA config_key_sources=()
		set_detected_default GAMEMODE 1
		[[ "$GAMEMODE" == "1" ]]
		config_key_sources[GAMEMODE]=presets/standard.env
		set_detected_default GAMEMODE 9
		[[ "$GAMEMODE" == "1" ]]
	'
	[[ $status -eq 0 ]]
}

@test "detected_defaults_add queues key value pairs" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib detected-defaults
		detected_defaults_reset
		detected_defaults_add GAMEMODE 1 "test reason"
		detected_defaults_add MANGOHUD 0 "other"
		(( ${#_detected_default_keys[@]} == 2 ))
		[[ "${_detected_default_keys[0]}" == GAMEMODE ]]
		[[ "${_detected_default_values[1]}" == "0" ]]
		[[ "${_detected_default_reasons[0]}" == "test reason" ]]
	'
	[[ $status -eq 0 ]]
}

@test "filter_installed_vram_hog_units drops missing units" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib detected-defaults platform
		has_systemd_user() { return 0; }
		systemctl() { [[ "$3" == launchlayer-fake.service ]] && return 1; return 0; }
		out="$(filter_installed_vram_hog_units "launchlayer-fake.service launchlayer-real.service")"
		[[ "$out" == "launchlayer-real.service" ]]
	'
	[[ $status -eq 0 ]]
}
