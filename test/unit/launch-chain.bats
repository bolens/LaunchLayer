#!/usr/bin/env bash
# Unit tests for launch chain invariants (no duplicate wrappers/overlays).
load '../helpers.bash'

setup() {
	bats_unit_setup
}

# run_launch_chain_case — Build launch[] with mocked tool availability.
run_launch_chain_case() {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		'"$1"'
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		optional_tool_installed() {
			case "$1" in
				gamemoderun|mangohud|taskset|gamescope|game-performance|dlss-swapper) return 0 ;;
				*) return 1 ;;
			esac
		}
		command_available() {
			case "$1" in
				game-performance|wrapper-a|dlss-swapper|dlss-swapper-dll) return 0 ;;
				*) return 1 ;;
			esac
		}
		default_online_cpus() { echo 0-3; }
		launch=()
		build_launch_chain
		'"$2"'
	'
}

@test "launch_chain_has_duplicate_wrappers rejects duplicate gamemoderun" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch=(gamemoderun gamemoderun /bin/true)
		if launch_chain_has_duplicate_wrappers; then
			launch_chain_duplicate_wrapper_errors
		else
			echo "no duplicates"
		fi
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"duplicate gamemoderun"* ]]
}

@test "launch_chain_has_duplicate_wrappers rejects mangohud with --mangoapp" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch=(gamescope --mangoapp -- mangohud /bin/true)
		launch_chain_duplicate_wrapper_errors
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"mangohud wrapper and gamescope --mangoapp both present"* ]]
}

@test "build_launch_chain gamescope+mangohud uses --mangoapp only once" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAMESCOPE=1 GAMESCOPE_W=1920 GAMESCOPE_H=1080 GAMESCOPE_R=120
		export GAMESCOPE_ADAPTIVE_SYNC=0 BENCHMARK=0 MANGOHUD=1 MANGOHUD_CONFIG=fps' \
		'printf "dup:%s\n" "$(launch_chain_has_duplicate_wrappers && echo yes || echo no)"
		printf "mangoapp:%s mangohud:%s\n" "$(launch_chain_count_token --mangoapp)" "$(launch_chain_count_token mangohud)"
		printf "mangohud_env:%s\n" "${MANGOHUD-unset}"
		printf "uses_mangohud:%s\n" "$(launch_chain_uses_mangohud && echo 1 || echo 0)"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dup:no"* ]]
	[[ "$output" == *"mangoapp:1 mangohud:0"* ]]
	[[ "$output" == *"mangohud_env:unset"* ]]
	[[ "$output" == *"uses_mangohud:1"* ]]
}

@test "build_launch_chain mangohud without gamescope adds mangohud once" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAMESCOPE=0 BENCHMARK=0 MANGOHUD=1' \
		'printf "dup:%s\n" "$(launch_chain_has_duplicate_wrappers && echo yes || echo no)"
		printf "mangoapp:%s mangohud:%s\n" "$(launch_chain_count_token --mangoapp)" "$(launch_chain_count_token mangohud)"
		printf "mangohud_env:%s\n" "${MANGOHUD:-unset}"
		printf "uses_mangohud:%s\n" "$(launch_chain_uses_mangohud && echo 1 || echo 0)"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dup:no"* ]]
	[[ "$output" == *"mangoapp:0 mangohud:1"* ]]
	[[ "$output" == *"mangohud_env:1"* ]]
	[[ "$output" == *"uses_mangohud:1"* ]]
}

@test "build_launch_chain benchmark mode skips mangohud and --mangoapp" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAMESCOPE=1 GAMESCOPE_W=1920 GAMESCOPE_H=1080 GAMESCOPE_R=120
		export GAMESCOPE_ADAPTIVE_SYNC=0 BENCHMARK=1 MANGOHUD=1' \
		'printf "dup:%s\n" "$(launch_chain_has_duplicate_wrappers && echo yes || echo no)"
		printf "mangoapp:%s mangohud:%s\n" "$(launch_chain_count_token --mangoapp)" "$(launch_chain_count_token mangohud)"
		printf "uses_mangohud:%s\n" "$(launch_chain_uses_mangohud && echo 1 || echo 0)"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dup:no"* ]]
	[[ "$output" == *"mangoapp:0 mangohud:0"* ]]
	[[ "$output" == *"uses_mangohud:0"* ]]
}

@test "build_launch_chain full wrapper stack has no duplicate tools" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=1 GAME_PERFORMANCE=1 GAMESCOPE=1 GAMESCOPE_W=1920 GAMESCOPE_H=1080 GAMESCOPE_R=120
		export GAMESCOPE_ADAPTIVE_SYNC=0 BENCHMARK=0 MANGOHUD=1
		export LAUNCH_WRAPPERS_BEFORE=wrapper-a LAUNCH_WRAPPERS=wrapper-a' \
		'printf "dup:%s\n" "$(launch_chain_has_duplicate_wrappers && echo yes || echo no)"
		printf "gamemoderun:%s gamescope:%s game-performance:%s\n" \
			"$(launch_chain_count_token gamemoderun)" \
			"$(launch_chain_count_token gamescope)" \
			"$(launch_chain_count_token game-performance)"
		launch_chain_duplicate_wrapper_errors || true'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dup:no"* ]]
	[[ "$output" == *"gamemoderun:1 gamescope:1 game-performance:1"* ]]
	[[ "$output" != *"duplicate"* ]]
}

@test "build_launch_chain DLSS_SWAPPER=1 inserts dlss-swapper" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 DLSS_SWAPPER=1 DISABLE_CPU_AFFINITY=1' \
		'printf "dlss:%s\n" "$(launch_chain_count_token dlss-swapper)"
		printf "chain:%s\n" "${launch[*]}"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dlss:1"* ]]
	[[ "$output" == *"chain:dlss-swapper"* ]]
}

@test "build_launch_chain DLSS_SWAPPER=dll inserts dlss-swapper-dll" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 DLSS_SWAPPER=dll DISABLE_CPU_AFFINITY=1' \
		'printf "dll:%s swapper:%s\n" "$(launch_chain_count_token dlss-swapper-dll)" "$(launch_chain_count_token dlss-swapper)"
		printf "chain:%s\n" "${launch[*]}"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dll:1 swapper:0"* ]]
	[[ "$output" == *"chain:dlss-swapper-dll"* ]]
}

@test "build_launch_chain DLSS_SWAPPER=0 omits dlss wrappers" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0 DLSS_SWAPPER=0 DISABLE_CPU_AFFINITY=1' \
		'printf "dlss:%s dll:%s\n" "$(launch_chain_count_token dlss-swapper)" "$(launch_chain_count_token dlss-swapper-dll)"
		printf "chain:%s\n" "${launch[*]:-empty}"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dlss:0 dll:0"* ]]
	[[ "$output" != *"dlss-swapper"* ]]
}

@test "build_launch_chain places dlss-swapper after game-performance" {
	run_launch_chain_case \
		'export is_native=0 GAMEMODE=0 GAME_PERFORMANCE=1 GAMESCOPE=0 MANGOHUD=0 DLSS_SWAPPER=1 DISABLE_CPU_AFFINITY=1' \
		'printf "chain:%s\n" "${launch[*]}"'
	[[ $status -eq 0 ]]
	[[ "$output" == *"chain:game-performance dlss-swapper"* ]]
}

@test "build_launch_chain skips DLSS_SWAPPER when binary missing" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export is_native=0 GAMEMODE=0 GAME_PERFORMANCE=0 GAMESCOPE=0 MANGOHUD=0
		export DLSS_SWAPPER=1 DISABLE_CPU_AFFINITY=1
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		optional_tool_installed() { return 1; }
		command_available() { return 1; }
		default_online_cpus() { echo 0-3; }
		launch=()
		build_launch_chain
		printf "count:%s chain:%s\n" "${#launch[@]}" "${launch[*]:-empty}"
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"count:0"* ]]
	[[ "$output" != *"dlss-swapper"* ]]
}

@test "launch_chain_duplicate_wrapper_errors flags both dlss wrappers" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch=(dlss-swapper dlss-swapper-dll /bin/true)
		launch_chain_duplicate_wrapper_errors
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"dlss-swapper and dlss-swapper-dll both present"* ]]
}

@test "launch_wrapper_config_conflict_errors flags dlss-swapper with DLSS_SWAPPER=1" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export DLSS_SWAPPER=1 LAUNCH_WRAPPERS=dlss-swapper
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch_wrapper_config_conflict_errors
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"LAUNCH_WRAPPERS includes dlss-swapper while DLSS_SWAPPER=1"* ]]
}

@test "launch_wrapper_config_conflict_errors flags dlss-swapper-dll with DLSS_SWAPPER=dll" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export DLSS_SWAPPER=dll LAUNCH_WRAPPERS_BEFORE=dlss-swapper-dll
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch_wrapper_config_conflict_errors
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"LAUNCH_WRAPPERS includes dlss-swapper-dll while DLSS_SWAPPER=dll"* ]]
}

@test "launch_wrapper_config_conflict_errors flags gamemoderun with GAMEMODE=1" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export GAMEMODE=1 LAUNCH_WRAPPERS_BEFORE=gamemoderun
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		launch_wrapper_config_conflict_errors
	'
	[[ $status -eq 0 ]]
	[[ "$output" == *"LAUNCH_WRAPPERS includes gamemoderun while GAMEMODE=1"* ]]
}

@test "build_launch_chain warns on duplicate gamemoderun from LAUNCH_WRAPPERS_BEFORE" {
	run bash -c '
		export CONFIG_DIR="'"$CONFIG_DIR"'"
		export is_native=0 GAMEMODE=1 LAUNCH_WRAPPERS_BEFORE=gamemoderun BENCHMARK=0
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform runtime
		optional_tool_installed() { [[ "$1" == gamemoderun ]]; }
		launch=()
		build_launch_chain
		printf "dup:%s\n" "$(launch_chain_has_duplicate_wrappers && echo yes || echo no)"
		printf "gamemoderun:%s\n" "$(launch_chain_count_token gamemoderun)"
		warn_launch_chain_issues
	' 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"launch chain:"* ]]
	[[ "$output" == *"duplicate gamemoderun"* ]]
	[[ "$output" == *"dup:yes"* ]]
	[[ "$output" == *"gamemoderun:2"* ]]
}

@test "prepare_launch_context fails dry-run guard when wrappers duplicate" {
	local tmp
	tmp="$(temp_config_dir)"
	mkdir -p "$tmp/games"
	printf '%s\n' 'GAMEMODE=1' 'LAUNCH_WRAPPERS_BEFORE=gamemoderun' > "$tmp/games/42424242.env"
	run env CONFIG_DIR="$tmp" LAUNCHLAYER_GAMES_DIR="$tmp/games" bash -c '
		source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
		source_lib platform keys config steam hardware runtime detected-defaults gpu launch
		optional_tool_installed() { [[ "$1" == gamemoderun ]]; }
		default_online_cpus() { echo 0-3; }
		prepare_launch_context 42424242
	' 2>&1
	[[ $status -eq 1 ]]
	[[ "$output" == *"duplicate gamemoderun"* ]]
	rm -rf "$tmp"
}

@test "log_launch_event records mangohud=1 when chain uses --mangoapp" {
	local tmp
	tmp="$(temp_state_dir)"
	run env \
		CONFIG_DIR="$CONFIG_DIR" \
		XDG_STATE_HOME="$tmp/state" \
		bash -c '
			export is_native=0 GAMESCOPE=1 GAMESCOPE_W=1920 GAMESCOPE_H=1080 GAMESCOPE_R=120
			export GAMESCOPE_ADAPTIVE_SYNC=0 BENCHMARK=0 MANGOHUD=1
			source "'"$BATS_TEST_DIRNAME"'/../helpers.bash"
			source_lib platform runtime
			optional_tool_installed() { [[ "$1" == gamescope ]]; }
			command_available() { return 1; }
			steam_app_id=42424242
			steam_game_name="Overlay Game"
			is_anticheat=0
			launch=()
			build_launch_chain
			log_launch_event 0 5
			grep -o "mangohud=[01]" "$LAUNCH_LOG_FILE"
		'
	[[ $status -eq 0 ]]
	[[ "$output" == "mangohud=1" ]]
	rm -rf "$tmp"
}
