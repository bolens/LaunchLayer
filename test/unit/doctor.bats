#!/usr/bin/env bash
# Unit tests for lib/setup/doctor.sh structured issue collection.
load '../helpers.bash'

setup() {
	bats_unit_setup
	DOCTOR_TMP="$(temp_config_dir)"
	export CONFIG_DIR="$DOCTOR_TMP"
}

teardown() {
	[[ -n "${DOCTOR_TMP:-}" ]] && rm -rf "$DOCTOR_TMP"
}

@test "doctor_collect_json_issues emits sysctl flatpak and config issues" {
	run env CONFIG_DIR="$DOCTOR_TMP" LAUNCHD_DIR="$DOCTOR_TMP/launch.d" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform setup cli
		doctor_collect_json_issues "65530" "262144" "needs_override" 2 "Validation failed
games/42424242.env:3: unknown key: BADKEY"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"code":"vm_max_map_count"'* ]]
	[[ "$output" == *'"code":"flatpak_script_access"'* ]]
	[[ "$output" == *'"code":"config_validation"'* ]]
	[[ "$output" == *"unknown key: BADKEY"* ]]
	[[ "$output" != *"Validation failed"* ]]
}

@test "doctor_collect_json_issues reports missing launch.d directory" {
	local missing_root
	missing_root="$(mktemp -d)"
	run env CONFIG_DIR="$missing_root" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform setup cli
		doctor_collect_json_issues "262144" "262144" "ok" 0 ""
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"code":"missing_launch_d"'* ]]
	[[ "$output" == *"missing $missing_root/launch.d"* ]]
	rm -rf "$missing_root"
}

@test "doctor_collect_json_issues returns empty array when healthy" {
	run env CONFIG_DIR="$DOCTOR_TMP" LAUNCHD_DIR="$DOCTOR_TMP/launch.d" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform setup cli
		doctor_collect_json_issues "262144" "262144" "ok" 0 ""
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "[]" ]]
}

@test "doctor_issue_count sums sysctl access launch.d and validation issues" {
	local bad_games
	bad_games="$(mktemp -d)"
	mkdir -p "$bad_games/games" "$DOCTOR_TMP/launch.d/presets"
	echo 'NOT_A_REAL_KEY=1' > "$bad_games/games/42424242.env"
	run env \
		CONFIG_DIR="$DOCTOR_TMP" \
		LAUNCHD_DIR="$DOCTOR_TMP/launch.d" \
		LAUNCHLAYER_GAMES_DIR="$bad_games/games" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib setup platform steam keys config inspect cli
			sysctl_required_value() { echo 262144; }
			sysctl_current_value() { echo 65530; }
			flatpak_script_access() { echo needs_override; }
			doctor_issue_count
		'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^[0-9]+$ ]]
	(( output >= 3 ))
	rm -rf "$bad_games"
}
