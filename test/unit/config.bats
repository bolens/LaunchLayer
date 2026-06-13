#!/usr/bin/env bash
# Unit tests for lib/config.sh and config validation helpers.
load '../helpers.bash'

setup() {
	bats_unit_setup
}

@test "appid_in_list_file finds appid in list" {
	local list
	list="$(mktemp)"
	printf '%s\n' 12345 67890 > "$list"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		appid_in_list_file 67890 "'"$list"'" && echo found || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == found ]]
	rm -f "$list"
}

@test "appid_in_list_file ignores comments and blanks" {
	local list
	list="$(mktemp)"
	cat > "$list" <<EOF
# comment
42424242

EOF
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		appid_in_list_file 42424242 "'"$list"'" && echo found || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == found ]]
	rm -f "$list"
}

@test "appid_in_list_file returns failure for missing appid" {
	local list
	list="$(mktemp)"
	printf '%s\n' 11111 > "$list"
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		appid_in_list_file 22222 "'"$list"'" && echo found || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == missing ]]
	rm -f "$list"
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
		echo "gamemode:$GAMEMODE mangohud:$MANGOHUD"
		rm -f /tmp/test-$$.env
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "gamemode:1 mangohud:0" ]]
}

@test "load_env_file force=0 preserves existing env" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMEMODE=9
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		echo GAMEMODE=1 > /tmp/test-$$.env
		load_env_file /tmp/test-$$.env 0
		echo "gamemode:$GAMEMODE"
		rm -f /tmp/test-$$.env
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "gamemode:9" ]]
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
		printf "%s\n" "$(appid_env_write_path 12345)" "$(resolve_appid_env_path 12345)"
		appid_env_exists 12345 && echo exists || echo missing
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"$games/12345.env"* ]]
	[[ "$output" == *exists* ]]
	rm -rf "$tmp"
}

@test "config_file_display_name parses scaffold header" {
	local tmp file
	tmp="$(mktemp -d)"
	file="$tmp/42424242.env"
	cat > "$file" <<'EOF'
# Test Game (Steam AppID 42424242)
INCLUDE=presets/standard.env
EOF
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		config_file_display_name "'"$file"'" 42424242
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "Test Game" ]]
	rm -rf "$tmp"
}

@test "write_appid_env_scaffold creates preset include file" {
	local tmp games path
	tmp="$(mktemp -d)"
	games="$tmp/games"
	mkdir -p "$games"
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$games" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config
		write_appid_env_scaffold 42424242 "Test Game" competitive
		cat "$(appid_env_write_path 42424242)"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"INCLUDE=presets/competitive.env"* ]]
	[[ "$output" == *"Test Game (Steam AppID 42424242)"* ]]
	rm -rf "$tmp"
}

@test "reset_config_state clears launch globals" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib keys config runtime
		GAMEMODE=1
		is_native=1
		is_anticheat=1
		launch=(gamemoderun)
		config_layers=("layer.env")
		reset_config_state
		echo "gamemode:${GAMEMODE:-unset} native:$is_native anticheat:$is_anticheat launch:${#launch[@]} layers:${#config_layers[@]}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == "gamemode:unset native:0 anticheat:0 launch:0 layers:0" ]]
}
