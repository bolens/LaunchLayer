#!/usr/bin/env bash
# Unit tests for lib/config.sh and config validation helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "appid_in_list_file finds appid in list" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
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
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
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

@test "appid_in_list_file returns failure for missing appid" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		printf "%s\n" 11111 > /tmp/appids-$$.txt
		appid_in_list_file 22222 /tmp/appids-$$.txt
		ec=$?
		rm -f /tmp/appids-$$.txt
		exit "$ec"
	'
	[[ $status -eq 1 ]]
}

@test "load_env_file exports keys from file" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
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
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		echo GAMEMODE=1 > /tmp/test-$$.env
		load_env_file /tmp/test-$$.env 0
		[[ "$GAMEMODE" == "9" ]]
		rm -f /tmp/test-$$.env
	'
	[[ $status -eq 0 ]]
}

@test "config_file_relative strips launch.d prefix" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
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
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform keys config tools inspect
		validate_single_config_file "'"$cfg"'"
	'
	[[ "$output" == *"unknown key"* ]]
	rm -rf "$tmp"
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
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib config
		[[ "$(appid_env_write_path 12345)" == "'"$games"'/12345.env" ]]
		[[ "$(resolve_appid_env_path 12345)" == "'"$games"'/12345.env" ]]
		appid_env_exists 12345
	'
	[[ $status -eq 0 ]]
	rm -rf "$tmp"
}
