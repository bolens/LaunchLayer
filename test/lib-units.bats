#!/usr/bin/env bash
# Unit tests for LaunchLayer lib/*.sh helpers.

setup() {
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/helpers.bash"
	export CONFIG_DIR="$(launchlayer_root)"
}

@test "appid_in_list_file finds appid in list" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib keys config
		printf "%s\n" 12345 67890 > /tmp/appids-$$.txt
		appid_in_list_file 67890 /tmp/appids-$$.txt
		rm -f /tmp/appids-$$.txt
	'
	[[ $status -eq 0 ]]
}

@test "appid_in_list_file ignores comments and blanks" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib keys config
		cat > /tmp/appids-$$.txt <<EOF
# comment
42424242

EOF
		appid_in_list_file 42424242 /tmp/appids-$$.txt
		rm -f /tmp/appids-$$.txt
	'
	[[ $status -eq 0 ]]
}

@test "load_env_file exports keys from file" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib keys config
		cat > /tmp/test-$$.env <<EOF
GAMEMODE=1
# comment
INCLUDE=presets/standard.env
MANGOHUD=0
EOF
		load_env_file /tmp/test-$$.env 1
		[[ "$GAMEMODE" == "1" && "$MANGOHUD" == "0" ]]
		rm -f /tmp/test-$$.env
	'
	[[ $status -eq 0 ]]
}

@test "load_env_file force=0 preserves existing env" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMEMODE=9
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib keys config
		echo GAMEMODE=1 > /tmp/test-$$.env
		load_env_file /tmp/test-$$.env 0
		[[ "$GAMEMODE" == "9" ]]
		rm -f /tmp/test-$$.env
	'
	[[ $status -eq 0 ]]
}

@test "bytes_to_gb rounds up partial gigabytes" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib platform
		bytes_to_gb $(( 600 * 1024 * 1024 ))
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "1" ]]
}

@test "json_string escapes quotes and newlines" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		json_string $'"'"'say "hi"\n'"'"'
	'
	[[ $status -eq 0 ]]
	[[ "$output" == '"say \"hi\"\n"' ]]
}

@test "json_bool emits true and false" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		printf "%s/%s\n" "$(json_bool 1)" "$(json_bool 0)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "true/false" ]]
}

@test "cli_edit_distance measures typos" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		cli_edit_distance --show-config --show-confg
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "1" ]]
}

@test "cli_suggest_subcommand suggests close flags" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		cli_suggest_subcommand --show-confg
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"--show-config"* ]]
}

@test "cli_is_known_subcommand recognizes registered verbs" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		cli_is_known_subcommand --doctor && cli_is_known_subcommand --not-real
	'
	[[ $status -eq 1 ]]
}

@test "vram ref count round-trip" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
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
			source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
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

@test "timestamp_iso returns parseable timestamp" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib platform
		timestamp_iso
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "detect_uname_kernel returns lowercase kernel name" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib platform
		detect_uname_kernel
	'
	[[ $status -eq 0 ]]
	[[ "$output" =~ ^(linux|darwin|freebsd|openbsd|netbsd)$ ]]
}

@test "config_file_relative strips launch.d prefix" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib keys config
		config_file_relative "'"$CONFIG_DIR"'/launch.d/presets/standard.env"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "presets/standard.env" ]]
}

@test "validate_single_config_file flags unknown keys" {
	local tmp cfg
	tmp="$(mktemp -d)"
	cfg="$tmp/bad.env"
	cat > "$cfg" <<'EOF'
NOT_A_REAL_LAUNCH_KEY=1
EOF
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib platform keys config tools inspect
		validate_single_config_file "'"$cfg"'"
	'
	[[ "$output" == *"unknown key"* ]]
	rm -rf "$tmp"
}

@test "launch_stats json with empty log" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
			source_lib platform steam cli inspect
			launch_stats "" 1
		'
	[[ $status -eq 0 ]]
	[[ "$output" == *'"entries":[]'* ]]
	python3 -c 'import json,sys; json.loads(sys.argv[1])' "$output"
	rm -rf "$tmp"
}

@test "launch_stats parses sample log entries" {
	local tmp log
	tmp="$(temp_state_dir)"
	log="$tmp/state/launchlayer/launch.log"
	mkdir -p "$(dirname "$log")"
	cat > "$log" <<'EOF'
2026-01-01T12:00:00+0000 appid=42424242 name="Test Game" duration=120s exit=0
2026-01-02T12:00:00+0000 appid=42424242 name="Test Game" duration=60s exit=1
EOF
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
			source_lib platform steam cli inspect
			launch_stats 42424242 1
		'
	[[ $status -eq 0 ]]
	python3 -c 'import json,sys; d=json.loads(sys.argv[1]); e=d["entries"][0]; assert e["appid"]=="42424242" and e["launches"]==2 and e["failures"]==1' "$output"
	rm -rf "$tmp"
}

@test "realpath_portable resolves existing path" {
	local tmp
	tmp="$(mktemp -d)"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib platform
		realpath_portable "'"$tmp"'"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "$tmp" ]]
	rm -rf "$tmp"
}

@test "cli_parse_global_flags strips quiet and verbose" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib cli
		cli_parse_global_flags --quiet --verbose --doctor > /tmp/ll-flags-$$.txt
		[[ "${LAUNCH_QUIET:-0}" == "1" && "${LAUNCH_VERBOSE:-0}" == "1" ]]
		grep -qx -- "--doctor" /tmp/ll-flags-$$.txt
		rm -f /tmp/ll-flags-$$.txt
	'
	[[ $status -eq 0 ]]
}

@test "appid_env helpers use games dir" {
	local tmp games
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games"
	printf 'GAMES=1\n' > "$games/12345.env"
	run bash -c '
		export CONFIG_DIR="'"$tmp"'"
		export LAUNCHLAYER_GAMES_DIR="'"$games"'"
		source "'"$BATS_TEST_DIRNAME"'/helpers.bash"
		source_lib config
		[[ "$(appid_env_write_path 12345)" == "'"$games"'/12345.env" ]]
		[[ "$(resolve_appid_env_path 12345)" == "'"$games"'/12345.env" ]]
		appid_env_exists 12345
	'
	[[ $status -eq 0 ]]
	rm -rf "$tmp"
}
