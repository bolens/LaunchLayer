#!/usr/bin/env bash
# Unit tests for lib/inspect/validation.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "validate_single_config_file flags unknown keys" {
	local tmp
	tmp="$(temp_config_dir)"
	echo 'NOT_A_REAL_KEY=1' > "$tmp/launch.d/presets/bad.env"
	run env CONFIG_DIR="$tmp" VALIDATION_FILE="$tmp/launch.d/presets/bad.env" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform steam keys config inspect
		validate_single_config_file "$VALIDATION_FILE" 2>&1
	'
	[[ $status -ne 0 ]]
	[[ "$output" == *"unknown key: NOT_A_REAL_KEY"* ]]
	rm -rf "$tmp"
}

@test "validate_single_config_file flags conflicting force flags" {
	local tmp
	tmp="$(temp_config_dir)"
	cat > "$tmp/launch.d/local.env" <<'EOF'
FORCE_NATIVE=1
FORCE_PROTON=1
EOF
	run env CONFIG_DIR="$tmp" VALIDATION_FILE="$tmp/launch.d/local.env" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform steam keys config inspect
		validate_single_config_file "$VALIDATION_FILE" 2>&1
	'
	[[ $status -ne 0 ]]
	[[ "$output" == *"conflicting FORCE_NATIVE=1 and FORCE_PROTON=1"* ]]
	rm -rf "$tmp"
}

@test "validate_single_config_file flags missing INCLUDE target" {
	local tmp
	tmp="$(temp_config_dir)"
	echo 'INCLUDE=missing-preset.env' > "$tmp/launch.d/local.env"
	run env CONFIG_DIR="$tmp" VALIDATION_FILE="$tmp/launch.d/local.env" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform steam keys config inspect
		validate_single_config_file "$VALIDATION_FILE" 2>&1
	'
	[[ $status -ne 0 ]]
	[[ "$output" == *"INCLUDE target missing: missing-preset.env"* ]]
	rm -rf "$tmp"
}

@test "validate_single_config_file accepts known keys" {
	local tmp
	tmp="$(temp_config_dir)"
	echo 'GAMEMODE=1' > "$tmp/launch.d/local.env"
	run env CONFIG_DIR="$tmp" VALIDATION_FILE="$tmp/launch.d/local.env" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform steam keys config inspect
		validate_single_config_file "$VALIDATION_FILE" 2>&1
	'
	[[ $status -eq 0 ]]
	[[ -z "$output" ]]
	[[ ! "$output" == *"unknown key"* ]]
	rm -rf "$tmp"
}
