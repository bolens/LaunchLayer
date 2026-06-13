#!/usr/bin/env bash
# Unit tests for lib/cli.sh helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "json_string escapes quotes and newlines" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		json_string $'"'"'say "hi"\n'"'"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == '"say \"hi\"\n"' ]]
}

@test "json_string quotes empty string" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		json_string ""
	'
	[[ $status -eq 0 ]]
	[[ "$output" == '""' ]]
}

@test "json_bool emits true and false" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		printf "%s/%s\n" "$(json_bool 1)" "$(json_bool 0)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "true/false" ]]
}

@test "cli_edit_distance measures typos" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_edit_distance --show-config --show-confg
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "1" ]]
}

@test "cli_edit_distance is zero for identical strings" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_edit_distance --doctor --doctor
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "0" ]]
}

@test "cli_suggest_subcommand suggests close flags" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_suggest_subcommand --show-confg
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"--show-config"* ]]
}

@test "cli_is_known_subcommand recognizes registered verbs" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_is_known_subcommand --doctor && cli_is_known_subcommand --not-real
	'
	[[ $status -eq 1 ]]
}

@test "cli_parse_global_flags strips quiet and verbose" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_parse_global_flags --quiet --verbose --doctor > /tmp/ll-flags-$$.txt
		[[ "${LAUNCH_QUIET:-0}" == "1" && "${LAUNCH_VERBOSE:-0}" == "1" ]]
		grep -qx -- "--doctor" /tmp/ll-flags-$$.txt
		rm -f /tmp/ll-flags-$$.txt
	'
	[[ $status -eq 0 ]]
}

@test "json_object_pair prints comma-prefixed fields" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		printf "{"; json_object_pair "a" "$(json_string 1)"; json_object_pair "b" "$(json_bool 1)" 1; printf "}\n"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"a":"1"'* ]]
	[[ "$output" == *'"b":true'* ]]
}

@test "json_array_strings builds quoted array" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		items=(alpha beta)
		json_array_strings items
	'
	[[ $status -eq 0 ]]
	[[ "$output" == '["alpha","beta"]' ]]
}

@test "json_number_or_string keeps integers unquoted" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		printf "%s/%s\n" "$(json_number_or_string 42)" "$(json_number_or_string hello)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == '42/"hello"' ]]
}

@test "cli_unknown_subcommand suggests typo fix" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_unknown_subcommand --show-confg 2>&1
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"unknown subcommand"* ]]
	[[ "$output" == *"--show-config"* ]]
}

@test "cli_basename returns launchlayer" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib cli
		cli_basename
	'
	[[ $status -eq 0 ]]
	[[ "$output" == launchlayer ]]
}
